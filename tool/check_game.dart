// Dependency-free check for constrained environments. The Flutter suite also
// covers widgets and persistent storage: flutter test.
import 'dart:io';
import 'dart:math';

// Keep this runner usable before package resolution in constrained environments.
// ignore: avoid_relative_lib_imports
import '../lib/game.dart';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

void main() {
  var boards = 0;
  for (final difficulty in Difficulty.values) {
    for (var seed = 0; seed < 100; seed++) {
      final game = MineGame(difficulty);
      final first = Random(seed).nextInt(game.size);
      game.reveal(first, random: Random(seed));
      check(game.mines.length == difficulty.mines, 'Incorrect mine count');
      check(!game.mines.contains(first), 'Unsafe first move');
      check(!game.neighbors(first).any(game.mines.contains), 'Unsafe opening');
      check(
        game.revealed.intersection(game.mines).isEmpty,
        'Flood revealed mine',
      );
      game.seconds = seed;
      game.toggleFlag(game.mines.first);
      final restored = MineGame.fromJson(game.toJson());
      check(restored.flags.contains(game.mines.first), 'Lost flag');
      check(restored.seconds == seed, 'Lost timer');
      for (var i = 0; i < game.size; i++) {
        if (!game.mines.contains(i) && !game.revealed.contains(i)) {
          game.reveal(i);
        }
      }
      check(game.status == GameStatus.won, 'Safe solution did not win');
      check(game.remaining == 0, 'Winning flags incomplete');
      restored.toggleFlag(restored.mines.first);
      restored.reveal(restored.mines.first);
      check(restored.status == GameStatus.lost, 'Mine did not end game');
      final before = restored.revealed.length;
      restored.reveal(first);
      check(restored.revealed.length == before, 'Move accepted after game end');
      boards++;
    }
  }
  check(
    MineGame(Difficulty.easy).neighbors(0).join(',') == '1,9,10',
    'Corner neighbors wrap',
  );
  stdout.writeln(
    'PASS: $boards boards; safe openings, flood fill, victory, defeat, '
    'flags, frozen final state, serialization and timer.',
  );
}
