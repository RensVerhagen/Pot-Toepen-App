import 'package:flutter_test/flutter_test.dart';
import 'package:pot_toepen/domain/game_engine.dart';
import 'package:pot_toepen/domain/models.dart';

void main() {
  late DateTime clock;
  late GameEngine engine;

  setUp(() {
    clock = DateTime(2026, 9, 7, 20);
    engine = GameEngine(now: () => clock);
  });

  test('new game starts every player at -1 and derives the pot', () {
    final game = engine.startGame([
      'Jan',
      'Piet',
      'Klaas',
      'Rens',
    ], ScoreUnit.euro);

    expect(game.players.map((player) => player.score), everyElement(-1));
    expect(game.pot, 4);
    expect(game.status, GameStatus.active);
    expect(game.phase, GamePhase.normal);
  });

  test('requires 2 to 8 unique non-empty players', () {
    expect(
      () => engine.startGame(['Solo'], ScoreUnit.points),
      throwsA(isA<GameRuleException>()),
    );
    expect(
      () => engine.startGame(['Rens', ' rens '], ScoreUnit.points),
      throwsA(isA<GameRuleException>()),
    );
    expect(
      () => engine.startGame(
        List.generate(9, (index) => 'P$index'),
        ScoreUnit.points,
      ),
      throwsA(isA<GameRuleException>()),
    );
  });

  test('processes the confirmed normal-round example', () {
    var game = engine.startGame(['P1', 'P2', 'P3', 'P4'], ScoreUnit.euro);
    game = game.copyWith(
      players: [
        game.players[0].copyWith(score: -2),
        game.players[1].copyWith(score: -2),
        game.players[2].copyWith(score: -3),
        game.players[3].copyWith(score: -5),
      ],
    );
    final stakes = [1, 1, 1, 5];
    for (var index = 0; index < game.players.length; index++) {
      game = engine.setDraftStake(game, game.players[index].id, stakes[index]);
    }
    game = engine.setDraftWinner(game, game.players[3].id);

    final result = engine.processNormalRound(game);

    expect(result.players.map((player) => player.score), [-3, -3, -4, 0]);
    expect(result.pot, 10);
    expect(result.rounds.single.potBefore, 12);
    expect(result.rounds.single.potAfter, 10);
  });

  test('zero is explicit and an unentered stake keeps draft incomplete', () {
    var game = engine.startGame(['A', 'B'], ScoreUnit.points);
    game = engine.setDraftStake(game, game.players[0].id, 0);
    game = engine.setDraftWinner(game, game.players[0].id);

    expect(game.hasCompleteDraft, isFalse);
    expect(
      () => engine.processNormalRound(game),
      throwsA(isA<GameRuleException>()),
    );

    game = engine.setDraftStake(game, game.players[1].id, 0);
    expect(game.hasCompleteDraft, isTrue);
  });

  test('stake cannot exceed pot at round start', () {
    final game = engine.startGame(['A', 'B'], ScoreUnit.points);
    expect(game.pot, 2);
    expect(
      () => engine.setDraftStake(game, game.players.first.id, 3),
      throwsA(isA<GameRuleException>()),
    );
  });

  test('payout schedule distributes remainder to earliest rounds', () {
    expect(engine.payoutSchedule(80, 3), [27, 27, 26]);
    expect(engine.payoutSchedule(4, 4), [1, 1, 1, 1]);
    expect(
      () => engine.payoutSchedule(3, 4),
      throwsA(isA<GameRuleException>()),
    );
  });

  test('closing rounds empty the pot without changing losers', () {
    var game = engine.startGame(['A', 'B', 'C'], ScoreUnit.euro);
    game = game.copyWith(
      players: [
        game.players[0].copyWith(score: -5),
        game.players[1].copyWith(score: -2),
        game.players[2].copyWith(score: -3),
      ],
    );
    game = engine.startClosing(game, 3);
    expect(game.closingPayouts, [4, 3, 3]);

    final originalLoserScore = game.players[1].score;
    for (var index = 0; index < 3; index++) {
      game = engine.setDraftWinner(game, game.players[0].id);
      game = engine.processPayoutRound(game);
    }

    expect(game.status, GameStatus.active);
    expect(game.pot, 0);
    expect(engine.completeGame(game).status, GameStatus.completed);
    expect(game.players[1].score, originalLoserScore);
    expect(game.players[0].score, 5);
  });

  test('undo restores scores and closing progress atomically', () {
    var game = engine.startGame(['A', 'B'], ScoreUnit.points);
    game = engine.startClosing(game, 2);
    game = engine.setDraftWinner(game, game.players.first.id);
    game = engine.processPayoutRound(game);
    expect(game.pot, 1);
    expect(game.closingRoundIndex, 1);

    game = engine.undo(game);

    expect(game.pot, 2);
    expect(game.closingRoundIndex, 0);
    expect(game.players.map((player) => player.score), [-1, -1]);
  });

  test('game with empty pot can complete without payout rounds', () {
    var game = engine.startGame(['A', 'B'], ScoreUnit.points);
    game = game.copyWith(
      players: [
        game.players[0].copyWith(score: 1),
        game.players[1].copyWith(score: -1),
      ],
    );

    game = engine.completeEmptyPot(game);

    expect(game.status, GameStatus.completed);
    expect(game.pot, 0);
  });

  test('game aggregate survives JSON round-trip', () {
    final game = engine.startGame(['A', 'B'], ScoreUnit.dollar);
    final decoded = GameRecord.decode(game.encode());

    expect(decoded.id, game.id);
    expect(decoded.unit, ScoreUnit.dollar);
    expect(decoded.players.map((player) => player.name), ['A', 'B']);
    expect(decoded.pot, 2);
  });
}
