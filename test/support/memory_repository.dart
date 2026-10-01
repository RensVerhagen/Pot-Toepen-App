import 'package:pot_toepen/data/game_repository.dart';
import 'package:pot_toepen/domain/models.dart';

class MemoryRepository implements GameRepository {
  final Map<String, GameRecord> games = {};
  final List<RememberedPlayer> players = [];
  bool failSave = false;
  @override
  Future<void> clearAllData() async {
    games.clear();
    players.clear();
  }

  @override
  Future<void> clearHistory() async =>
      games.removeWhere((_, g) => g.status != GameStatus.active);
  @override
  Future<void> deleteGame(String id) async => games.remove(id);
  @override
  Future<void> deleteRememberedPlayer(String id) async =>
      players.removeWhere((p) => p.id == id);
  @override
  Future<GameRecord?> loadActiveGame() async =>
      games.values.where((g) => g.status == GameStatus.active).firstOrNull;
  @override
  Future<List<GameRecord>> loadHistory() async =>
      games.values.where((g) => g.status != GameStatus.active).toList();
  @override
  Future<List<RememberedPlayer>> loadRememberedPlayers() async => [...players];
  @override
  Future<void> rememberPlayers(Iterable<PlayerScore> values) async {
    players.addAll(
      values.map(
        (p) => RememberedPlayer(
          id: p.id,
          name: p.name,
          lastUsedAt: DateTime.now(),
        ),
      ),
    );
  }

  @override
  Future<void> renameRememberedPlayer(String id, String name) async {}
  @override
  Future<void> saveGame(GameRecord game) async {
    if (failSave) throw StateError('Disk full');
    games[game.id] = GameRecord.decode(game.encode());
  }
}
