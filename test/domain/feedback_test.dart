import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pot_toepen/domain/game_engine.dart';
import 'package:pot_toepen/domain/models.dart';

void main() {
  late GameEngine engine;
  late GameRecord game;
  setUp(() {
    engine = GameEngine(
      random: Random(42),
      now: () => DateTime(2026, 9, 11, 20),
    );
    game = engine.startGame(['Rens', 'Thijs', 'Jan', 'Piet'], ScoreUnit.euro);
  });

  test('game agreements persist through rounds, restart and undo', () {
    game = engine.startGame(
      ['Rens', 'Thijs'],
      ScoreUnit.euro,
      toepTrekAmount: 10,
      allPassAmount: 5,
    );
    for (final p in game.players) {
      game = engine.setDraftStake(game, p.id, 0);
    }
    game = engine.processAllPass(game, game.players.first.id);
    game = GameRecord.decode(game.encode());
    expect(game.toepTrekAmount, 10);
    expect(game.allPassAmount, 5);
    game = engine.processToepTrek(game, game.players.first.id);
    expect(game.rounds.last.payout, 7);
    game = engine.undo(game);
    expect(game.toepTrekAmount, 10);
    expect(game.allPassAmount, 5);
  });

  test('invalid special amounts are rejected before game creation', () {
    for (final value in [0, -1, 1000001]) {
      expect(
        () =>
            engine.startGame(['A', 'B'], ScoreUnit.euro, toepTrekAmount: value),
        throwsA(isA<GameRuleException>()),
      );
      expect(
        () =>
            engine.startGame(['A', 'B'], ScoreUnit.euro, allPassAmount: value),
        throwsA(isA<GameRuleException>()),
      );
    }
  });

  test('legacy per-round undo keeps the current game agreement', () {
    game = engine.startGame(
      ['Rens', 'Thijs'],
      ScoreUnit.euro,
      toepTrekAmount: 10,
      allPassAmount: 5,
    );
    game = engine.topUp(game, 1);
    final oldSnapshot = (jsonDecode(game.undoStates.last) as Map)
      ..['toepTrekAmount'] = 2
      ..['allPassAmount'] = 3
      ..['roundConfigured'] = false;
    game = GameRecord.decode(
      game.copyWith(undoStates: [jsonEncode(oldSnapshot)]).encode(),
    );
    game = engine.undo(game);
    expect(game.pot, 2);
    expect(game.toepTrekAmount, 10);
    expect(game.allPassAmount, 5);
  });

  test('dealer is chosen once; table order wraps and survives a restart', () {
    expect(game.players.map((p) => p.id), contains(game.initialDealerId));
    game = game.copyWith(initialDealerId: game.players[1].id);
    expect(game.stakeOrder.map((p) => p.name), [
      'Jan',
      'Piet',
      'Rens',
      'Thijs',
    ]);
    final restored = GameRecord.decode(game.encode());
    expect(restored.dealerId, game.dealerId);
    expect(
      restored.stakeOrder.map((p) => p.id),
      game.stakeOrder.map((p) => p.id),
    );
  });

  test(
    'round winner deals next, and reorder preserves identities and scores',
    () {
      for (final p in game.players) {
        game = engine.setDraftStake(game, p.id, 1);
      }
      game = engine.setDraftWinner(game, game.players[2].id);
      game = engine.processNormalRound(game);
      expect(game.stakeOrder.map((p) => p.name), [
        'Piet',
        'Rens',
        'Thijs',
        'Jan',
      ]);
      final old = game;
      game = engine.reorderPlayers(game, [
        game.players[2].id,
        game.players[0].id,
        game.players[3].id,
        game.players[1].id,
      ]);
      expect(game.stakeOrder.map((p) => p.name), [
        'Rens',
        'Piet',
        'Thijs',
        'Jan',
      ]);
      expect(game.pot, old.pot);
      expect(game.lastWinnerId, old.lastWinnerId);
      expect(
        engine.undo(game).players.map((p) => p.id),
        old.players.map((p) => p.id),
      );
    },
  );

  test(
    '10 agreed, 8 in pot: toep-trek pays exactly 8 and game stays active',
    () {
      game = engine.startGame(
        ['Rens', 'Thijs', 'Jan', 'Piet'],
        ScoreUnit.euro,
        toepTrekAmount: 10,
        allPassAmount: 3,
      );
      game = engine.topUp(game, 1);
      final id = game.players.first.id;
      final before = game;
      game = engine.processToepTrek(game, id);
      expect(game.rounds.last.payout, 8);
      expect(game.pot, 0);
      expect(game.scoreFor(id), before.scoreFor(id)! + 8);
      expect(game.status, GameStatus.active);
      expect(game.dealerId, id);
      expect(engine.completeGame(game).status, GameStatus.completed);
      expect(
        engine.undo(GameRecord.decode(game.encode())).encode(),
        engine.undo(game).encode(),
      );
    },
  );

  test(
    'toep-trek only changes recipient and rejects an empty pot or live draft',
    () {
      game = engine.startGame(
        ['Rens', 'Thijs', 'Jan', 'Piet'],
        ScoreUnit.euro,
        toepTrekAmount: 2,
        allPassAmount: 3,
      );
      final before = game;
      game = engine.processToepTrek(game, game.players.first.id);
      expect(
        game.players.skip(1).map((p) => p.score),
        before.players.skip(1).map((p) => p.score),
      );
      game = engine.processToepTrek(game, game.players.first.id);
      expect(
        () => engine.processToepTrek(game, game.players.first.id),
        throwsA(isA<GameRuleException>()),
      );
    },
  );

  test(
    'all-pass charges only highest hand; undo restores draft and settings',
    () {
      game = engine.startGame(
        ['Rens', 'Thijs', 'Jan', 'Piet'],
        ScoreUnit.euro,
        toepTrekAmount: 10,
        allPassAmount: 5,
      );
      for (final p in game.players) {
        game = engine.setDraftStake(game, p.id, 0);
      }
      final before = game;
      game = engine.processAllPass(game, game.players[2].id);
      expect(game.pot, 9);
      expect(game.players.map((p) => p.score), [-1, -1, -6, -1]);
      expect(game.rounds.last.kind, RoundKind.allPass);
      expect(game.draftStakes, isEmpty);
      game = engine.undo(GameRecord.decode(game.encode()));
      expect(game.draftStakes, before.draftStakes);
      expect(game.pot, 4);
      expect(game.allPassAmount, 5);
      expect(game.rounds, isEmpty);
    },
  );

  test('incomplete or mixed stakes cannot trigger everyone-pass', () {
    game = engine.setDraftStake(game, game.players.first.id, 0);
    expect(
      () => engine.processAllPass(game, game.players.first.id),
      throwsA(isA<GameRuleException>()),
    );
    for (final p in game.players.skip(1)) {
      game = engine.setDraftStake(game, p.id, 1);
    }
    expect(
      () => engine.processAllPass(game, game.players.first.id),
      throwsA(isA<GameRuleException>()),
    );
    final winnerId = game.players.first.id;
    game = engine.setDraftWinner(game, winnerId);
    final result = engine.processNormalRound(game);
    expect(result.scoreFor(winnerId), game.scoreFor(winnerId));
    expect(result.pot, 7);
    expect(result.dealerId, winnerId);
  });

  test(
    'top-ups preserve dealer, do not advance round, and undo repeatedly',
    () {
      final dealer = game.dealerId;
      game = engine.topUp(game, 2);
      expect(game.pot, 12);
      expect(game.highestPot, 12);
      expect(game.normalRoundCount, 0);
      expect(game.dealerId, dealer);
      expect(game.lastWinnerId, isNull);
      game = engine.topUp(game, 5);
      expect(game.pot, 32);
      game = engine.undo(GameRecord.decode(game.encode()));
      expect(game.pot, 12);
      game = engine.undo(game);
      expect(game.pot, 4);
      expect(game.highestPot, 4);
    },
  );

  test('mid-round top-up, reorder and finish are blocked', () {
    game = engine.setDraftStake(game, game.players.first.id, 1);
    expect(() => engine.topUp(game, 2), throwsA(isA<GameRuleException>()));
    expect(
      () => engine.reorderPlayers(game, game.players.map((p) => p.id).toList()),
      throwsA(isA<GameRuleException>()),
    );
    expect(() => engine.completeGame(game), throwsA(isA<GameRuleException>()));
  });

  test('legacy JSON loads with safe defaults without replaying randomizer', () {
    final json = game.toJson()
      ..remove('initialDealerId')
      ..remove('dealerRevealed')
      ..remove('toepTrekAmount')
      ..remove('allPassAmount')
      ..remove('undoStates')
      ..remove('roundConfigured');
    final restored = GameRecord.fromJson(json);
    expect(restored.dealerRevealed, isTrue);
    expect(restored.stakeOrder.first.id, game.players.first.id);
    expect(restored.toepTrekAmount, 2);
    expect(restored.canUndo, isFalse);
  });

  test('last final payout is undoable, and completion is explicit', () {
    game = engine.startClosing(game, 1);
    game = engine.setDraftWinner(game, game.players.first.id);
    game = engine.processPayoutRound(game);
    expect(game.status, GameStatus.active);
    expect(game.pot, 0);
    game = engine.undo(game);
    expect(game.pot, 4);
    expect(game.closingRoundIndex, 0);
    game = engine.undo(game);
    expect(game.phase, GamePhase.normal);
  });

  test('mixed sequences always conserve scores plus pot and persist undo', () {
    final random = Random(7);
    for (var i = 0; i < 60; i++) {
      game = engine.topUp(game, 1 + random.nextInt(5));
      final p = game.players[random.nextInt(game.players.length)];
      if (i.isEven) {
        game = engine.processToepTrek(game, p.id);
      } else {
        for (final player in game.players) {
          game = engine.setDraftStake(game, player.id, 0);
        }
        game = engine.processAllPass(game, p.id);
      }
      game = GameRecord.decode(game.encode());
      expect(game.pot, greaterThanOrEqualTo(0));
      expect(
        game.pot + game.players.fold<int>(0, (sum, p) => sum + p.score),
        0,
      );
    }
    while (game.undoStates.isNotEmpty) {
      game = engine.undo(game);
    }
    expect(game.pot, 4);
    expect(game.rounds, isEmpty);
  });
}
