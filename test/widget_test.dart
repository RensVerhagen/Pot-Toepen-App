import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pot_toepen/domain/models.dart';
import 'package:pot_toepen/ui/app_theme.dart';
import 'package:pot_toepen/ui/widgets/app_widgets.dart';

void main() {
  testWidgets('pot display formats and animates points', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: const Scaffold(body: PotDisplay(value: 12, unit: ScoreUnit.points)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('12 pt'), findsOneWidget);
    expect(find.text('IN DE POT'), findsOneWidget);
  });
}
