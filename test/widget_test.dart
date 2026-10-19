import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minesweeper/main.dart';
import 'package:minesweeper/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Menu opens a game, saves a move and resumes it', (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final store = GameStore(await SharedPreferences.getInstance());
    await tester.pumpWidget(MinesweeperApp(store: store));
    await tester.ensureVisible(find.text('Новая игра'));
    await tester.tap(find.text('Новая игра'));
    await tester.pumpAndSettle();
    expect(find.text('Первый ход всегда безопасен'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('cell-0')));
    await tester.pumpAndSettle();
    expect(store.active!.generated, isTrue);
    final id = store.active!.id;
    await tester.tap(find.byTooltip('Сохранить и выйти'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.textContaining('Продолжить'));
    await tester.tap(find.textContaining('Продолжить'));
    await tester.pumpAndSettle();
    expect(store.active!.id, id);
    final mine = store.active!.mines.first;
    await tester.ensureVisible(find.byKey(ValueKey('cell-$mine')));
    await tester.tap(find.byKey(ValueKey('cell-$mine')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Мина найдена.'), findsOneWidget);
    expect(store.records, hasLength(1));
    expect(store.active, isNull);
    await tester.ensureVisible(find.text('Рекорды и история'));
    await tester.tap(find.text('Рекорды и история'));
    await tester.pumpAndSettle();
    expect(find.text('Поражение · Новичок'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('History screen shows empty state and difficulty filters', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = GameStore(await SharedPreferences.getInstance());
    await tester.pumpWidget(MaterialApp(home: RecordsScreen(store: store)));
    expect(find.text('Лучшие времена'), findsOneWidget);
    await tester.tap(find.text('Эксперт'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Первый рекорд'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
