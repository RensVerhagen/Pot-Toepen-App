import '../domain/models.dart';

abstract class GameRepository {
  Future<GameRecord?> loadActiveGame();

  Future<List<GameRecord>> loadHistory();

  Future<void> saveGame(GameRecord game);

  Future<void> deleteGame(String gameId);

  Future<void> clearHistory();

  Future<List<RememberedPlayer>> loadRememberedPlayers();

  Future<void> rememberPlayers(Iterable<PlayerScore> players);

  Future<void> renameRememberedPlayer(String id, String name);

  Future<void> deleteRememberedPlayer(String id);
}
