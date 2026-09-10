import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:pot_toepen/application/app_controller.dart';
import 'package:pot_toepen/data/game_repository.dart';
import 'package:pot_toepen/domain/game_engine.dart';
import 'package:pot_toepen/domain/models.dart';
import 'package:pot_toepen/ui/app_theme.dart';
import 'package:pot_toepen/ui/screens/game_screen.dart';
import 'package:pot_toepen/ui/screens/home_screen.dart';
import 'package:pot_toepen/ui/screens/results_screen.dart';
import 'package:pot_toepen/ui/screens/setup_screen.dart';

void main() {
  late AppController controller;
  late String goldenDirectory;

  setUpAll(() async {
    goldenDirectory = path.join(
      Directory.systemTemp.path,
      'pot_toepen_visuals',
    );
    await Directory(goldenDirectory).create(recursive: true);
    debugPrint('QA_GOLDEN_DIR=$goldenDirectory');
  });

  setUp(() async {
    controller = AppController(repository: _MemoryRepository());
    await controller.initialize();
  });

  testWidgets('render home screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: HomeScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(HomeScreen),
      matchesGoldenFile(Uri.file(path.join(goldenDirectory, 'home.png'))),
    );
  });

  testWidgets('render game setup', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: SetupScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(SetupScreen),
      matchesGoldenFile(Uri.file(path.join(goldenDirectory, 'setup.png'))),
    );
  });

  testWidgets('render active round', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final game = await controller.startGame(const [
      'Rens',
      'Jan',
      'Piet',
      'Klaas',
    ], ScoreUnit.euro);
    for (final player in game.players) {
      await controller.setStake(player.id, player.name == 'Rens' ? 4 : 1);
    }
    await controller.setWinner(game.players.first.id);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: GameScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(GameScreen),
      matchesGoldenFile(Uri.file(path.join(goldenDirectory, 'game.png'))),
    );
  });

  testWidgets('render results', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = GameEngine();
    var game = engine.startGame(const [
      'Rens',
      'Jan',
      'Piet',
      'Klaas',
    ], ScoreUnit.euro);
    for (final player in game.players) {
      game = engine.setDraftStake(game, player.id, 1);
    }
    game = engine.setDraftWinner(game, game.players.first.id);
    game = engine.processNormalRound(game);
    game = engine.startClosing(game, 2);
    game = engine.setDraftWinner(game, game.players[1].id);
    game = engine.processPayoutRound(game);
    game = engine.setDraftWinner(game, game.players.first.id);
    game = engine.processPayoutRound(game);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: ResultsScreen(controller: controller, game: game),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(ResultsScreen),
      matchesGoldenFile(Uri.file(path.join(goldenDirectory, 'results.png'))),
    );
  });
}

class _MemoryRepository implements GameRepository {
  final List<GameRecord> games = [];

  @override
  Future<void> clearHistory() async =>
      games.removeWhere((game) => game.status != GameStatus.active);

  @override
  Future<void> deleteGame(String gameId) async =>
      games.removeWhere((game) => game.id == gameId);

  @override
  Future<void> deleteRememberedPlayer(String id) async {}

  @override
  Future<GameRecord?> loadActiveGame() async => null;

  @override
  Future<List<GameRecord>> loadHistory() async => const [];

  @override
  Future<List<RememberedPlayer>> loadRememberedPlayers() async => const [];

  @override
  Future<void> rememberPlayers(Iterable<PlayerScore> players) async {}

  @override
  Future<void> renameRememberedPlayer(String id, String name) async {}

  @override
  Future<void> saveGame(GameRecord game) async {
    games.removeWhere((item) => item.id == game.id);
    games.add(game);
  }
}
