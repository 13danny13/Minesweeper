import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:minesweeper/game.dart';
import 'package:minesweeper/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('First move and its neighbors are safe on every difficulty', () {
    for (final difficulty in Difficulty.values) {
      for (final first in [
        0,
        difficulty.columns + 1,
        difficulty.rows * difficulty.columns - 1,
      ]) {
        final game = MineGame(difficulty)..reveal(first, random: Random(42));
        expect(game.mines.length, difficulty.mines);
        expect(game.mines.contains(first), isFalse);
        expect(game.neighbors(first).any(game.mines.contains), isFalse);
        expect(game.revealed.contains(first), isTrue);
        expect(game.revealed.intersection(game.mines), isEmpty);
      }
    }
  });

  test('Corner neighbors do not wrap around rows', () {
    final game = MineGame(Difficulty.easy);
    expect(game.neighbors(0).toSet(), {1, 9, 10});
    expect(game.neighbors(8).toSet(), {7, 16, 17});
  });

  test('Flags prevent opening and respect mine count', () {
    final game = MineGame(Difficulty.easy);
    for (var i = 0; i < 11; i++) {
      game.toggleFlag(i);
    }
    expect(game.flags.length, 10);
    game.reveal(0);
    expect(game.generated, isFalse);
    game.toggleFlag(0);
    game.reveal(0, random: Random(5));
    expect(game.revealed.contains(0), isTrue);
    game.toggleFlag(0);
    expect(game.flags.contains(0), isFalse);
  });

  test('Opening all safe cells wins and freezes the game', () {
    final game = MineGame(Difficulty.easy)..reveal(40, random: Random(13));
    for (var i = 0; i < game.size; i++) {
      if (!game.mines.contains(i) && !game.revealed.contains(i)) game.reveal(i);
    }
    expect(game.status, GameStatus.won);
    expect(game.revealed.length, game.size - game.difficulty.mines);
    expect(game.remaining, 0);
    final before = game.toJson();
    game.reveal(game.mines.first);
    game.toggleFlag(game.mines.first);
    expect(game.toJson(), before);
  });

  test('Opening a mine loses', () {
    final game = MineGame(Difficulty.easy)..reveal(0, random: Random(4));
    final mine = game.mines.first;
    game.reveal(mine);
    expect(game.status, GameStatus.lost);
    expect(game.exploded, mine);
  });

  test('Chord opens neighbors only when flags match the number', () {
    final game = MineGame(Difficulty.easy)..reveal(40, random: Random(8));
    final number = game.revealed.firstWhere(
      (i) =>
          game.adjacent(i) > 0 &&
          game
              .neighbors(i)
              .any(
                (n) => !game.mines.contains(n) && !game.revealed.contains(n),
              ),
    );
    final before = game.revealed.length;
    game.reveal(number);
    expect(game.revealed.length, before);
    for (final n in game.neighbors(number).where(game.mines.contains)) {
      game.toggleFlag(n);
    }
    game.reveal(number);
    expect(game.revealed.length, greaterThan(before));
    expect(game.status, isNot(GameStatus.lost));
  });

  test('Board, time and flags survive serialization', () {
    final game = MineGame(Difficulty.medium)
      ..reveal(0, random: Random(7))
      ..seconds = 123;
    game.toggleFlag(game.mines.first);
    expect(MineGame.fromJson(game.toJson()).toJson(), game.toJson());
  });

  test('Storage resumes a game and saves completed result only once', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = GameStore(prefs);
    final game = MineGame(Difficulty.easy)
      ..reveal(0, random: Random(4))
      ..seconds = 42;
    store.active = game;
    await store.save();
    expect(GameStore(prefs).active!.toJson(), game.toJson());
    game.reveal(game.mines.first);
    await store.finish(game);
    await store.finish(game);
    final restored = GameStore(prefs);
    expect(restored.active, isNull);
    expect(restored.records, hasLength(1));
    expect(restored.records.first.seconds, 42);
    expect(restored.records.first.won, isFalse);
  });

  test('Corrupt storage does not prevent starting a new game', () async {
    SharedPreferences.setMockInitialValues({'minesweeper.v1': '{broken'});
    final store = GameStore(await SharedPreferences.getInstance());
    expect(store.active, isNull);
    expect(store.warning, isNotNull);
  });
}
