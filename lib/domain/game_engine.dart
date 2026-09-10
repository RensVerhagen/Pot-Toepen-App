import 'dart:math';

import 'models.dart';

class GameRuleException implements Exception {
  const GameRuleException(this.message);

  final String message;

  @override
  String toString() => message;
}

class GameEngine {
  GameEngine({DateTime Function()? now, Random? random})
    : _now = now ?? DateTime.now,
      _random = random ?? Random.secure();

  final DateTime Function() _now;
  final Random _random;

  GameRecord startGame(List<String> rawNames, ScoreUnit unit) {
    final names = rawNames.map((name) => name.trim()).toList(growable: false);
    if (names.length < 2 || names.length > 8) {
      throw const GameRuleException('Een spel heeft 2 tot 8 spelers nodig.');
    }
    if (names.any((name) => name.isEmpty)) {
      throw const GameRuleException('Iedere speler heeft een naam nodig.');
    }
    final unique = names.map((name) => name.toLowerCase()).toSet();
    if (unique.length != names.length) {
      throw const GameRuleException('Spelernamen moeten uniek zijn.');
    }

    final timestamp = _now();
    return GameRecord(
      id: _id('game'),
      createdAt: timestamp,
      updatedAt: timestamp,
      status: GameStatus.active,
      phase: GamePhase.normal,
      unit: unit,
      players: [
        for (final name in names)
          PlayerScore(id: _id('player'), name: name, score: -1),
      ],
    );
  }

  GameRecord setDraftStake(GameRecord game, String playerId, int stake) {
    _requireNormalActive(game);
    _requirePlayer(game, playerId);
    if (stake < 0 || stake > game.pot) {
      throw GameRuleException('De inzet moet tussen 0 en ${game.pot} liggen.');
    }
    return game.copyWith(
      updatedAt: _now(),
      draftStakes: {...game.draftStakes, playerId: stake},
    );
  }

  GameRecord setDraftWinner(GameRecord game, String playerId) {
    if (game.status != GameStatus.active) {
      throw const GameRuleException('Dit spel is niet meer actief.');
    }
    _requirePlayer(game, playerId);
    return game.copyWith(updatedAt: _now(), draftWinnerPlayerId: playerId);
  }

  RoundProjection previewNormalRound(GameRecord game) {
    _requireNormalActive(game);
    if (!game.hasCompleteDraft) {
      throw const GameRuleException(
        'Vul voor iedere speler een inzet in en kies een winnaar.',
      );
    }
    final winnerId = game.draftWinnerPlayerId!;
    final potBefore = game.pot;
    final nextPlayers = <PlayerScore>[];
    for (final player in game.players) {
      final stake = game.draftStakes[player.id];
      if (stake == null || stake < 0 || stake > potBefore) {
        throw GameRuleException('Ongeldige inzet voor ${player.name}.');
      }
      nextPlayers.add(
        player.copyWith(
          score: player.score + (player.id == winnerId ? stake : -stake),
        ),
      );
    }
    final potAfter = -nextPlayers.fold<int>(
      0,
      (sum, player) => sum + player.score,
    );
    if (potAfter < 0) {
      throw const GameRuleException('De pot kan niet negatief worden.');
    }
    return RoundProjection(
      players: nextPlayers,
      potBefore: potBefore,
      potAfter: potAfter,
      winnerPlayerId: winnerId,
      stakes: Map.unmodifiable(game.draftStakes),
    );
  }

  GameRecord processNormalRound(GameRecord game) {
    final projection = previewNormalRound(game);
    final timestamp = _now();
    final round = RoundRecord(
      id: _id('round'),
      kind: RoundKind.normal,
      createdAt: timestamp,
      winnerPlayerId: projection.winnerPlayerId,
      potBefore: projection.potBefore,
      potAfter: projection.potAfter,
      scoresBefore: _scoreMap(game.players),
      scoresAfter: _scoreMap(projection.players),
      stakes: projection.stakes,
    );
    return game.copyWith(
      updatedAt: timestamp,
      players: projection.players,
      rounds: [...game.rounds, round],
      draftStakes: const {},
      clearDraftWinner: true,
    );
  }

  List<int> payoutSchedule(int pot, int roundCount) {
    if (pot <= 0) {
      throw const GameRuleException('Er is geen pot om uit te spelen.');
    }
    if (roundCount < 1 || roundCount > pot) {
      throw GameRuleException('Kies 1 tot en met $pot finalerondes.');
    }
    final base = pot ~/ roundCount;
    final remainder = pot % roundCount;
    return List<int>.generate(
      roundCount,
      (index) => base + (index < remainder ? 1 : 0),
      growable: false,
    );
  }

  GameRecord startClosing(GameRecord game, int roundCount) {
    _requireNormalActive(game);
    final payouts = payoutSchedule(game.pot, roundCount);
    return game.copyWith(
      updatedAt: _now(),
      phase: GamePhase.closing,
      closingPayouts: payouts,
      closingRoundIndex: 0,
      draftStakes: const {},
      clearDraftWinner: true,
    );
  }

  GameRecord cancelClosing(GameRecord game) {
    if (game.status != GameStatus.active || game.phase != GamePhase.closing) {
      throw const GameRuleException('De finale is niet actief.');
    }
    if (game.closingRoundIndex != 0) {
      throw const GameRuleException(
        'Maak eerst alle gespeelde finalerondes ongedaan.',
      );
    }
    return game.copyWith(
      updatedAt: _now(),
      phase: GamePhase.normal,
      closingPayouts: const [],
      closingRoundIndex: 0,
      clearDraftWinner: true,
    );
  }

  RoundProjection previewPayoutRound(GameRecord game) {
    if (game.status != GameStatus.active || game.phase != GamePhase.closing) {
      throw const GameRuleException('De finale is niet actief.');
    }
    final winnerId = game.draftWinnerPlayerId;
    if (winnerId == null) {
      throw const GameRuleException('Kies de winnaar van deze finaleronde.');
    }
    _requirePlayer(game, winnerId);
    if (game.closingRoundIndex >= game.closingPayouts.length) {
      throw const GameRuleException('Alle finalerondes zijn al gespeeld.');
    }
    final payout = game.closingPayouts[game.closingRoundIndex];
    final players = [
      for (final player in game.players)
        player.id == winnerId
            ? player.copyWith(score: player.score + payout)
            : player,
    ];
    return RoundProjection(
      players: players,
      potBefore: game.pot,
      potAfter: game.pot - payout,
      winnerPlayerId: winnerId,
      payout: payout,
    );
  }

  GameRecord processPayoutRound(GameRecord game) {
    final projection = previewPayoutRound(game);
    final timestamp = _now();
    final nextIndex = game.closingRoundIndex + 1;
    final isFinished = nextIndex == game.closingPayouts.length;
    if (isFinished && projection.potAfter != 0) {
      throw const GameRuleException(
        'De finale moet de volledige pot uitbetalen.',
      );
    }
    final round = RoundRecord(
      id: _id('round'),
      kind: RoundKind.payout,
      createdAt: timestamp,
      winnerPlayerId: projection.winnerPlayerId,
      potBefore: projection.potBefore,
      potAfter: projection.potAfter,
      scoresBefore: _scoreMap(game.players),
      scoresAfter: _scoreMap(projection.players),
      payout: projection.payout,
    );
    return game.copyWith(
      updatedAt: timestamp,
      completedAt: isFinished ? timestamp : null,
      status: isFinished ? GameStatus.completed : GameStatus.active,
      players: projection.players,
      rounds: [...game.rounds, round],
      closingRoundIndex: nextIndex,
      clearDraftWinner: true,
    );
  }

  GameRecord completeEmptyPot(GameRecord game) {
    _requireNormalActive(game);
    if (game.pot != 0) {
      throw const GameRuleException(
        'Speel een finale om de pot leeg te maken.',
      );
    }
    final timestamp = _now();
    return game.copyWith(
      updatedAt: timestamp,
      completedAt: timestamp,
      status: GameStatus.completed,
    );
  }

  GameRecord abandon(GameRecord game) {
    if (game.status != GameStatus.active) {
      throw const GameRuleException('Dit spel is niet meer actief.');
    }
    final timestamp = _now();
    return game.copyWith(
      updatedAt: timestamp,
      completedAt: timestamp,
      status: GameStatus.abandoned,
      draftStakes: const {},
      clearDraftWinner: true,
    );
  }

  GameRecord undo(GameRecord game) {
    if (game.status != GameStatus.active || game.rounds.isEmpty) {
      throw const GameRuleException('Er is geen ronde om ongedaan te maken.');
    }
    final last = game.rounds.last;
    if (game.phase == GamePhase.closing &&
        last.kind == RoundKind.normal &&
        game.closingRoundIndex == 0) {
      throw const GameRuleException('Annuleer eerst de finale.');
    }
    final restoredPlayers = [
      for (final player in game.players)
        player.copyWith(score: last.scoresBefore[player.id]),
    ];
    return game.copyWith(
      updatedAt: _now(),
      players: restoredPlayers,
      rounds: game.rounds.sublist(0, game.rounds.length - 1),
      closingRoundIndex: last.kind == RoundKind.payout
          ? max(0, game.closingRoundIndex - 1)
          : game.closingRoundIndex,
      draftStakes: const {},
      clearDraftWinner: true,
    );
  }

  void _requireNormalActive(GameRecord game) {
    if (game.status != GameStatus.active || game.phase != GamePhase.normal) {
      throw const GameRuleException('De normale speelronde is niet actief.');
    }
  }

  void _requirePlayer(GameRecord game, String playerId) {
    if (!game.players.any((player) => player.id == playerId)) {
      throw const GameRuleException('Onbekende speler.');
    }
  }

  Map<String, int> _scoreMap(List<PlayerScore> players) => {
    for (final player in players) player.id: player.score,
  };

  String _id(String prefix) =>
      '${prefix}_${_now().microsecondsSinceEpoch}_${_random.nextInt(1 << 32)}';
}
