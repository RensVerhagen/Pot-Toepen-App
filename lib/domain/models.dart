import 'dart:convert';

enum ScoreUnit { points, euro, dollar, pound }

extension ScoreUnitX on ScoreUnit {
  String get label => switch (this) {
    ScoreUnit.points => 'Punten',
    ScoreUnit.euro => 'Euro',
    ScoreUnit.dollar => 'Dollar',
    ScoreUnit.pound => 'Pond',
  };

  String get symbol => switch (this) {
    ScoreUnit.points => 'pt',
    ScoreUnit.euro => '€',
    ScoreUnit.dollar => r'$',
    ScoreUnit.pound => '£',
  };

  String format(int value, {bool showPlus = false}) {
    final sign = showPlus && value > 0 ? '+' : '';
    return this == ScoreUnit.points ? '$sign$value pt' : '$sign$symbol$value';
  }
}

enum GameStatus { active, completed, abandoned }

enum GamePhase { normal, closing }

enum RoundKind { normal, payout, allPass, toepTrek, topUp }

extension RoundKindX on RoundKind {
  String get label => switch (this) {
    RoundKind.normal => 'Speelronde',
    RoundKind.payout => 'Finaleronde',
    RoundKind.allPass => 'Iedereen past',
    RoundKind.toepTrek => 'Toep-trek',
    RoundKind.topUp => 'Pot bijspekken',
  };
}

class PlayerScore {
  const PlayerScore({
    required this.id,
    required this.name,
    required this.score,
  });

  final String id;
  final String name;
  final int score;

  PlayerScore copyWith({String? name, int? score}) =>
      PlayerScore(id: id, name: name ?? this.name, score: score ?? this.score);

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'score': score};

  factory PlayerScore.fromJson(Map<String, Object?> json) => PlayerScore(
    id: json['id']! as String,
    name: json['name']! as String,
    score: json['score']! as int,
  );
}

class RoundRecord {
  const RoundRecord({
    required this.id,
    required this.kind,
    required this.createdAt,
    required this.winnerPlayerId,
    required this.potBefore,
    required this.potAfter,
    required this.scoresBefore,
    required this.scoresAfter,
    this.stakes = const {},
    this.payout,
  });

  final String id;
  final RoundKind kind;
  final DateTime createdAt;
  final String winnerPlayerId;
  final int potBefore;
  final int potAfter;
  final Map<String, int> scoresBefore;
  final Map<String, int> scoresAfter;
  final Map<String, int> stakes;
  final int? payout;

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'createdAt': createdAt.toIso8601String(),
    'winnerPlayerId': winnerPlayerId,
    'potBefore': potBefore,
    'potAfter': potAfter,
    'scoresBefore': scoresBefore,
    'scoresAfter': scoresAfter,
    'stakes': stakes,
    'payout': payout,
  };

  factory RoundRecord.fromJson(Map<String, Object?> json) => RoundRecord(
    id: json['id']! as String,
    kind: RoundKind.values.byName(json['kind']! as String),
    createdAt: DateTime.parse(json['createdAt']! as String),
    winnerPlayerId: json['winnerPlayerId']! as String,
    potBefore: json['potBefore']! as int,
    potAfter: json['potAfter']! as int,
    scoresBefore: _intMap(json['scoresBefore']),
    scoresAfter: _intMap(json['scoresAfter']),
    stakes: _intMap(json['stakes']),
    payout: json['payout'] as int?,
  );
}

class GameRecord {
  const GameRecord({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    required this.phase,
    required this.unit,
    required this.players,
    this.rounds = const [],
    this.closingPayouts = const [],
    this.closingRoundIndex = 0,
    this.draftStakes = const {},
    this.draftWinnerPlayerId,
    this.completedAt,
    this.initialDealerId,
    this.dealerRevealed = false,
    this.toepTrekAmount = 2,
    this.allPassAmount = 2,
    this.undoStates = const [],
  });

  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final GameStatus status;
  final GamePhase phase;
  final ScoreUnit unit;
  final List<PlayerScore> players;
  final List<RoundRecord> rounds;
  final List<int> closingPayouts;
  final int closingRoundIndex;
  final Map<String, int> draftStakes;
  final String? draftWinnerPlayerId;

  final String? initialDealerId;
  final bool dealerRevealed;
  final int toepTrekAmount;
  final int allPassAmount;
  final List<String> undoStates;

  String? get lastWinnerId {
    for (final round in rounds.reversed) {
      if (round.kind != RoundKind.topUp) return round.winnerPlayerId;
    }
    return null;
  }

  String get dealerId => lastWinnerId ?? initialDealerId ?? players.last.id;

  List<PlayerScore> get stakeOrder {
    final start =
        (players.indexWhere((p) => p.id == dealerId) + 1) % players.length;
    return List.generate(
      players.length,
      (i) => players[(start + i) % players.length],
    );
  }

  bool get allPassed =>
      draftStakes.length == players.length &&
      draftStakes.values.every((stake) => stake == 0);

  int get highestPot => [
    pot,
    players.length,
    for (final round in rounds) ...[round.potBefore, round.potAfter],
  ].reduce((a, b) => a > b ? a : b);

  bool get canUndo => undoStates.isNotEmpty || rounds.isNotEmpty;

  int get pot => -players.fold<int>(0, (sum, player) => sum + player.score);

  int get normalRoundCount => rounds
      .where(
        (round) =>
            round.kind != RoundKind.payout && round.kind != RoundKind.topUp,
      )
      .length;

  int get payoutRoundCount =>
      rounds.where((round) => round.kind == RoundKind.payout).length;

  bool get hasCompleteDraft =>
      draftWinnerPlayerId != null &&
      players.every((player) => draftStakes.containsKey(player.id));

  int? scoreFor(String playerId) {
    for (final player in players) {
      if (player.id == playerId) return player.score;
    }
    return null;
  }

  PlayerScore playerById(String playerId) =>
      players.firstWhere((player) => player.id == playerId);

  GameRecord copyWith({
    DateTime? updatedAt,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    GameStatus? status,
    GamePhase? phase,
    ScoreUnit? unit,
    List<PlayerScore>? players,
    List<RoundRecord>? rounds,
    List<int>? closingPayouts,
    int? closingRoundIndex,
    Map<String, int>? draftStakes,
    String? draftWinnerPlayerId,
    bool clearDraftWinner = false,
    String? initialDealerId,
    bool? dealerRevealed,
    int? toepTrekAmount,
    int? allPassAmount,
    List<String>? undoStates,
  }) => GameRecord(
    id: id,
    initialDealerId: initialDealerId ?? this.initialDealerId,
    dealerRevealed: dealerRevealed ?? this.dealerRevealed,
    toepTrekAmount: toepTrekAmount ?? this.toepTrekAmount,
    allPassAmount: allPassAmount ?? this.allPassAmount,
    undoStates: undoStates ?? this.undoStates,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
    status: status ?? this.status,
    phase: phase ?? this.phase,
    unit: unit ?? this.unit,
    players: players ?? this.players,
    rounds: rounds ?? this.rounds,
    closingPayouts: closingPayouts ?? this.closingPayouts,
    closingRoundIndex: closingRoundIndex ?? this.closingRoundIndex,
    draftStakes: draftStakes ?? this.draftStakes,
    draftWinnerPlayerId: clearDraftWinner
        ? null
        : (draftWinnerPlayerId ?? this.draftWinnerPlayerId),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'status': status.name,
    'phase': phase.name,
    'unit': unit.name,
    'players': players.map((player) => player.toJson()).toList(),
    'rounds': rounds.map((round) => round.toJson()).toList(),
    'initialDealerId': initialDealerId,
    'dealerRevealed': dealerRevealed,
    'toepTrekAmount': toepTrekAmount,
    'allPassAmount': allPassAmount,
    'undoStates': undoStates,
    'closingPayouts': closingPayouts,
    'closingRoundIndex': closingRoundIndex,
    'draftStakes': draftStakes,
    'draftWinnerPlayerId': draftWinnerPlayerId,
  };

  String encode() => jsonEncode(toJson());

  factory GameRecord.fromJson(Map<String, Object?> json) => GameRecord(
    id: json['id']! as String,
    createdAt: DateTime.parse(json['createdAt']! as String),
    updatedAt: DateTime.parse(json['updatedAt']! as String),
    completedAt: json['completedAt'] == null
        ? null
        : DateTime.parse(json['completedAt']! as String),
    status: GameStatus.values.byName(json['status']! as String),
    phase: GamePhase.values.byName(json['phase']! as String),
    unit: ScoreUnit.values.byName(json['unit']! as String),
    players: (json['players']! as List<Object?>)
        .map(
          (item) =>
              PlayerScore.fromJson((item! as Map).cast<String, Object?>()),
        )
        .toList(growable: false),
    rounds: (json['rounds']! as List<Object?>)
        .map(
          (item) =>
              RoundRecord.fromJson((item! as Map).cast<String, Object?>()),
        )
        .toList(growable: false),
    closingPayouts: (json['closingPayouts']! as List<Object?>).cast<int>(),
    initialDealerId: json['initialDealerId'] as String?,
    dealerRevealed: json['dealerRevealed'] as bool? ?? true,
    toepTrekAmount: json['toepTrekAmount'] as int? ?? 2,
    allPassAmount: json['allPassAmount'] as int? ?? 2,
    undoStates: (json['undoStates'] as List?)?.cast<String>() ?? const [],
    closingRoundIndex: json['closingRoundIndex']! as int,
    draftStakes: _intMap(json['draftStakes']),
    draftWinnerPlayerId: json['draftWinnerPlayerId'] as String?,
  );

  factory GameRecord.decode(String value) =>
      GameRecord.fromJson((jsonDecode(value) as Map).cast<String, Object?>());
}

class RememberedPlayer {
  const RememberedPlayer({
    required this.id,
    required this.name,
    required this.lastUsedAt,
  });

  final String id;
  final String name;
  final DateTime lastUsedAt;
}

class RoundProjection {
  const RoundProjection({
    required this.players,
    required this.potBefore,
    required this.potAfter,
    required this.winnerPlayerId,
    this.stakes = const {},
    this.payout,
  });

  final List<PlayerScore> players;
  final int potBefore;
  final int potAfter;
  final String winnerPlayerId;
  final Map<String, int> stakes;
  final int? payout;
}

Map<String, int> _intMap(Object? value) {
  if (value == null) return const {};
  return (value as Map).map(
    (key, item) => MapEntry(key as String, item as int),
  );
}
