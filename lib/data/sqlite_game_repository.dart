import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../domain/models.dart';
import 'game_repository.dart';

class SqliteGameRepository implements GameRepository {
  SqliteGameRepository._(this._database);

  final Database _database;

  static Future<SqliteGameRepository> open() async {
    final root = await getDatabasesPath();
    final database = await openDatabase(
      p.join(root, 'pot_toepen.db'),
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE games (
            id TEXT PRIMARY KEY,
            status TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            payload TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE INDEX games_status_updated
          ON games(status, updated_at DESC)
        ''');
        await db.execute('''
          CREATE TABLE remembered_players (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL COLLATE NOCASE UNIQUE,
            last_used_at INTEGER NOT NULL
          )
        ''');
      },
    );
    return SqliteGameRepository._(database);
  }

  @override
  Future<GameRecord?> loadActiveGame() async {
    final rows = await _database.query(
      'games',
      columns: ['payload'],
      where: 'status = ?',
      whereArgs: [GameStatus.active.name],
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return GameRecord.decode(rows.first['payload']! as String);
  }

  @override
  Future<List<GameRecord>> loadHistory() async {
    final rows = await _database.query(
      'games',
      columns: ['payload'],
      where: 'status != ?',
      whereArgs: [GameStatus.active.name],
      orderBy: 'updated_at DESC',
    );
    return rows
        .map((row) => GameRecord.decode(row['payload']! as String))
        .toList(growable: false);
  }

  @override
  Future<void> saveGame(GameRecord game) async {
    await _database.insert('games', {
      'id': game.id,
      'status': game.status.name,
      'created_at': game.createdAt.millisecondsSinceEpoch,
      'updated_at': game.updatedAt.millisecondsSinceEpoch,
      'payload': game.encode(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> deleteGame(String gameId) =>
      _database.delete('games', where: 'id = ?', whereArgs: [gameId]);

  @override
  Future<void> clearHistory() => _database.delete(
    'games',
    where: 'status != ?',
    whereArgs: [GameStatus.active.name],
  );

  @override
  Future<List<RememberedPlayer>> loadRememberedPlayers() async {
    final rows = await _database.query(
      'remembered_players',
      orderBy: 'last_used_at DESC, name COLLATE NOCASE',
    );
    return [
      for (final row in rows)
        RememberedPlayer(
          id: row['id']! as String,
          name: row['name']! as String,
          lastUsedAt: DateTime.fromMillisecondsSinceEpoch(
            row['last_used_at']! as int,
          ),
        ),
    ];
  }

  @override
  Future<void> rememberPlayers(Iterable<PlayerScore> players) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await _database.transaction((transaction) async {
      for (final player in players) {
        final existing = await transaction.query(
          'remembered_players',
          columns: ['id'],
          where: 'name = ? COLLATE NOCASE',
          whereArgs: [player.name.trim()],
          limit: 1,
        );
        await transaction.insert('remembered_players', {
          'id': existing.isEmpty ? player.id : existing.first['id'],
          'name': player.name.trim(),
          'last_used_at': timestamp,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  @override
  Future<void> renameRememberedPlayer(String id, String name) =>
      _database.update(
        'remembered_players',
        {'name': name.trim()},
        where: 'id = ?',
        whereArgs: [id],
      );

  @override
  Future<void> deleteRememberedPlayer(String id) =>
      _database.delete('remembered_players', where: 'id = ?', whereArgs: [id]);
}
