import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../application/app_controller.dart';
import '../../domain/game_engine.dart';
import '../../domain/models.dart';
import '../app_theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/feedback_widgets.dart';
import 'results_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  RoundRecord? _celebration;
  late GameRecord _lastGame;
  bool _busy = false;
  int _recordLevel = 0;

  @override
  void initState() {
    super.initState();
    _lastGame = widget.controller.activeGame!;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_lastGame.dealerRevealed && mounted) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => DealerReveal(game: _lastGame),
        );
        if (mounted) await widget.controller.revealDealer();
      }
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, child) {
      final current = widget.controller.activeGame;
      if (current != null) _lastGame = current;
      final game = current ?? _lastGame;
      return PopScope(
        child: Stack(
          children: [
            FeltScaffold(
              appBar: AppBar(
                leading: const BackButton(),
                title: Text(
                  game.phase == GamePhase.normal
                      ? 'Ronde ${game.normalRoundCount + 1}'
                      : 'Finaleronde ${game.closingRoundIndex + 1}',
                ),
                actions: [
                  IconButton(
                    tooltip: 'Ongedaan maken',
                    onPressed: _canUndo(game) ? _undo : null,
                    icon: const Icon(Icons.undo_rounded),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Meer',
                    onSelected: (value) => switch (value) {
                      'info' => _showGameInfo(game),
                      'history' => _showHistory(),
                      'games' => _showGames(),
                      'players' => _reorder(game),
                      'finish' => _finish(),
                      'closing' => _openClosingSetup(game),
                      'cancel-closing' => _cancelClosing(),
                      'abandon' => _abandon(),
                      _ => null,
                    },
                    icon: const Icon(Icons.more_horiz_rounded),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'info',
                        child: Text('Spelinformatie'),
                      ),
                      const PopupMenuItem(
                        value: 'players',
                        child: Text('Spelers wijzigen'),
                      ),
                      const PopupMenuItem(
                        value: 'games',
                        child: Text('Spelgeschiedenis'),
                      ),
                      const PopupMenuItem(
                        value: 'finish',
                        child: Text('Spel afronden'),
                      ),
                      const PopupMenuItem(
                        value: 'history',
                        child: ListTile(
                          leading: Icon(Icons.receipt_long_outlined),
                          title: Text('Rondehistorie'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      if (game.phase == GamePhase.normal)
                        const PopupMenuItem(
                          value: 'closing',
                          child: ListTile(
                            leading: Icon(Icons.flag_outlined),
                            title: Text('Start finale'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      if (game.phase == GamePhase.closing &&
                          game.closingRoundIndex == 0)
                        const PopupMenuItem(
                          value: 'cancel-closing',
                          child: ListTile(
                            leading: Icon(Icons.close_rounded),
                            title: Text('Finale annuleren'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'abandon',
                        child: ListTile(
                          leading: Icon(
                            Icons.stop_circle_outlined,
                            color: AppColors.coral,
                          ),
                          title: Text('Pot afbreken'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              body: SafeArea(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 76, 20, 36),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PotDisplay(value: game.pot, unit: game.unit),
                      const SizedBox(height: 20),
                      GlassCard(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.style_rounded,
                              color: AppColors.gold,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Deler · ${game.playerById(game.dealerId).name}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  Text(
                                    game.lastWinnerId == null
                                        ? '${game.stakeOrder.first.name} begint'
                                        : 'Laatste winnaar: ${game.playerById(game.lastWinnerId!).name}',
                                    style: const TextStyle(
                                      color: AppColors.gold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Spelinformatie',
                              onPressed: () => _showGameInfo(game),
                              icon: const Icon(Icons.info_outline_rounded),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (game.phase == GamePhase.normal)
                        _NormalRound(
                          game: game,
                          controller: widget.controller,
                          onStake: _openStakeFlow,
                          onProcess: _processNormal,
                          onClosing: _finish,
                          onTopUp: _topUp,
                          onToepTrek: _toepTrek,
                        )
                      else
                        _PayoutRound(
                          game: game,
                          controller: widget.controller,
                          onProcess: _processPayout,
                          onFinish: _finish,
                          onChangeSchedule: () => _changeClosingSchedule(game),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (_celebration != null)
              _RoundCelebration(
                key: ValueKey(_celebration!.id),
                game: game,
                round: _celebration!,
                recordLevel: _recordLevel,
                onFinished: () {
                  if (mounted) setState(() => _celebration = null);
                },
              ),
          ],
        ),
      );
    },
  );

  bool _canUndo(GameRecord game) => !_busy && game.canUndo;

  Future<void> _showGameInfo(GameRecord game) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => GameInfoSheet(game: game),
  );

  Future<void> _openStakeFlow(String playerId) async {
    if (_busy) return;
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => StakeFlowSheet(
        controller: widget.controller,
        initialPlayerId: playerId,
      ),
    );
    if (mounted && widget.controller.activeGame!.allPassed) {
      await _processNormal();
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      _showError(
        error is GameRuleException
            ? error.message
            : 'Opslaan mislukt. Probeer opnieuw.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _celebrate(GameRecord before, int recordBefore) {
    final game = widget.controller.activeGame!;
    final round = game.rounds.last;
    final level = game.pot > recordBefore
        ? 2
        : game.pot > before.highestPot
        ? 1
        : 0;
    HapticFeedback.mediumImpact();
    if (mounted) {
      setState(() {
        _recordLevel = level;
        _celebration = round;
      });
    }
  }

  Future<void> _processNormal() => _run(() async {
    final game = widget.controller.activeGame!;
    if (game.draftStakes.length != game.players.length) return;
    final winner = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _RoundReviewSheet(game: game),
    );
    if (winner == null || !mounted) return;
    final record = widget.controller.recordFor(game.unit);
    if (game.allPassed) {
      await widget.controller.processAllPass(winner);
    } else {
      await widget.controller.setWinner(winner);
      await widget.controller.processNormalRound();
    }
    _celebrate(game, record);
  });

  Future<void> _processPayout() => _run(() async {
    final game = widget.controller.activeGame!;
    final projection = widget.controller.payoutProjection;
    if (projection == null) return;
    if (!await confirmAction(
      context,
      'Finaleronde afronden?',
      '${game.playerById(projection.winnerPlayerId).name} ontvangt ${game.unit.format(projection.payout!)}.',
    )) {
      return;
    }
    final record = widget.controller.recordFor(game.unit);
    await widget.controller.processPayoutRound();
    _celebrate(game, record);
  });

  Future<void> _undo() => _run(() async {
    if (!await confirmAction(
      context,
      'Laatste actie ongedaan maken?',
      'De vorige stand wordt hersteld. Je kunt daarna opnieuw de laatste actie terugdraaien.',
      action: 'Ongedaan maken',
    )) {
      return;
    }
    await widget.controller.undo();
    if (mounted) setState(() => _celebration = null);
    HapticFeedback.selectionClick();
  });

  Future<void> _topUp(int amount) => _run(() async {
    final game = widget.controller.activeGame!;
    if (!await confirmAction(
      context,
      'Pot bijspekken?',
      '${game.players.length} spelers × ${game.unit.format(amount)} = ${game.unit.format(amount * game.players.length)} toevoegen aan de pot?',
    )) {
      return;
    }
    final record = widget.controller.recordFor(game.unit);
    await widget.controller.topUp(amount);
    _celebrate(game, record);
  });

  Future<void> _toepTrek() => _run(() async {
    final game = widget.controller.activeGame!;
    final amount = math.min(game.toepTrekAmount, game.pot);
    final player = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SectionHeading(title: 'Wie heeft Toep-trek?'),
                const SizedBox(height: 12),
                Text('Uitbetaling: ${game.unit.format(amount)}'),
                for (final p in game.players)
                  ListTile(
                    title: Text(p.name),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.pop(context, p.id),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (player == null || !mounted) return;
    if (!await confirmAction(
      context,
      'Toep-trek uitbetalen?',
      '${game.playerById(player).name} ontvangt ${game.unit.format(amount)}. Er blijft ${game.unit.format(game.pot - amount)} over.',
    )) {
      return;
    }
    final record = widget.controller.recordFor(game.unit);
    await widget.controller.processToepTrek(player);
    _celebrate(game, record);
  });

  Future<void> _reorder(GameRecord game) async {
    if (game.draftStakes.isNotEmpty) {
      _showError('Rond eerst de huidige inzetten af.');
      return;
    }
    final ids = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PlayerOrderSheet(game: game),
    );
    if (ids != null) await _run(() => widget.controller.reorderPlayers(ids));
  }

  Future<void> _showGames() async {
    final game = await showModalBottomSheet<GameRecord>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => GameHistorySheet(
        controller: widget.controller,
        onCleared: () {
          if (mounted) Navigator.pop(context);
        },
      ),
    );
    if (game != null && mounted) {
      await Navigator.push(
        context,
        potRoute(ResultsScreen(controller: widget.controller, game: game)),
      );
    }
  }

  Future<void> _finish() => _run(() async {
    final game = widget.controller.activeGame!;
    if (game.draftStakes.isNotEmpty) {
      _showError('Rond eerst de huidige inzetten af.');
      return;
    }
    if (!await confirmAction(
      context,
      'Spel afronden?',
      game.pot == 0
          ? 'De eindstand en grafiek worden opgeslagen in de spelgeschiedenis.'
          : 'Er zit nog ${game.unit.format(game.pot)} in de pot. Afronden bewaart deze resterende pot; kies Start finale in het menu om hem eerst uit te spelen.',
      action: 'Spel afronden',
    )) {
      return;
    }
    final result = await widget.controller.completeGame();
    if (mounted) {
      await Navigator.pushReplacement(
        context,
        potRoute(ResultsScreen(controller: widget.controller, game: result)),
      );
    }
  });

  Future<void> _openClosingSetup(GameRecord game) async {
    if (game.draftStakes.isNotEmpty) {
      _showError('Rond eerst de huidige inzetten af.');
      return;
    }
    if (game.pot == 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Pot is leeg'),
          content: const Text('Wil je het spel nu afronden?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Nog niet'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Afronden'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        final result = await widget.controller.completeEmptyPot();
        if (mounted) {
          await Navigator.of(context).pushReplacement(
            potRoute(
              ResultsScreen(controller: widget.controller, game: result),
            ),
          );
        }
      }
      return;
    }
    final count = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _ClosingSetupSheet(
        pot: game.pot,
        unit: game.unit,
        engine: widget.controller.engine,
        initialCount: math.min(4, game.pot),
      ),
    );
    if (count != null) {
      await widget.controller.startClosing(count);
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> _changeClosingSchedule(GameRecord game) async {
    await widget.controller.cancelClosing();
    if (mounted) await _openClosingSetup(widget.controller.activeGame!);
  }

  Future<void> _cancelClosing() async {
    await widget.controller.cancelClosing();
    HapticFeedback.selectionClick();
  }

  Future<void> _showHistory() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) =>
        _RoundHistorySheet(controller: widget.controller, onUndo: _undo),
  );

  Future<void> _abandon() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pot afbreken?'),
        content: const Text(
          'De huidige stand blijft bewaard in de geschiedenis.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Doorgaan'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.coral),
            child: const Text('Pot afbreken'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.controller.abandon();
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _NormalRound extends StatelessWidget {
  const _NormalRound({
    required this.game,
    required this.controller,
    required this.onStake,
    required this.onProcess,
    required this.onClosing,
    required this.onTopUp,
    required this.onToepTrek,
  });
  final GameRecord game;
  final AppController controller;
  final ValueChanged<String> onStake;
  final VoidCallback onProcess, onClosing, onToepTrek;
  final ValueChanged<int> onTopUp;
  @override
  Widget build(BuildContext context) {
    final order = game.stakeOrder;
    final next = order.firstWhere(
      (p) => !game.draftStakes.containsKey(p.id),
      orElse: () => order.first,
    );
    final ready = game.draftStakes.length == game.players.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: SectionHeading(title: 'Aan tafel')),
            StatusPill(
              label:
                  '${game.draftStakes.length}/${game.players.length} INGEZET',
              icon: Icons.check_rounded,
            ),
          ],
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < order.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _RoundPlayerRow(
              game: game,
              player: order[i],
              isNext: !ready && next.id == order[i].id,
              onTap: () => onStake(
                game.draftStakes.containsKey(order[i].id)
                    ? order[i].id
                    : next.id,
              ),
            ),
          ),
        const SizedBox(height: 6),
        FilledButton.icon(
          onPressed: () => onStake(next.id),
          icon: const Icon(Icons.payments_outlined),
          label: Text(ready ? 'Inzetten wijzigen' : 'Inzetten'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: ready ? onProcess : null,
          icon: const Icon(Icons.emoji_events_outlined),
          label: const Text('Ronde afronden'),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: game.draftStakes.isEmpty && game.pot > 0
              ? onToepTrek
              : null,
          icon: const Icon(Icons.style_rounded),
          label: const Text('Toep-trek'),
        ),
        const SizedBox(height: 20),
        const SectionHeading(title: 'Pot bijspekken'),
        const SizedBox(height: 6),
        const Text('Iedereen legt hetzelfde bedrag bij.'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final n in [1, 2, 3, 5])
              ActionChip(
                label: Text(game.unit.format(n)),
                avatar: const Icon(Icons.add_rounded, size: 16),
                onPressed: game.draftStakes.isEmpty ? () => onTopUp(n) : null,
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: onClosing,
          icon: const Icon(Icons.flag_outlined),
          label: const Text('Spel afronden'),
        ),
      ],
    );
  }
}

class _RoundPlayerRow extends StatelessWidget {
  const _RoundPlayerRow({
    required this.game,
    required this.player,
    required this.isNext,
    required this.onTap,
  });
  final GameRecord game;
  final PlayerScore player;
  final bool isNext;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stake = game.draftStakes[player.id];
    final name = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(player.name, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          isNext
              ? 'Aan de beurt'
              : player.id == game.dealerId
              ? 'Deler'
              : stake == 0
              ? 'Speelt mee'
              : 'Speler',
          style: const TextStyle(color: AppColors.mutedCream, fontSize: 12),
        ),
      ],
    );
    final total = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Text(
          'Totaal',
          style: TextStyle(color: AppColors.mutedCream, fontSize: 11),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: ScoreText(score: player.score, unit: game.unit),
        ),
      ],
    );
    final entry = Semantics(
      label:
          '${player.name}, inzet deze ronde: ${stake == null ? 'nog niet ingevuld' : game.unit.format(stake)}',
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.gold.withValues(alpha: stake == null ? .04 : .14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.gold.withValues(alpha: stake == null ? .2 : .6),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(
              'Inzet',
              style: TextStyle(color: AppColors.gold, fontSize: 11),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                stake == null ? '—' : game.unit.format(stake),
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return GlassCard(
      onTap: onTap,
      borderColor: isNext ? AppColors.gold : null,
      padding: const EdgeInsets.all(14),
      child: MediaQuery.textScalerOf(context).scale(16) > 22
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                name,
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: total),
                    const SizedBox(width: 16),
                    Expanded(child: entry),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Expanded(flex: 3, child: name),
                const SizedBox(width: 8),
                Expanded(flex: 2, child: total),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: entry),
              ],
            ),
    );
  }
}

class _RoundReviewSheet extends StatefulWidget {
  const _RoundReviewSheet({required this.game});
  final GameRecord game;
  @override
  State<_RoundReviewSheet> createState() => _RoundReviewSheetState();
}

class _RoundReviewSheetState extends State<_RoundReviewSheet> {
  String? _winner;
  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final projection = _winner == null || game.allPassed
        ? null
        : GameEngine().previewNormalRound(
            game.copyWith(draftWinnerPlayerId: _winner),
          );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeading(
              title: game.allPassed
                  ? 'Iedereen heeft gepast'
                  : 'Ronde afronden',
            ),
            const SizedBox(height: 8),
            Text(
              game.allPassed
                  ? 'Teruguittoepen · wie had de hoogste hand? Deze speler betaalt ${game.unit.format(game.allPassAmount)} aan de pot.'
                  : 'Controleer de inzetten en kies de winnaar.',
            ),
            const SizedBox(height: 14),
            RadioGroup<String>(
              groupValue: _winner,
              onChanged: (value) => setState(() => _winner = value),
              child: Column(
                children: [
                  for (final p in game.stakeOrder)
                    RadioListTile<String>(
                      value: p.id,
                      enabled: true,
                      title: Text(p.name),
                      subtitle: Text(
                        game.draftStakes[p.id] == 0
                            ? 'Inzet ${game.unit.format(0)} · speelt mee'
                            : 'Inzet ${game.unit.format(game.draftStakes[p.id]!)}',
                      ),
                    ),
                ],
              ),
            ),
            if (projection != null)
              _ProjectionCard(game: game, projection: projection),
            if (_winner != null && game.allPassed)
              GlassCard(
                child: Text(
                  '${game.playerById(_winner!).name} betaalt ${game.unit.format(game.allPassAmount)}. Pot: ${game.unit.format(game.pot)} → ${game.unit.format(game.pot + game.allPassAmount)}',
                ),
              ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _winner == null
                  ? null
                  : () => Navigator.pop(context, _winner),
              icon: const Icon(Icons.check_rounded),
              label: const Text('Uitkomst bevestigen'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectionCard extends StatelessWidget {
  const _ProjectionCard({required this.game, required this.projection});

  final GameRecord game;
  final RoundProjection projection;

  @override
  Widget build(BuildContext context) => GlassCard(
    color: AppColors.mint.withValues(alpha: .08),
    borderColor: AppColors.mint.withValues(alpha: .42),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.visibility_outlined, color: AppColors.mint),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                'Voorvertoning',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  '${game.unit.format(projection.potBefore)} → ${game.unit.format(projection.potAfter)}',
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final player in game.players)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Expanded(child: Text(player.name)),
                Text(
                  '${game.unit.format(player.score, showPlus: true)} → ${game.unit.format(projection.players.firstWhere((item) => item.id == player.id).score, showPlus: true)}',
                  style: TextStyle(
                    color: player.id == projection.winnerPlayerId
                        ? AppColors.mint
                        : AppColors.mutedCream,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class _PayoutRound extends StatelessWidget {
  const _PayoutRound({
    required this.game,
    required this.controller,
    required this.onProcess,
    required this.onChangeSchedule,
    required this.onFinish,
  });

  final GameRecord game;
  final AppController controller;
  final VoidCallback onProcess;
  final VoidCallback onChangeSchedule;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    if (game.closingRoundIndex >= game.closingPayouts.length) {
      return GlassCard(
        child: Column(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: AppColors.mint,
              size: 40,
            ),
            const SizedBox(height: 14),
            const Text(
              'De pot is uitgespeeld. Sla de eindstand op of maak de laatste actie ongedaan.',
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onFinish,
              icon: const Icon(Icons.flag_outlined),
              label: const Text('Spel afronden'),
            ),
          ],
        ),
      );
    }
    final payout = game.closingPayouts[game.closingRoundIndex];
    final projection = controller.payoutProjection;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassCard(
          color: AppColors.gold.withValues(alpha: .1),
          borderColor: AppColors.gold.withValues(alpha: .52),
          child: Column(
            children: [
              const StatusPill(
                label: 'FINALE',
                icon: Icons.flag_rounded,
                color: AppColors.gold,
              ),
              const SizedBox(height: 14),
              Text(
                'Wie wint ${game.unit.format(payout)}?',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Ronde ${game.closingRoundIndex + 1} van ${game.closingPayouts.length} · geen inzetten meer',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                alignment: WrapAlignment.center,
                children: [
                  for (
                    var index = 0;
                    index < game.closingPayouts.length;
                    index++
                  )
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 240),
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: index < game.closingRoundIndex
                            ? AppColors.mint.withValues(alpha: .16)
                            : index == game.closingRoundIndex
                            ? AppColors.gold
                            : AppColors.raised,
                        shape: BoxShape.circle,
                      ),
                      child: index < game.closingRoundIndex
                          ? const Icon(
                              Icons.check_rounded,
                              size: 19,
                              color: AppColors.mint,
                            )
                          : Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: index == game.closingRoundIndex
                                    ? AppColors.black
                                    : AppColors.mutedCream,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                ],
              ),
              if (game.closingRoundIndex == 0) ...[
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: onChangeSchedule,
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Verdeling aanpassen'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 22),
        const SectionHeading(title: 'Kies de winnaar'),
        const SizedBox(height: 13),
        for (var index = 0; index < game.players.length; index++) ...[
          StaggeredEntrance(
            index: index,
            child: _PayoutPlayerCard(
              player: game.players[index],
              unit: game.unit,
              payout: payout,
              isWinner: game.draftWinnerPlayerId == game.players[index].id,
              onTap: () async {
                HapticFeedback.selectionClick();
                await controller.setWinner(game.players[index].id);
              },
            ),
          ),
          const SizedBox(height: 11),
        ],
        if (projection != null) ...[
          const SizedBox(height: 4),
          GlassCard(
            color: AppColors.mint.withValues(alpha: .08),
            borderColor: AppColors.mint.withValues(alpha: .42),
            child: Row(
              children: [
                const Icon(Icons.payments_outlined, color: AppColors.mint),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${game.playerById(projection.winnerPlayerId).name} gaat van ${game.unit.format(game.playerById(projection.winnerPlayerId).score, showPlus: true)} naar ${game.unit.format(projection.players.firstWhere((player) => player.id == projection.winnerPlayerId).score, showPlus: true)}.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        FilledButton.icon(
          onPressed: projection == null ? null : onProcess,
          icon: const Icon(Icons.emoji_events_rounded),
          label: Text(
            game.closingRoundIndex == game.closingPayouts.length - 1
                ? 'Laatste finaleronde verwerken'
                : 'Finaleronde verwerken',
          ),
        ),
      ],
    );
  }
}

class _PayoutPlayerCard extends StatelessWidget {
  const _PayoutPlayerCard({
    required this.player,
    required this.unit,
    required this.payout,
    required this.isWinner,
    required this.onTap,
  });

  final PlayerScore player;
  final ScoreUnit unit;
  final int payout;
  final bool isWinner;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GlassCard(
    onTap: onTap,
    color: isWinner
        ? AppColors.gold.withValues(alpha: .13)
        : AppColors.deepGreen.withValues(alpha: .92),
    borderColor: isWinner
        ? AppColors.gold.withValues(alpha: .88)
        : const Color(0xFF315548),
    child: Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: isWinner ? AppColors.gold : AppColors.raised,
            borderRadius: BorderRadius.circular(17),
          ),
          child: Icon(
            isWinner ? Icons.emoji_events_rounded : Icons.emoji_events_outlined,
            color: isWinner ? AppColors.black : AppColors.mutedCream,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(player.name, style: Theme.of(context).textTheme.titleMedium),
              ScoreText(score: player.score, unit: unit),
            ],
          ),
        ),
        AnimatedOpacity(
          opacity: isWinner ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: Text(
            '+${unit.format(payout)}',
            style: const TextStyle(
              color: AppColors.mint,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

class StakeFlowSheet extends StatefulWidget {
  const StakeFlowSheet({
    super.key,
    required this.controller,
    required this.initialPlayerId,
  });

  final AppController controller;
  final String initialPlayerId;

  @override
  State<StakeFlowSheet> createState() => _StakeFlowSheetState();
}

class _StakeFlowSheetState extends State<StakeFlowSheet> {
  late String _playerId;
  late TextEditingController _amountController;
  int _amount = 0;
  String? _error;
  bool _saving = false;

  GameRecord get _game => widget.controller.activeGame!;
  PlayerScore get _player => _game.playerById(_playerId);

  @override
  void initState() {
    super.initState();
    _playerId = widget.initialPlayerId;
    _amount = _game.draftStakes[_playerId] ?? 0;
    _amountController = TextEditingController(text: '$_amount');
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quickAmounts = [0, 1, 2, 3, 4, 5, 10, 15, 20, 25];
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(
              value: _game.draftStakes.length / _game.players.length,
              color: AppColors.gold,
              backgroundColor: AppColors.raised,
            ),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 420),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween(
                    begin: child.key == ValueKey(_playerId)
                        ? const Offset(1, 0)
                        : const Offset(-1, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: Column(
                key: ValueKey(_playerId),
                children: [
                  Text(
                    'INZET VOOR',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.gold,
                      letterSpacing: 2,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _player.name,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Text('Maximaal ${_game.unit.format(_game.pot)}'),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final amount in quickAmounts)
                  FilledButton.tonal(
                    onPressed: _saving || amount > _game.pot
                        ? null
                        : () => _saveAndAdvance(amount),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(58, 52),
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                    ),
                    child: Text(
                      amount == 0 ? 'Pas' : _game.unit.format(amount),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : () => _saveAndAdvance(_game.pot),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.black,
              ),
              icon: const Icon(Icons.local_fire_department_rounded),
              label: Text('HELE POT · ${_game.unit.format(_game.pot)}'),
            ),
            const SizedBox(height: 17),
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: _amount > 0 ? () => _setAmount(_amount - 1) : null,
                  icon: const Icon(Icons.remove_rounded),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: InputDecoration(
                      errorText: _error,
                      prefixText: _game.unit == ScoreUnit.points
                          ? null
                          : _game.unit.symbol,
                      suffixText: _game.unit == ScoreUnit.points ? ' pt' : null,
                    ),
                    onChanged: (value) {
                      _amount = int.tryParse(value) ?? 0;
                      if (_error != null) setState(() => _error = null);
                    },
                    onSubmitted: (_) => _confirmCustom(),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  onPressed: _amount < _game.pot
                      ? () => _setAmount(_amount + 1)
                      : null,
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _saving ? null : _confirmCustom,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(
                _remainingUnentered == 0
                    ? 'Inzet opslaan'
                    : 'Opslaan & volgende',
              ),
            ),
          ],
        ),
      ),
    );
  }

  int get _remainingUnentered => _game.players
      .where(
        (player) =>
            player.id != _playerId && !_game.draftStakes.containsKey(player.id),
      )
      .length;

  void _setAmount(int amount) {
    HapticFeedback.selectionClick();
    setState(() {
      _amount = amount;
      _amountController.text = '$amount';
      _error = null;
    });
  }

  void _confirmCustom() {
    final amount = int.tryParse(_amountController.text);
    if (amount == null || amount < 0 || amount > _game.pot) {
      setState(() => _error = 'Kies 0 t/m ${_game.pot}');
      return;
    }
    _saveAndAdvance(amount);
  }

  Future<void> _saveAndAdvance(int amount) async {
    if (_saving) return;
    setState(() => _saving = true);
    if (_saving && !mounted) return;
    try {
      await widget.controller.setStake(_playerId, amount);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Opslaan mislukt. Probeer opnieuw.';
        });
      }
      return;
    }
    HapticFeedback.selectionClick();
    if (!mounted) return;
    final next = _game.stakeOrder.cast<PlayerScore?>().firstWhere(
      (player) =>
          player!.id != _playerId && !_game.draftStakes.containsKey(player.id),
      orElse: () => null,
    );
    if (next == null) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _playerId = next.id;
      _amount = _game.draftStakes[_playerId] ?? 0;
      _amountController.text = '$_amount';
      _error = null;
      _saving = false;
    });
  }
}

class _ClosingSetupSheet extends StatefulWidget {
  const _ClosingSetupSheet({
    required this.pot,
    required this.unit,
    required this.engine,
    required this.initialCount,
  });

  final int pot;
  final ScoreUnit unit;
  final GameEngine engine;
  final int initialCount;

  @override
  State<_ClosingSetupSheet> createState() => _ClosingSetupSheetState();
}

class _ClosingSetupSheetState extends State<_ClosingSetupSheet> {
  late int _count = widget.initialCount;

  @override
  Widget build(BuildContext context) {
    final schedule = widget.engine.payoutSchedule(widget.pot, _count);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.flag_rounded, color: AppColors.gold, size: 38),
            const SizedBox(height: 12),
            Text(
              'Tijd voor de finale',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 7),
            Text(
              'Verdeel de resterende ${widget.unit.format(widget.pot)} over de laatste rondes.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filledTonal(
                  onPressed: _count > 1 ? () => setState(() => _count--) : null,
                  icon: const Icon(Icons.remove_rounded),
                ),
                SizedBox(
                  width: 118,
                  child: Column(
                    children: [
                      Text(
                        '$_count',
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(color: AppColors.gold),
                      ),
                      Text(_count == 1 ? 'finaleronde' : 'finalerondes'),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: _count < widget.pot
                      ? () => setState(() => _count++)
                      : null,
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            const SizedBox(height: 22),
            GlassCard(
              color: AppColors.gold.withValues(alpha: .08),
              borderColor: AppColors.gold.withValues(alpha: .42),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Verdeling',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var index = 0; index < schedule.length; index++)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.raised,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Text(
                            '${index + 1} · ${widget.unit.format(schedule[index])}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, _count),
              icon: const Icon(Icons.flag_rounded),
              label: const Text('Start de finale'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundHistorySheet extends StatelessWidget {
  const _RoundHistorySheet({required this.controller, required this.onUndo});

  final AppController controller;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final game = controller.activeGame!;
    final rounds = game.rounds.reversed.toList();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .74,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Rondehistorie',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton.icon(
                  onPressed: rounds.isEmpty
                      ? null
                      : () {
                          Navigator.pop(context);
                          onUndo();
                        },
                  icon: const Icon(Icons.undo_rounded),
                  label: const Text('Undo'),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: rounds.isEmpty
                ? const Center(child: Text('Nog geen gespeelde rondes.'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                    itemCount: rounds.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final round = rounds[index];
                      final winner = game.playerById(round.winnerPlayerId);
                      final originalIndex = game.rounds.indexOf(round) + 1;
                      return GlassCard(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: round.kind == RoundKind.payout
                                  ? AppColors.gold.withValues(alpha: .16)
                                  : AppColors.mint.withValues(alpha: .12),
                              foregroundColor: round.kind == RoundKind.payout
                                  ? AppColors.gold
                                  : AppColors.mint,
                              child: Icon(
                                round.kind == RoundKind.payout
                                    ? Icons.flag_rounded
                                    : Icons.emoji_events_outlined,
                              ),
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${round.kind.label} $originalIndex · ${round.kind == RoundKind.topUp ? 'Iedereen' : winner.name}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  Text(
                                    round.kind == RoundKind.payout
                                        ? '${game.unit.format(round.payout!)} uitgekeerd'
                                        : round.stakes.entries
                                              .map(
                                                (entry) =>
                                                    '${game.playerById(entry.key).name} ${entry.value}',
                                              )
                                              .join(' · '),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${game.unit.format(round.potBefore)} → ${game.unit.format(round.potAfter)}',
                              style: const TextStyle(
                                color: AppColors.gold,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _RoundCelebration extends StatefulWidget {
  const _RoundCelebration({
    super.key,
    required this.game,
    required this.round,
    required this.recordLevel,
    required this.onFinished,
  });

  final GameRecord game;
  final RoundRecord round;
  final int recordLevel;
  final VoidCallback onFinished;

  @override
  State<_RoundCelebration> createState() => _RoundCelebrationState();
}

class _RoundCelebrationState extends State<_RoundCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
            vsync: this,
            duration: Duration(
              milliseconds: widget.recordLevel == 2 ? 2600 : 1300,
            ),
          )
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) widget.onFinished();
          })
          ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final winner = widget.game.playerById(widget.round.winnerPlayerId);
    final amount =
        widget.round.payout ??
        widget.round.stakes[widget.round.winnerPlayerId] ??
        0;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final headline = widget.recordLevel == 2
        ? 'Nieuw all-time potrecord!'
        : widget.recordLevel == 1
        ? 'Nieuw potrecord dit spel!'
        : widget.round.kind == RoundKind.topUp
        ? 'Samen de pot gespekt'
        : widget.round.kind == RoundKind.allPass
        ? 'Teruguitgetoept'
        : winner.name;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final entrance = reduced
              ? 1.0
              : Curves.elasticOut.transform(
                  (_controller.value / .55).clamp(0.0, 1.0),
                );
          final fade = _controller.value < .72
              ? 1.0
              : 1 - ((_controller.value - .72) / .28);
          return Opacity(
            opacity: fade.clamp(0.0, 1.0),
            child: ColoredBox(
              color: AppColors.black.withValues(alpha: .42),
              child: Stack(
                fit: StackFit.expand,
                alignment: Alignment.center,
                children: [
                  if (!reduced)
                    CustomPaint(
                      painter: _BurstPainter(
                        progress: _controller.value,
                        level: widget.recordLevel,
                      ),
                    ),
                  Center(
                    child: Transform.scale(
                      scale: entrance,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Material(
                          type: MaterialType.transparency,
                          child: GlassCard(
                            color: AppColors.gold,
                            borderColor: AppColors.goldSoft,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.emoji_events_rounded,
                                  size: 46,
                                  color: AppColors.black,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  headline,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(color: AppColors.black),
                                ),
                                Text(
                                  widget.recordLevel > 0
                                      ? widget.game.unit.format(widget.game.pot)
                                      : widget.round.kind == RoundKind.topUp
                                      ? '+${widget.game.unit.format(widget.round.potAfter - widget.round.potBefore)} in de pot'
                                      : widget.round.kind == RoundKind.allPass
                                      ? '${winner.name} betaalt ${widget.game.unit.format(amount)}'
                                      : '+${widget.game.unit.format(amount)}',
                                  style: const TextStyle(
                                    color: AppColors.black,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter({required this.progress, required this.level});
  final int level;

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final travel = Curves.easeOutCubic.transform(progress.clamp(0, 1));
    const colors = [
      AppColors.gold,
      AppColors.mint,
      AppColors.coral,
      AppColors.cream,
    ];
    final count = level == 2
        ? 150
        : level == 1
        ? 48
        : 24;
    for (var index = 0; index < count; index++) {
      final angle = index * (math.pi * 2 / count) + (index % 3) * .12;
      final distance = (60 + (index % 9) * (level == 2 ? 44 : 20)) * travel;
      final position =
          (level == 2
              ? Offset(
                  size.width * (.2 + (index % 3) * .3),
                  size.height * (.2 + (index % 4) * .17),
                )
              : center) +
          Offset(math.cos(angle), math.sin(angle)) * distance;
      final paint = Paint()
        ..color = colors[index % colors.length].withValues(
          alpha: (1 - progress).clamp(0, 1),
        );
      canvas.save();
      canvas.translate(position.dx, position.dy);
      canvas.rotate(angle + progress * 4);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: 5 + index % 3 * 2,
            height: 11,
          ),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
