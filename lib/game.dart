import 'dart:math';

enum Difficulty {
  easy('Новичок', 9, 9, 10),
  medium('Любитель', 12, 12, 24),
  hard('Эксперт', 16, 16, 50);

  const Difficulty(this.label, this.rows, this.columns, this.mines);
  final String label;
  final int rows;
  final int columns;
  final int mines;
}

enum GameStatus { playing, won, lost }

class MineGame {
  MineGame(this.difficulty)
    : mines = <int>{},
      revealed = <int>{},
      flags = <int>{};

  final Difficulty difficulty;
  final Set<int> mines;
  final Set<int> revealed;
  final Set<int> flags;
  bool generated = false;
  int seconds = 0;
  GameStatus status = GameStatus.playing;
  int? exploded;
  String id = DateTime.now().microsecondsSinceEpoch.toString();

  int get size => difficulty.rows * difficulty.columns;
  int get remaining => difficulty.mines - flags.length;
  int get score => status == GameStatus.won
      ? max(100, difficulty.mines * 1000 - seconds * 5)
      : revealed.length * 10;

  Iterable<int> neighbors(int index) sync* {
    final row = index ~/ difficulty.columns;
    final col = index % difficulty.columns;
    for (var dr = -1; dr <= 1; dr++) {
      for (var dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        final r = row + dr;
        final c = col + dc;
        if (r >= 0 && r < difficulty.rows && c >= 0 && c < difficulty.columns) {
          yield r * difficulty.columns + c;
        }
      }
    }
  }

  int adjacent(int index) => neighbors(index).where(mines.contains).length;

  void toggleFlag(int index) {
    if (status != GameStatus.playing || revealed.contains(index)) return;
    if (!flags.remove(index) && flags.length < difficulty.mines) {
      flags.add(index);
    }
  }

  void reveal(int index, {Random? random}) {
    if (status != GameStatus.playing || flags.contains(index)) return;
    if (!generated) {
      // The first cell and its neighbors are always safe.
      final safe = {index, ...neighbors(index)};
      final candidates = List.generate(
        size,
        (i) => i,
      ).where((i) => !safe.contains(i)).toList()..shuffle(random ?? Random());
      mines.addAll(candidates.take(difficulty.mines));
      generated = true;
    }
    if (revealed.contains(index)) {
      // Open around a number once the matching number of flags is placed.
      if (adjacent(index) > 0 &&
          neighbors(index).where(flags.contains).length == adjacent(index)) {
        for (final n in neighbors(index).toList()) {
          if (!revealed.contains(n) && !flags.contains(n)) _open(n);
          if (status != GameStatus.playing) break;
        }
      }
    } else {
      _open(index);
    }
    if (status == GameStatus.playing &&
        revealed.length == size - difficulty.mines) {
      status = GameStatus.won;
      flags.addAll(mines);
    }
  }

  void _open(int index) {
    if (mines.contains(index)) {
      exploded = index;
      status = GameStatus.lost;
      return;
    }
    final pending = [index];
    while (pending.isNotEmpty) {
      final current = pending.removeLast();
      if (flags.contains(current) || !revealed.add(current)) continue;
      if (adjacent(current) == 0) {
        pending.addAll(
          neighbors(current).where(
            (n) =>
                !revealed.contains(n) &&
                !flags.contains(n) &&
                !mines.contains(n),
          ),
        );
      }
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'difficulty': difficulty.name,
    'mines': mines.toList(),
    'revealed': revealed.toList(),
    'flags': flags.toList(),
    'generated': generated,
    'seconds': seconds,
    'status': status.name,
    'exploded': exploded,
  };

  factory MineGame.fromJson(Map<String, dynamic> json) {
    final game =
        MineGame(Difficulty.values.byName(json['difficulty'] as String))
          ..id = json['id'] as String
          ..generated = json['generated'] as bool
          ..seconds = json['seconds'] as int
          ..status = GameStatus.values.byName(json['status'] as String)
          ..exploded = json['exploded'] as int?;
    game.mines.addAll((json['mines'] as List).cast<int>());
    game.revealed.addAll((json['revealed'] as List).cast<int>());
    game.flags.addAll((json['flags'] as List).cast<int>());
    final cells = {...game.mines, ...game.revealed, ...game.flags};
    if (cells.any((i) => i < 0 || i >= game.size) ||
        game.seconds < 0 ||
        (game.generated && game.mines.length != game.difficulty.mines) ||
        (!game.generated && game.mines.isNotEmpty) ||
        game.revealed.intersection(game.mines).isNotEmpty ||
        game.revealed.intersection(game.flags).isNotEmpty) {
      throw const FormatException('Некорректное сохранение');
    }
    return game;
  }
}

String formatTime(int seconds) =>
    '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
