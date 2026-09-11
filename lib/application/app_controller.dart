import 'package:flutter/foundation.dart';

import '../data/game_repository.dart';
import '../domain/game_engine.dart';
import '../domain/models.dart';

class AppController extends ChangeNotifier {
  AppController({required this.repository, GameEngine? engine})
    : engine = engine ?? GameEngine();

  final GameRepository repository;
  final GameEngine engine;

  GameRecord? _activeGame;
  List<GameRecord> _history = const [];
  List<RememberedPlayer> _rememberedPlayers = const [];

  GameRecord? get activeGame => _activeGame;
  List<GameRecord> get history => List.unmodifiable(_history);
  List<RememberedPlayer> get rememberedPlayers =>
      List.unmodifiable(_rememberedPlayers);

  Future<void> initialize() async {
    _activeGame = await repository.loadActiveGame();
    _history = await repository.loadHistory();
    _rememberedPlayers = await repository.loadRememberedPlayers();
    notifyListeners();
  }

  Future<GameRecord> startGame(List<String> names, ScoreUnit unit) async {
    if (_activeGame != null) {
      throw const GameRuleException('Er is al een actief spel.');
    }
    final game = engine.startGame(names, unit);
    await repository.saveGame(game);
    await repository.rememberPlayers(game.players);
    _activeGame = game;
    _rememberedPlayers = await repository.loadRememberedPlayers();
    notifyListeners();
    return game;
  }

  int recordFor(ScoreUnit unit) => [
    for (final game in [..._history, ?_activeGame])
      if (game.unit == unit) game.highestPot,
    0,
  ].reduce((a, b) => a > b ? a : b);

  Future<void> revealDealer() =>
      _replaceActive(engine.revealDealer(_requiredGame));
  Future<void> configureRound(int toepTrek, int allPass) =>
      _replaceActive(engine.configureRound(_requiredGame, toepTrek, allPass));
  Future<void> reorderPlayers(List<String> ids) =>
      _replaceActive(engine.reorderPlayers(_requiredGame, ids));
  Future<void> topUp(int amount) =>
      _replaceActive(engine.topUp(_requiredGame, amount));
  Future<void> processAllPass(String id) =>
      _replaceActive(engine.processAllPass(_requiredGame, id));
  Future<void> processToepTrek(String id) =>
      _replaceActive(engine.processToepTrek(_requiredGame, id));
  Future<GameRecord> completeGame() async {
    final next = engine.completeGame(_requiredGame);
    await _saveTerminalOrActive(next);
    return next;
  }

  Future<void> clearAllData() async {
    await repository.clearAllData();
    _activeGame = null;
    _history = const [];
    _rememberedPlayers = const [];
    notifyListeners();
  }

  Future<void> setStake(String playerId, int stake) async {
    await _replaceActive(engine.setDraftStake(_requiredGame, playerId, stake));
  }

  Future<void> setWinner(String playerId) async {
    await _replaceActive(engine.setDraftWinner(_requiredGame, playerId));
  }

  RoundProjection? get normalProjection {
    final game = _activeGame;
    if (game == null ||
        !game.hasCompleteDraft ||
        game.allPassed ||
        game.phase != GamePhase.normal) {
      return null;
    }
    return engine.previewNormalRound(game);
  }

  RoundProjection? get payoutProjection {
    final game = _activeGame;
    if (game == null ||
        game.phase != GamePhase.closing ||
        game.draftWinnerPlayerId == null) {
      return null;
    }
    return engine.previewPayoutRound(game);
  }

  Future<RoundRecord> processNormalRound() async {
    final next = engine.processNormalRound(_requiredGame);
    await _replaceActive(next);
    return next.rounds.last;
  }

  Future<void> startClosing(int roundCount) async {
    await _replaceActive(engine.startClosing(_requiredGame, roundCount));
  }

  Future<void> cancelClosing() async {
    await _replaceActive(engine.cancelClosing(_requiredGame));
  }

  Future<GameRecord> processPayoutRound() async {
    final next = engine.processPayoutRound(_requiredGame);
    await _saveTerminalOrActive(next);
    return next;
  }

  Future<GameRecord> completeEmptyPot() async {
    final next = engine.completeEmptyPot(_requiredGame);
    await _saveTerminalOrActive(next);
    return next;
  }

  Future<void> undo() async {
    await _replaceActive(engine.undo(_requiredGame));
  }

  Future<void> abandon() async {
    final next = engine.abandon(_requiredGame);
    await _saveTerminalOrActive(next);
  }

  Future<void> deleteHistoryGame(String gameId) async {
    await repository.deleteGame(gameId);
    _history = _history.where((game) => game.id != gameId).toList();
    notifyListeners();
  }

  Future<void> clearHistory() async {
    await repository.clearHistory();
    _history = const [];
    notifyListeners();
  }

  Future<void> renameRememberedPlayer(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const GameRuleException('Vul een naam in.');
    }
    final duplicate = _rememberedPlayers.any(
      (player) =>
          player.id != id && player.name.toLowerCase() == trimmed.toLowerCase(),
    );
    if (duplicate) {
      throw const GameRuleException('Deze speler bestaat al.');
    }
    await repository.renameRememberedPlayer(id, trimmed);
    _rememberedPlayers = await repository.loadRememberedPlayers();
    notifyListeners();
  }

  Future<void> deleteRememberedPlayer(String id) async {
    await repository.deleteRememberedPlayer(id);
    _rememberedPlayers = await repository.loadRememberedPlayers();
    notifyListeners();
  }

  Future<void> _replaceActive(GameRecord game) async {
    await repository.saveGame(game);
    _activeGame = game;
    notifyListeners();
  }

  Future<void> _saveTerminalOrActive(GameRecord game) async {
    await repository.saveGame(game);
    if (game.status == GameStatus.active) {
      _activeGame = game;
    } else {
      _activeGame = null;
      _history = await repository.loadHistory();
    }
    notifyListeners();
  }

  GameRecord get _requiredGame {
    final game = _activeGame;
    if (game == null) {
      throw const GameRuleException('Er is geen actief spel.');
    }
    return game;
  }
}
