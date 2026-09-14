import 'dart:io';

import 'package:path/path.dart' as path;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pot_toepen/application/app_controller.dart';
import 'package:pot_toepen/domain/models.dart';
import 'package:pot_toepen/ui/app_theme.dart';
import 'package:pot_toepen/ui/screens/game_screen.dart';
import 'package:pot_toepen/ui/screens/results_screen.dart';
import 'package:pot_toepen/ui/widgets/feedback_widgets.dart';

import '../test/support/memory_repository.dart';

void main() {
  late AppController controller;
  final output = Directory(
    path.join(Directory.systemTemp.path, 'pot_toepen_feedback_visuals'),
  );
  setUpAll(() async {
    await output.create(recursive: true);
    debugPrint('FEEDBACK_QA_DIR=${output.path}');
    final font = File(r'C:\Windows\Fonts\segoeui.ttf');
    if (await font.exists()) {
      final loader = FontLoader('QA')
        ..addFont(Future.value(ByteData.sublistView(await font.readAsBytes())));
      await loader.load();
      final iconFont = File(
        path.join(
          Directory.current.path,
          '.tooling',
          'flutter',
          'bin',
          'cache',
          'artifacts',
          'material_fonts',
          'MaterialIcons-Regular.otf',
        ),
      );
      if (await iconFont.exists()) {
        final icons = FontLoader('MaterialIcons')
          ..addFont(
            Future.value(ByteData.sublistView(await iconFont.readAsBytes())),
          );
        await icons.load();
      }
    }
  });
  setUp(() async {
    controller = AppController(repository: MemoryRepository());
    await controller.initialize();
    await controller.startGame(
      ['Rens', 'Thijs', 'Sophie', 'Daan'],
      ScoreUnit.euro,
      toepTrekAmount: 10,
      allPassAmount: 3,
    );
    await controller.revealDealer();
    await controller.topUp(5);
  });
  Future<void> mount(WidgetTester tester, Widget widget) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme().copyWith(
          textTheme: buildTheme().textTheme.apply(fontFamily: 'QA'),
        ),
        home: widget,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(Uri.file(path.join(output.path, '$name.png'))),
    );
  }

  testWidgets('active table and stake transition', (tester) async {
    await mount(tester, GameScreen(controller: controller));
    await capture(tester, 'table');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Inzetten'));
    await tester.tap(find.widgetWithText(FilledButton, 'Inzetten'));
    await tester.pumpAndSettle();
    await capture(tester, 'stakes');
    await tester.tap(find.widgetWithText(FilledButton, '€1'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    await capture(tester, 'stake-transition');
    await tester.pumpAndSettle();
  });

  testWidgets('filled stakes and fixed game information', (tester) async {
    final players = controller.activeGame!.players;
    final amounts = [0, 1, 10, 20];
    for (var i = 0; i < players.length; i++) {
      await controller.setStake(players[i].id, amounts[i]);
    }
    await mount(tester, GameScreen(controller: controller));
    await capture(tester, 'filled-stakes');
    await tester.tap(find.byTooltip('Spelinformatie'));
    await tester.pumpAndSettle();
    await capture(tester, 'game-info');
  });

  testWidgets('round agreement', (tester) async {
    await mount(
      tester,
      Scaffold(
        body: SafeArea(child: GameSettingsSheet(game: controller.activeGame!)),
      ),
    );
    await capture(tester, 'round-settings');
  });
  testWidgets('dealer roulette', (tester) async {
    await mount(tester, DealerReveal(game: controller.activeGame!));
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle();
    await capture(tester, 'dealer');
  });
  testWidgets('table reorder', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme().copyWith(
          textTheme: buildTheme().textTheme.apply(fontFamily: 'QA'),
        ),
        home: Scaffold(
          body: SafeArea(child: PlayerOrderSheet(game: controller.activeGame!)),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await capture(tester, 'reorder');
  });
  testWidgets('results and timeline', (tester) async {
    for (var i = 0; i < 4; i++) {
      final game = controller.activeGame!;
      for (final p in game.players) {
        await controller.setStake(p.id, i + 1);
      }
      await controller.setWinner(game.players[i].id);
      await controller.processNormalRound();
    }
    final game = await controller.completeGame();
    await mount(tester, ResultsScreen(controller: controller, game: game));
    await capture(tester, 'results');
    await tester.ensureVisible(find.byType(GameChart));
    await tester.pumpAndSettle();
    await capture(tester, 'chart');
  });
  testWidgets('all-time celebration', (tester) async {
    await mount(tester, GameScreen(controller: controller));
    final button = find.widgetWithText(ActionChip, '€5');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bevestigen'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await capture(tester, 'record-celebration');
    await tester.pumpAndSettle();
  });
}
