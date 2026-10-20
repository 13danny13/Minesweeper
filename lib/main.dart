import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game.dart';
import 'storage.dart';

const ink = Color(0xFF182D37);
const teal = Color(0xFF087F73);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = GameStore(await SharedPreferences.getInstance());
  // Recover a completed board if the app closed before the results screen.
  if (store.active != null && store.active!.status != GameStatus.playing) {
    await store.finish(store.active!);
  }
  runApp(MinesweeperApp(store: store));
}

class MinesweeperApp extends StatelessWidget {
  const MinesweeperApp({super.key, required this.store});
  final GameStore store;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Минное поле',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: teal),
      scaffoldBackgroundColor: const Color(0xFFF4F6F3),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF4F6F3),
        foregroundColor: ink,
        centerTitle: false,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontWeight: FontWeight.w800, color: ink),
        headlineMedium: TextStyle(fontWeight: FontWeight.w800, color: ink),
        titleLarge: TextStyle(fontWeight: FontWeight.w700, color: ink),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(0, 54)),
      ),
    ),
    home: HomeScreen(store: store),
  );
}

Route<T> smoothRoute<T>(Widget page) => PageRouteBuilder<T>(
  pageBuilder: (_, animation, secondaryAnimation) => page,
  transitionDuration: const Duration(milliseconds: 300),
  transitionsBuilder: (_, animation, secondaryAnimation, child) =>
      FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, .04),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        ),
      ),
);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store});
  final GameStore store;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Difficulty selected = Difficulty.easy;

  Future<void> play({bool resume = false}) async {
    if (!resume && widget.store.active != null) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Начать заново?'),
          content: const Text('Текущая незавершённая игра будет заменена.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Новая игра'),
            ),
          ],
        ),
      );
      if (replace != true || !mounted) return;
    }
    final game = resume ? widget.store.active! : MineGame(selected);
    widget.store.active = game;
    await widget.store.save();
    if (!mounted) return;
    await Navigator.push(
      context,
      smoothRoute(GameScreen(store: widget.store, game: game)),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final wins = widget.store.records.where((r) => r.won).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'МИННОЕ ПОЛЕ',
          style: TextStyle(
            fontSize: 14,
            letterSpacing: 3,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Как играть',
            icon: const Icon(Icons.help_outline),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Найдите безопасный путь'),
                content: const Text(
                  'Откройте все клетки без мин. Число показывает, сколько мин рядом, включая диагонали.\n\nДолгое нажатие ставит флаг. Можно также включить режим флажков. Нажмите открытое число, чтобы раскрыть соседей, когда рядом достаточно флажков.\n\nПервый ход всегда безопасен. Таймер идёт только пока поле открыто. Игра сохраняется автоматически.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Понятно'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: HeightAdaptiveMenu(
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: ink,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.blur_on_rounded,
                      color: Color(0xFF9DE4BF),
                      size: 52,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Меньше спешки.\nБольше логики.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Раскройте поле. Доверьтесь числам.\nОставьте мины нетронутыми.',
                      style: TextStyle(color: Color(0xFFB9CDC9), height: 1.6),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '$wins побед  •  ${widget.store.records.length} игр в истории',
                      style: const TextStyle(color: Color(0xFF9DE4BF)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Ваш уровень',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              for (final difficulty in Difficulty.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: selected == difficulty
                        ? const Color(0xFFE0EEE7)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => setState(() => selected = difficulty),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            Icon(
                              selected == difficulty
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              color: teal,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    difficulty.label,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    '${difficulty.rows} × ${difficulty.columns}  ·  ${difficulty.mines} мин',
                                    style: const TextStyle(
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              [
                                Icons.spa_outlined,
                                Icons.landscape_outlined,
                                Icons.bolt,
                              ][difficulty.index],
                              color: teal,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => play(),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Новая игра'),
              ),
              if (widget.store.active != null) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => play(resume: true),
                  icon: const Icon(Icons.history),
                  label: Text(
                    'Продолжить · ${formatTime(widget.store.active!.seconds)}',
                  ),
                ),
              ],
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  smoothRoute(RecordsScreen(store: widget.store)),
                ),
                icon: const Icon(Icons.emoji_events_outlined),
                label: const Text('Рекорды и история'),
              ),
              if (widget.store.warning != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    widget.store.warning!,
                    style: const TextStyle(color: Colors.deepOrange),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Scale the whole menu with the usable height while retaining vertical scroll
/// on very short screens and when accessibility text makes content taller.
class HeightAdaptiveMenu extends StatelessWidget {
  const HeightAdaptiveMenu({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final scale = (constraints.maxHeight / 1050).clamp(.7, 1.1);
        return SingleChildScrollView(
          child: SizedBox(
            width: constraints.maxWidth,
            child: FittedBox(
              fit: BoxFit.fitWidth,
              alignment: Alignment.topCenter,
              child: SizedBox(
                key: const ValueKey('menu-content'),
                width: constraints.maxWidth / scale,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.store, required this.game});
  final GameStore store;
  final MineGame game;
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  Timer? timer;
  bool flagMode = false;
  bool foreground = true;
  bool finishing = false;
  MineGame get game => widget.game;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (foreground && game.generated && game.status == GameStatus.playing) {
        setState(() => game.seconds++);
        unawaited(widget.store.save());
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    unawaited(widget.store.save());
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> move(int index, {bool flag = false}) async {
    if (finishing || game.status != GameStatus.playing) return;
    setState(() {
      if (flag || flagMode) {
        game.toggleFlag(index);
      } else {
        game.reveal(index);
      }
    });
    if (game.status == GameStatus.playing) {
      await widget.store.save();
    } else {
      finishing = true;
      timer?.cancel();
      await widget.store.finish(game);
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        smoothRoute(ResultScreen(store: widget.store, game: game)),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(game.difficulty.label),
      actions: [
        IconButton(
          tooltip: 'Сохранить и выйти',
          onPressed: () async {
            await widget.store.save();
            if (context.mounted) Navigator.pop(context);
          },
          icon: const Icon(Icons.save_outlined),
        ),
      ],
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        icon: Icons.flag_outlined,
                        value: '${game.remaining}',
                        label: 'Осталось мин',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatTile(
                        icon: Icons.timer_outlined,
                        value: formatTime(game.seconds),
                        label: 'Время',
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, size: 16, color: teal),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        !game.generated
                            ? 'Первый ход всегда безопасен'
                            : 'Открыто ${game.revealed.length} из ${game.size - game.difficulty.mines}',
                        style: const TextStyle(color: teal, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Fit every difficulty to the viewport before manual zoom.
                    final width = (constraints.maxWidth - 24).clamp(
                      0.0,
                      double.infinity,
                    );
                    final height =
                        width * game.difficulty.rows / game.difficulty.columns;
                    return InteractiveViewer(
                      key: ValueKey('board-viewport-${constraints.maxWidth}'),
                      constrained: false,
                      minScale: 1,
                      maxScale: 2.5,
                      boundaryMargin: const EdgeInsets.all(24),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: SizedBox(
                          key: const ValueKey('game-board'),
                          width: width,
                          height: height,
                          child: GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            padding: EdgeInsets.zero,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: game.difficulty.columns,
                                  mainAxisSpacing: 3,
                                  crossAxisSpacing: 3,
                                ),
                            itemCount: game.size,
                            itemBuilder: (context, index) => buildCell(index),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: false,
                          icon: Icon(Icons.touch_app_outlined),
                          label: Text('Открывать'),
                        ),
                        ButtonSegment(
                          value: true,
                          icon: Icon(Icons.flag_outlined),
                          label: Text('Флажки'),
                        ),
                      ],
                      selected: {flagMode},
                      onSelectionChanged: (value) =>
                          setState(() => flagMode = value.first),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Удерживайте клетку, чтобы поставить флаг.\nПоле можно двигать и увеличивать.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    if (widget.store.warning != null)
                      Text(
                        widget.store.warning!,
                        style: const TextStyle(color: Colors.deepOrange),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget buildCell(int index) {
    final open = game.revealed.contains(index);
    final flag = game.flags.contains(index);
    final mine =
        game.status != GameStatus.playing && game.mines.contains(index);
    final wrongFlag =
        game.status == GameStatus.lost && flag && !game.mines.contains(index);
    final count = open ? game.adjacent(index) : 0;
    final color = index == game.exploded
        ? const Color(0xFFF5AAA0)
        : open
        ? const Color(0xFFE7ECE6)
        : const Color(0xFFCDDDD5);
    const numberColors = [
      Colors.transparent,
      Color(0xFF2868AC),
      teal,
      Color(0xFFBF4D39),
      Color(0xFF6E4E9A),
      Color(0xFFA36A24),
      Color(0xFF267F87),
      ink,
      Colors.black,
    ];
    return Semantics(
      key: ValueKey('cell-$index'),
      label:
          'Строка ${index ~/ game.difficulty.columns + 1}, столбец ${index % game.difficulty.columns + 1}, ${mine
              ? 'мина'
              : flag
              ? 'флаг'
              : open
              ? count == 0
                    ? 'пусто'
                    : '$count мин рядом'
              : 'закрыто'}',
      button: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: open ? const Color(0xFFDDE5DC) : Colors.white54,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => move(index),
            onLongPress: () => move(index, flag: true),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: wrongFlag
                      ? const Icon(Icons.close, size: 20, color: Colors.red)
                      : mine
                      ? const Icon(Icons.brightness_7, size: 22, color: ink)
                      : flag
                      ? const Icon(Icons.flag_rounded, size: 22, color: teal)
                      : count > 0
                      ? Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: numberColors[count],
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        Icon(icon, color: teal),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.store, required this.game});
  final GameStore store;
  final MineGame game;
  @override
  Widget build(BuildContext context) {
    final won = game.status == GameStatus.won;
    return Scaffold(
      appBar: AppBar(title: const Text('Результат')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(28),
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: .6, end: 1),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (_, value, child) =>
                    Transform.scale(scale: value, child: child),
                child: CircleAvatar(
                  radius: 56,
                  backgroundColor: won
                      ? const Color(0xFFD7EDDF)
                      : const Color(0xFFF5DED6),
                  child: Icon(
                    won ? Icons.emoji_events_rounded : Icons.spa_outlined,
                    size: 58,
                    color: teal,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                won ? 'Чистая победа!' : 'Мина найдена.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 12),
              Text(
                won
                    ? 'Все безопасные клетки открыты. Отличная работа!'
                    : 'Каждая попытка учит замечать больше. Попробуем ещё?',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54, height: 1.5),
              ),
              const SizedBox(height: 28),
              StatTile(
                icon: Icons.star_outline,
                value: '${game.score}',
                label: 'Очки · ${game.difficulty.label}',
              ),
              const SizedBox(height: 12),
              StatTile(
                icon: Icons.timer_outlined,
                value: formatTime(game.seconds),
                label: 'Время игры',
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: () async {
                  final next = MineGame(game.difficulty);
                  store.active = next;
                  await store.save();
                  if (context.mounted) {
                    Navigator.pushReplacement(
                      context,
                      smoothRoute(GameScreen(store: store, game: next)),
                    );
                  }
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Сыграть ещё'),
              ),
              TextButton(
                onPressed: () => Navigator.pushReplacement(
                  context,
                  smoothRoute(RecordsScreen(store: store)),
                ),
                child: const Text('Рекорды и история'),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.popUntil(context, (route) => route.isFirst),
                child: const Text('В главное меню'),
              ),
              if (store.warning != null)
                Text(
                  store.warning!,
                  style: const TextStyle(color: Colors.deepOrange),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key, required this.store});
  final GameStore store;
  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  Difficulty selected = Difficulty.easy;
  @override
  Widget build(BuildContext context) {
    final wins =
        widget.store.records
            .where((r) => r.won && r.difficulty == selected)
            .toList()
          ..sort((a, b) => a.seconds.compareTo(b.seconds));
    return Scaffold(
      appBar: AppBar(title: const Text('Рекорды и история')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Лучшие времена',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: Difficulty.values
                    .map(
                      (d) => ChoiceChip(
                        label: Text(d.label),
                        selected: selected == d,
                        onSelected: (_) => setState(() => selected = d),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              if (wins.isEmpty)
                const EmptyCard(
                  text:
                      'Первый рекорд ещё впереди.\nЗавершите игру без единой мины.',
                )
              else
                for (var i = 0; i < wins.length && i < 5; i++)
                  Card(
                    color: Colors.white,
                    elevation: 0,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFE0EEE7),
                        child: Text('${i + 1}'),
                      ),
                      title: Text(
                        formatTime(wins[i].seconds),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(dateLabel(wins[i].date)),
                      trailing: Text('${wins[i].score} очков'),
                    ),
                  ),
              const SizedBox(height: 28),
              Text(
                'История игр',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              const Text(
                'Последние 200 завершённых игр',
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
              const SizedBox(height: 12),
              if (widget.store.records.isEmpty)
                const EmptyCard(
                  text:
                      'Здесь появятся ваши игры.\nНачните с уровня «Новичок».',
                )
              else
                for (final record in widget.store.records)
                  Card(
                    color: Colors.white,
                    elevation: 0,
                    child: ListTile(
                      leading: Icon(
                        record.won
                            ? Icons.emoji_events_outlined
                            : Icons.brightness_7_outlined,
                        color: record.won ? teal : Colors.deepOrange,
                      ),
                      title: Text(
                        '${record.won ? 'Победа' : 'Поражение'} · ${record.difficulty.label}',
                      ),
                      subtitle: Text(
                        '${dateLabel(record.date)} · ${record.score} очков',
                      ),
                      trailing: Text(formatTime(record.seconds)),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

String dateLabel(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

class EmptyCard extends StatelessWidget {
  const EmptyCard({super.key, required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      children: [
        const Icon(Icons.outlined_flag, size: 38, color: teal),
        const SizedBox(height: 12),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black54, height: 1.5),
        ),
      ],
    ),
  );
}
