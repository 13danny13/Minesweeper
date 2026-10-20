import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minesweeper/game.dart';
import 'package:minesweeper/main.dart';
import 'package:minesweeper/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Every difficulty fits narrow and wide screens after resizing', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final store = GameStore(await SharedPreferences.getInstance());
    for (final difficulty in Difficulty.values) {
      final game = MineGame(difficulty);
      store.active = game;
      await tester.pumpWidget(
        MaterialApp(
          home: GameScreen(key: ValueKey(difficulty), store: store, game: game),
        ),
      );
      for (final width in [320.0, 390.0, 600.0]) {
        await tester.binding.setSurfaceSize(Size(width, 1000));
        await tester.pumpAndSettle();
        final board = tester.getRect(find.byKey(const ValueKey('game-board')));
        expect(board.width, closeTo(width - 24, .01));
        expect(board.left, greaterThanOrEqualTo(0));
        expect(board.right, lessThanOrEqualTo(width));
        expect(tester.takeException(), isNull);
      }
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Menu shrinks with height and keeps actions visible on a phone', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final store = GameStore(await SharedPreferences.getInstance())
      ..active = MineGame(Difficulty.easy);
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    await tester.pumpWidget(MinesweeperApp(store: store));
    await tester.pumpAndSettle();
    final tallHero = tester.getRect(
      find.text('Меньше спешки.\nБольше логики.'),
    );
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpAndSettle();
    final shortHero = tester.getRect(
      find.text('Меньше спешки.\nБольше логики.'),
    );
    expect(shortHero.height, lessThan(tallHero.height));
    final records = tester.getRect(find.text('Рекорды и история'));
    expect(records.bottom, lessThanOrEqualTo(844));
    expect(find.textContaining('Продолжить'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Landscape/short windows retain scrolling rather than losing actions.
    await tester.binding.setSurfaceSize(const Size(600, 360));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Рекорды и история'));
    await tester.tap(find.text('Рекорды и история'));
    await tester.pumpAndSettle();
    expect(find.text('Лучшие времена'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
