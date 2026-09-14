import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pot_toepen/application/app_controller.dart';
import 'package:pot_toepen/domain/models.dart';
import 'package:pot_toepen/ui/app_theme.dart';
import 'package:pot_toepen/ui/screens/game_screen.dart';
import 'package:pot_toepen/ui/screens/setup_screen.dart';
import 'package:pot_toepen/ui/widgets/feedback_widgets.dart';

import 'support/memory_repository.dart';

void main() {
  late AppController controller;
  late MemoryRepository repository;
  setUp(() async {
    repository = MemoryRepository();
    controller = AppController(repository: repository);
    await controller.initialize();
    await controller.startGame(
      ['Rens', 'Thijs', 'Jan', 'Piet'],
      ScoreUnit.euro,
      toepTrekAmount: 10,
      allPassAmount: 3,
    );
    await controller.revealDealer();
  });
  Future<void> mount(
    WidgetTester tester,
    Widget home, {
    double scale = 1,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: home,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'zero-stake winner receives zero, deals next and no new settings appear',
    (tester) async {
      final original = controller.activeGame!;
      final winner = original.players.first;
      for (final p in original.players) {
        await controller.setStake(p.id, p.id == winner.id ? 0 : 1);
      }
      await mount(tester, GameScreen(controller: controller));
      expect(find.text('Inzet'), findsNWidgets(4));
      expect(find.text('Totaal'), findsNWidgets(4));
      expect(find.text('€0'), findsOneWidget);
      await tap(tester, find.widgetWithText(OutlinedButton, 'Ronde afronden'));
      await tap(
        tester,
        find.widgetWithText(RadioListTile<String>, winner.name),
      );
      await tap(tester, find.text('Uitkomst bevestigen'));
      expect(controller.activeGame!.scoreFor(winner.id), -1);
      expect(controller.activeGame!.pot, 7);
      expect(controller.activeGame!.dealerId, winner.id);
      await tap(tester, find.widgetWithText(FilledButton, 'Inzetten'));
      expect(find.byType(GameSettingsSheet), findsNothing);
      expect(find.byType(StakeFlowSheet), findsOneWidget);
      expect(controller.activeGame!.toepTrekAmount, 10);
      expect(controller.activeGame!.allPassAmount, 3);
    },
  );

  testWidgets(
    'game information is read-only and resumes after restart without settings prompt',
    (tester) async {
      final saved = controller.activeGame!.toJson()
        ..['roundConfigured'] = false;
      repository.games[controller.activeGame!.id] = GameRecord.fromJson(saved);
      controller = AppController(repository: repository);
      await controller.initialize();
      await mount(tester, GameScreen(controller: controller));
      await tap(tester, find.byTooltip('Spelinformatie'));
      expect(find.byType(GameInfoSheet), findsOneWidget);
      expect(find.text('€10'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(GameInfoSheet),
          matching: find.text('€3'),
        ),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNothing);
      await tap(tester, find.text('Terug naar het spel'));
      await tap(tester, find.widgetWithText(FilledButton, 'Inzetten'));
      expect(find.byType(StakeFlowSheet), findsOneWidget);
      expect(find.byType(GameSettingsSheet), findsNothing);
    },
  );

  testWidgets('new game asks once and saves agreement with the initial game', (
    tester,
  ) async {
    repository = MemoryRepository();
    controller = AppController(repository: repository);
    await controller.initialize();
    await mount(tester, SetupScreen(controller: controller));
    for (final name in ['Rens', 'Thijs']) {
      await tester.enterText(find.byType(TextField), name);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(find.text('Start met €2 in de pot'));
    await tester.tap(find.text('Start met €2 in de pot'));
    // Finish the modal transition without settling the busy start button.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(GameSettingsSheet), findsOneWidget);
    expect(controller.activeGame, isNull);
    await tester.enterText(find.byType(TextField).at(1), '10');
    await tester.enterText(find.byType(TextField).at(2), '5');
    tester.testTextInput.hide();
    await tester.pump();
    await tester.ensureVisible(find.text('Bedragen opslaan'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Bedragen opslaan'));
    await tester.pumpAndSettle();
    expect(controller.activeGame!.toepTrekAmount, 10);
    expect(controller.activeGame!.allPassAmount, 5);
    expect(repository.games.values.single.toepTrekAmount, 10);
    await tap(tester, find.text('Aan tafel!'));
    await tap(tester, find.widgetWithText(FilledButton, 'Inzetten'));
    expect(find.byType(GameSettingsSheet), findsNothing);
    expect(find.byType(StakeFlowSheet), findsOneWidget);
  });

  testWidgets(
    'sequential entry follows dealer, caps presets and reaches review',
    (tester) async {
      await controller.topUp(5);
      final game = controller.activeGame!;
      final order = game.stakeOrder;
      await mount(tester, GameScreen(controller: controller));
      await tap(tester, find.widgetWithText(FilledButton, 'Inzetten'));
      expect(find.text('INZET VOOR'), findsOneWidget);
      final disabled = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '€25'),
      );
      expect(disabled.onPressed, isNull);
      for (final p in order) {
        expect(
          find.descendant(
            of: find.byType(StakeFlowSheet),
            matching: find.text(p.name),
          ),
          findsOneWidget,
        );
        await tap(tester, find.widgetWithText(FilledButton, '€1'));
        expect(controller.activeGame!.draftStakes[p.id], 1);
      }
      expect(find.byType(StakeFlowSheet), findsNothing);
      await tap(tester, find.widgetWithText(OutlinedButton, 'Ronde afronden'));
      expect(controller.activeGame!.rounds.length, 1); // only top-up booked
      await tap(
        tester,
        find.widgetWithText(RadioListTile<String>, order.first.name),
      );
      expect(find.text('Uitkomst bevestigen'), findsOneWidget);
      await tap(tester, find.text('Uitkomst bevestigen'));
      expect(controller.activeGame!.rounds.length, 2);
      expect(controller.activeGame!.dealerId, order.first.id);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'everyone-pass automatically prompts and only books after confirmation',
    (tester) async {
      await mount(tester, GameScreen(controller: controller));
      await tap(tester, find.widgetWithText(FilledButton, 'Inzetten'));
      for (var i = 0; i < 4; i++) {
        await tap(tester, find.widgetWithText(FilledButton, 'Pas'));
      }
      expect(find.text('Iedereen heeft gepast'), findsOneWidget);
      expect(controller.activeGame!.rounds, isEmpty);
      await tap(tester, find.widgetWithText(RadioListTile<String>, 'Jan'));
      await tap(tester, find.text('Uitkomst bevestigen'));
      expect(controller.activeGame!.pot, 7);
      expect(controller.activeGame!.rounds.single.kind, RoundKind.allPass);
    },
  );

  testWidgets(
    'undo cancellation changes nothing; confirmation restores without toast',
    (tester) async {
      await controller.topUp(2);
      await mount(tester, GameScreen(controller: controller));
      await tap(tester, find.byTooltip('Ongedaan maken'));
      await tap(tester, find.text('Annuleren'));
      expect(controller.activeGame!.pot, 12);
      await tap(tester, find.byTooltip('Ongedaan maken'));
      await tap(tester, find.widgetWithText(FilledButton, 'Ongedaan maken'));
      expect(controller.activeGame!.pot, 4);
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  testWidgets(
    'round settings validate invalid values and accept custom amount',
    (tester) async {
      await mount(
        tester,
        Scaffold(body: GameSettingsSheet(game: controller.activeGame!)),
      );
      await tester.enterText(find.byType(TextField).first, '0');
      tester.testTextInput.hide();
      await tester.pump();
      await tester.ensureVisible(find.text('Bedragen opslaan'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Bedragen opslaan'));
      await tester.pumpAndSettle();
      expect(
        find.text('Vul twee hele bedragen van 1 t/m 1000000 in.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'dealer reveal respects reduced motion and identifies first bettor',
    (tester) async {
      await mount(tester, DealerReveal(game: controller.activeGame!));
      expect(find.text('De eerste deler is…'), findsOneWidget);
      expect(
        find.text(
          '${controller.activeGame!.stakeOrder.first.name} begint met inzetten.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('game chart includes pot and every player at each event', (
    tester,
  ) async {
    await controller.topUp(2);
    await mount(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: GameChart(game: controller.activeGame!),
        ),
      ),
    );
    expect(find.text('Pot €12'), findsOneWidget);
    expect(find.byType(FilterChip), findsNWidgets(5));
    await tester.tap(find.byType(Slider), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('large-text phone layout remains usable', (tester) async {
    await mount(tester, GameScreen(controller: controller), scale: 1.6);
    expect(tester.takeException(), isNull);
  });

  test(
    'records are per unit and recompute after deleting a saved game',
    () async {
      await controller.topUp(5);
      final game = await controller.completeGame();
      expect(controller.recordFor(ScoreUnit.euro), 24);
      expect(controller.recordFor(ScoreUnit.dollar), 0);
      await controller.deleteHistoryGame(game.id);
      expect(controller.recordFor(ScoreUnit.euro), 0);
    },
  );

  test(
    'failed save preserves active state; all-data delete clears every category',
    () async {
      repository.failSave = true;
      await expectLater(controller.topUp(2), throwsStateError);
      expect(controller.activeGame!.pot, 4);
      repository.failSave = false;
      await controller.clearAllData();
      expect(controller.activeGame, isNull);
      expect(controller.rememberedPlayers, isEmpty);
      expect(controller.history, isEmpty);
      expect(repository.games, isEmpty);
    },
  );
}
