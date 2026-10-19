import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'game.dart';

class GameRecord {
  GameRecord({
    required this.id,
    required this.difficulty,
    required this.won,
    required this.seconds,
    required this.score,
    required this.date,
  });

  factory GameRecord.fromGame(MineGame game) => GameRecord(
    id: game.id,
    difficulty: game.difficulty,
    won: game.status == GameStatus.won,
    seconds: game.seconds,
    score: game.score,
    date: DateTime.now(),
  );

  final String id;
  final Difficulty difficulty;
  final bool won;
  final int seconds;
  final int score;
  final DateTime date;

  Map<String, dynamic> toJson() => {
    'id': id,
    'difficulty': difficulty.name,
    'won': won,
    'seconds': seconds,
    'score': score,
    'date': date.toIso8601String(),
  };

  factory GameRecord.fromJson(Map<String, dynamic> json) => GameRecord(
    id: json['id'] as String,
    difficulty: Difficulty.values.byName(json['difficulty'] as String),
    won: json['won'] as bool,
    seconds: json['seconds'] as int,
    score: json['score'] as int,
    date: DateTime.parse(json['date'] as String),
  );
}

class GameStore {
  GameStore(this.preferences) {
    final raw = preferences.getString('minesweeper.v1');
    if (raw == null) return;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['active'] != null) {
        active = MineGame.fromJson(json['active'] as Map<String, dynamic>);
      }
      records.addAll(
        (json['records'] as List).map(
          (r) => GameRecord.fromJson(r as Map<String, dynamic>),
        ),
      );
    } catch (_) {
      active = null;
      records.clear();
      warning = 'Сохранение повреждено. Можно начать новую игру.';
    }
  }

  final SharedPreferences preferences;
  MineGame? active;
  final List<GameRecord> records = [];
  String? warning;
  Future<void> _pending = Future.value();

  // Serialize writes so a slow earlier save cannot overwrite a later move.
  Future<void> save() {
    final value = jsonEncode({
      'active': active?.toJson(),
      'records': records.map((r) => r.toJson()).toList(),
    });
    _pending = _pending.then((_) async {
      try {
        if (!await preferences.setString('minesweeper.v1', value)) {
          warning = 'Не удалось сохранить игру на устройстве.';
        }
      } catch (_) {
        warning = 'Не удалось сохранить игру на устройстве.';
      }
    });
    return _pending;
  }

  Future<void> finish(MineGame game) {
    if (!records.any((r) => r.id == game.id)) {
      records.insert(0, GameRecord.fromGame(game));
      if (records.length > 200) records.removeRange(200, records.length);
    }
    active = null;
    return save();
  }
}
