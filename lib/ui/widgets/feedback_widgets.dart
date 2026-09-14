import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/app_controller.dart';
import '../../domain/models.dart';
import '../app_theme.dart';
import 'app_widgets.dart';

Future<bool> confirmAction(
  BuildContext context,
  String title,
  String message, {
  String action = 'Bevestigen',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuleren'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;

class GameSettingsSheet extends StatefulWidget {
  const GameSettingsSheet({super.key, required this.game});
  final GameRecord game;
  @override
  State<GameSettingsSheet> createState() => _GameSettingsSheetState();
}

class _GameSettingsSheetState extends State<GameSettingsSheet> {
  late final _trek = TextEditingController(
    text: '${widget.game.toepTrekAmount}',
  );
  late final _pass = TextEditingController(
    text: '${widget.game.allPassAmount}',
  );
  String? _error;
  @override
  void dispose() {
    _trek.dispose();
    _pass.dispose();
    super.dispose();
  }

  Widget _amount(String label, String hint, TextEditingController controller) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(hint),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final n in [1, 2, 3, 5, 10])
                ChoiceChip(
                  label: Text(widget.game.unit.format(n)),
                  selected: controller.text == '$n',
                  onSelected: (_) => setState(() => controller.text = '$n'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Eigen bedrag · $label',
              suffixText: widget.game.unit.symbol,
            ),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      8,
      20,
      24 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const StatusPill(
            label: 'VOOR HET HELE SPEL',
            icon: Icons.tune_rounded,
            color: AppColors.gold,
          ),
          const SizedBox(height: 18),
          const Text(
            'Deze bedragen staan vast voor het hele spel en kunnen daarna niet meer worden gewijzigd.',
          ),
          const SizedBox(height: 18),
          _amount(
            'Toep-trek',
            'De gekozen speler ontvangt dit uit de pot.',
            _trek,
          ),
          const SizedBox(height: 24),
          _amount(
            'Iedereen past',
            'Wie de hoogste hand heeft, betaalt deze boete.',
            _pass,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.coral),
              ),
            ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.check_rounded),
            label: const Text('Bedragen opslaan'),
            onPressed: () {
              final trek = int.tryParse(_trek.text);
              final pass = int.tryParse(_pass.text);
              if (trek == null ||
                  pass == null ||
                  trek < 1 ||
                  pass < 1 ||
                  trek > 1000000 ||
                  pass > 1000000) {
                setState(
                  () => _error = 'Vul twee hele bedragen van 1 t/m 1000000 in.',
                );
              } else {
                Navigator.pop(context, [trek, pass]);
              }
            },
          ),
        ],
      ),
    ),
  );
}

class DealerReveal extends StatefulWidget {
  const DealerReveal({super.key, required this.game});
  final GameRecord game;
  @override
  State<DealerReveal> createState() => _DealerRevealState();
}

class _DealerRevealState extends State<DealerReveal> {
  Timer? _timer;
  int _tick = 0;
  int _index = 0;
  bool _done = false;
  bool _started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _index = widget.game.players.indexWhere(
        (p) => p.id == widget.game.dealerId,
      );
      _done = true;
    } else {
      _next();
    }
  }

  void _next() {
    _timer = Timer(
      Duration(milliseconds: 65 + (_tick * _tick * .9).round()),
      () {
        if (!mounted) return;
        setState(() {
          _tick++;
          _done = _tick >= 20;
          _index = _done
              ? widget.game.players.indexWhere(
                  (p) => p.id == widget.game.dealerId,
                )
              : (_index + 1) % widget.game.players.length;
        });
        HapticFeedback.selectionClick();
        if (!_done) _next();
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _done,
    child: Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.casino_rounded, color: AppColors.gold, size: 46),
              const SizedBox(height: 16),
              Text(
                _done ? 'De eerste deler is…' : 'Wie schudt de kaarten?',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 24),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 100),
                child: Text(
                  widget.game.players[_index].name,
                  key: ValueKey(_index),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall
                      ?.copyWith(color: AppColors.gold),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var i = 0; i < widget.game.players.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: i == _index ? AppColors.gold : AppColors.raised,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        widget.game.players[i].name,
                        style: TextStyle(
                          color: i == _index
                              ? AppColors.black
                              : AppColors.mutedCream,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                _done
                    ? '${widget.game.stakeOrder.first.name} begint met inzetten.'
                    : 'Even schudden…',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _done ? () => Navigator.pop(context) : null,
                child: const Text('Aan tafel!'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class PlayerOrderSheet extends StatefulWidget {
  const PlayerOrderSheet({super.key, required this.game});
  final GameRecord game;
  @override
  State<PlayerOrderSheet> createState() => _PlayerOrderSheetState();
}

class _PlayerOrderSheetState extends State<PlayerOrderSheet>
    with SingleTickerProviderStateMixin {
  late final List<PlayerScore> _players = [...widget.game.players];
  late final AnimationController _wiggle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _wiggle.stop();
    } else if (!_wiggle.isAnimating) {
      _wiggle.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _wiggle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * .78,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeading(title: 'Spelers wijzigen'),
          const SizedBox(height: 8),
          const Text(
            'Sleep de rijen in tafelvolgorde. De speler na de deler begint.',
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              itemCount: _players.length,
              onReorderItem: (oldIndex, newIndex) {
                setState(() {
                  final p = _players.removeAt(oldIndex);
                  _players.insert(newIndex, p);
                });
                HapticFeedback.selectionClick();
              },
              itemBuilder: (context, i) => AnimatedBuilder(
                key: ValueKey(_players[i].id),
                animation: _wiggle,
                builder: (context, child) => Transform.rotate(
                  angle: (_wiggle.value - .5) * .018 * (i.isEven ? 1 : -1),
                  child: child,
                ),
                child: Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Text('${i + 1}')),
                    title: Text(_players[i].name),
                    subtitle: _players[i].id == widget.game.dealerId
                        ? const Text('Deler')
                        : null,
                    trailing: ReorderableDragStartListener(
                      index: i,
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Icon(Icons.drag_handle_rounded),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, _players.map((p) => p.id).toList()),
            child: const Text('Tafelvolgorde opslaan'),
          ),
        ],
      ),
    ),
  );
}

/// One shared time axis: each booked round or contribution is one step.
class GameChart extends StatefulWidget {
  const GameChart({super.key, required this.game});
  final GameRecord game;
  @override
  State<GameChart> createState() => _GameChartState();
}

class _GameChartState extends State<GameChart> {
  final Set<String> _hidden = {};
  int? _selected;
  static const colors = [
    AppColors.gold,
    AppColors.mint,
    AppColors.coral,
    Color(0xFF8EADFF),
    Color(0xFFED9BEF),
    Color(0xFF81DBEF),
    Color(0xFFE9AD78),
    Color(0xFFC7D98A),
    Color(0xFFB7A5E8),
  ];
  @override
  Widget build(BuildContext context) {
    final g = widget.game;
    final series = <String, List<int>>{
      'Pot': [
        g.rounds.isEmpty ? g.pot : g.rounds.first.potBefore,
        for (final r in g.rounds) r.potAfter,
      ],
      for (final p in g.players)
        p.name: [
          g.rounds.isEmpty ? p.score : g.rounds.first.scoresBefore[p.id]!,
          for (final r in g.rounds) r.scoresAfter[p.id]!,
        ],
    };
    final step = (_selected ?? g.rounds.length).clamp(0, g.rounds.length);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeading(title: 'Het verloop van de avond'),
          const SizedBox(height: 6),
          Text('Pot & cumulatieve scores · ${g.unit.label}'),
          const SizedBox(height: 18),
          Semantics(
            label: 'Grafiek van pot en spelersscores. Gebruik de schuifregelaar voor bedragen per stap.',
            child: SizedBox(
              height: 220,
              child: CustomPaint(
                painter: _ChartPainter(
                  series: series,
                  hidden: _hidden,
                  colors: colors,
                  selected: step,
                  fontFamily: Theme.of(context).textTheme.bodySmall?.fontFamily,
                ),
              ),
            ),
          ),
          Slider(
            value: step.toDouble(),
            max: math.max(1, g.rounds.length).toDouble(),
            divisions: math.max(1, g.rounds.length),
            label: 'Stap $step',
            onChanged: g.rounds.isEmpty
                ? null
                : (v) => setState(() => _selected = v.round()),
          ),
          Text(
            step == 0
                ? 'Start van het spel'
                : 'Stap $step · ${g.rounds[step - 1].kind.label}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < series.length; i++)
                FilterChip(
                  selected: !_hidden.contains(series.keys.elementAt(i)),
                  avatar: CircleAvatar(backgroundColor: colors[i], radius: 5),
                  label: Text(
                    '${series.keys.elementAt(i)} ${g.unit.format(series.values.elementAt(i)[step], showPlus: i > 0)}',
                  ),
                  onSelected: (v) => setState(() {
                    final key = series.keys.elementAt(i);
                    v ? _hidden.remove(key) : _hidden.add(key);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Hoogste pot: ${g.unit.format(g.highestPot)}'),
        ],
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.series,
    required this.hidden,
    required this.colors,
    required this.selected,
    required this.fontFamily,
  });
  final Map<String, List<int>> series;
  final Set<String> hidden;
  final List<Color> colors;
  final int selected;
  final String? fontFamily;
  @override
  void paint(Canvas canvas, Size size) {
    final values = series.values.expand((v) => v);
    final low = math.min(0, values.reduce(math.min));
    final high = math.max(1, values.reduce(math.max));
    final rect = Rect.fromLTRB(42, 8, size.width - 8, size.height - 22);
    double x(int i) =>
        rect.left +
        i / math.max(1, series.values.first.length - 1) * rect.width;
    double y(num v) => rect.bottom - (v - low) / (high - low) * rect.height;
    for (var i = 0; i <= 4; i++) {
      final value = low + (high - low) * i / 4;
      canvas.drawLine(
        Offset(rect.left, y(value)),
        Offset(rect.right, y(value)),
        Paint()..color = AppColors.cream.withValues(alpha: .12),
      );
      final label = TextPainter(
        text: TextSpan(
          text: '${value.round()}',
          style: TextStyle(
            color: AppColors.mutedCream,
            fontSize: 11,
            fontFamily: fontFamily,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(rect.left - label.width - 8, y(value) - 6));
    }
    canvas.drawLine(
      Offset(x(selected), rect.top),
      Offset(x(selected), rect.bottom),
      Paint()..color = AppColors.cream.withValues(alpha: .25),
    );
    for (var j = 0; j < series.length; j++) {
      if (hidden.contains(series.keys.elementAt(j))) continue;
      final points = series.values.elementAt(j);
      final path = Path()..moveTo(x(0), y(points[0]));
      for (var i = 1; i < points.length; i++) {
        path.lineTo(x(i), y(points[i]));
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = colors[j]
          ..strokeWidth = j == 0 ? 3 : 1.8
          ..style = PaintingStyle.stroke,
      );
      canvas.drawCircle(
        Offset(x(selected), y(points[selected])),
        4,
        Paint()..color = colors[j],
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) => true;
}

class GameHistorySheet extends StatelessWidget {
  const GameHistorySheet({super.key, required this.controller, this.onCleared});
  final AppController controller;
  final VoidCallback? onCleared;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => SizedBox(
      height: MediaQuery.sizeOf(context).height * .82,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Expanded(
                  child: SectionHeading(title: 'Spelgeschiedenis'),
                ),
                IconButton(
                  tooltip: 'Alle spelgegevens wissen',
                  icon: const Icon(Icons.delete_sweep_outlined),
                  onPressed: () async {
                    if (!await confirmAction(
                      context,
                      'Alle spelgegevens wissen?',
                      'Alle spellen, inclusief de actieve pot, records en opgeslagen spelers worden definitief verwijderd.',
                      action: 'Alles wissen',
                    )) {
                      return;
                    }
                    await controller.clearAllData();
                    if (context.mounted) {
                      Navigator.pop(context);
                      onCleared?.call();
                    }
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: controller.history.isEmpty
                ? const Center(child: Text('Nog geen afgeronde spellen.'))
                : ListView.builder(
                    itemCount: controller.history.length,
                    itemBuilder: (context, i) {
                      final game = controller.history[i];
                      final date = game.createdAt;
                      return ListTile(
                        title: Text(
                          game.players.map((p) => p.name).join(' · '),
                        ),
                        subtitle: Text(
                          '${date.day}-${date.month}-${date.year} · ${game.rounds.length} acties · record ${game.unit.format(game.highestPot)}',
                        ),
                        onTap: () => Navigator.pop(context, game),
                        trailing: IconButton(
                          tooltip: 'Spel verwijderen',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            if (await confirmAction(
                              context,
                              'Spel verwijderen?',
                              'Dit spel en het bijbehorende record worden verwijderd.',
                              action: 'Verwijderen',
                            )) {
                              await controller.deleteHistoryGame(game.id);
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
  );
}

class GameInfoSheet extends StatelessWidget {
  const GameInfoSheet({super.key, required this.game});
  final GameRecord game;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeading(title: 'Spelinformatie'),
          const SizedBox(height: 8),
          const Text(
            'Afgesproken bij de spelstart. Deze bedragen staan vast voor het hele spel.',
          ),
          const SizedBox(height: 20),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Toep-trek',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  game.unit.format(game.toepTrekAmount),
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(color: AppColors.gold),
                ),
                const Text('Winst uit de pot, maximaal wat er nog in zit.'),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(),
                ),
                Text(
                  'Iedereen past',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  game.unit.format(game.allPassAmount),
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(color: AppColors.gold),
                ),
                const Text(
                  'Bij teruguittoepen betaalt de speler met de hoogste hand dit aan de pot.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Passen is 0 inzetten. Je blijft meespelen en kunt winnen, maar ontvangt dan 0 uit de pot.',
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Terug naar het spel'),
          ),
        ],
      ),
    ),
  );
}
