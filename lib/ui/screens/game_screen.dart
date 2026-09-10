import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../application/app_controller.dart';
import '../../domain/game_engine.dart';
import '../../domain/models.dart';
import '../app_theme.dart';
import '../widgets/app_widgets.dart';
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

  @override
  void initState() {
    super.initState();
    _lastGame = widget.controller.activeGame!;
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
                      'history' => _showHistory(),
                      'closing' => _openClosingSetup(game),
                      'cancel-closing' => _cancelClosing(),
                      'abandon' => _abandon(),
                      _ => null,
                    },
                    itemBuilder: (context) => [
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
                      if (game.phase == GamePhase.normal)
                        _NormalRound(
                          game: game,
                          controller: widget.controller,
                          onStake: _openStakeFlow,
                          onProcess: _processNormal,
                          onClosing: () => _openClosingSetup(game),
                        )
                      else
                        _PayoutRound(
                          game: game,
                          controller: widget.controller,
                          onProcess: _processPayout,
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
                onFinished: () {
                  if (mounted) setState(() => _celebration = null);
                },
              ),
          ],
        ),
      );
    },
  );

  bool _canUndo(GameRecord game) =>
      game.rounds.isNotEmpty &&
      !(game.phase == GamePhase.closing &&
          game.closingRoundIndex == 0 &&
          game.rounds.last.kind == RoundKind.normal);

  Future<void> _openStakeFlow(String playerId) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => StakeFlowSheet(
      controller: widget.controller,
      initialPlayerId: playerId,
    ),
  );

  Future<void> _processNormal() async {
    try {
      HapticFeedback.mediumImpact();
      final round = await widget.controller.processNormalRound();
      if (!mounted) return;
      setState(() => _celebration = round);
      _showUndoSnackBar(round);
    } on GameRuleException catch (error) {
      _showError(error.message);
    }
  }

  Future<void> _processPayout() async {
    try {
      HapticFeedback.heavyImpact();
      final result = await widget.controller.processPayoutRound();
      if (!mounted) return;
      if (result.status == GameStatus.completed) {
        await Navigator.of(context).pushReplacement(
          potRoute(ResultsScreen(controller: widget.controller, game: result)),
        );
      } else {
        setState(() => _celebration = result.rounds.last);
        _showUndoSnackBar(result.rounds.last);
      }
    } on GameRuleException catch (error) {
      _showError(error.message);
    }
  }

  void _showUndoSnackBar(RoundRecord round) {
    final winner = _lastGame.playerById(round.winnerPlayerId);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${winner.name} won deze ronde'),
          action: SnackBarAction(label: 'UNDO', onPressed: _undo),
        ),
      );
  }

  Future<void> _undo() async {
    try {
      await widget.controller.undo();
      HapticFeedback.selectionClick();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Laatste ronde ongedaan gemaakt')),
        );
      }
    } on GameRuleException catch (error) {
      _showError(error.message);
    }
  }

  Future<void> _openClosingSetup(GameRecord game) async {
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
  });

  final GameRecord game;
  final AppController controller;
  final ValueChanged<String> onStake;
  final VoidCallback onProcess;
  final VoidCallback onClosing;

  @override
  Widget build(BuildContext context) {
    final projection = controller.normalProjection;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: SectionHeading(title: 'Inzet & winnaar')),
            StatusPill(
              label:
                  '${game.draftStakes.length}/${game.players.length} INGEVULD',
              icon: Icons.edit_rounded,
              color: game.draftStakes.length == game.players.length
                  ? AppColors.mint
                  : AppColors.gold,
            ),
          ],
        ),
        const SizedBox(height: 14),
        for (var index = 0; index < game.players.length; index++) ...[
          StaggeredEntrance(
            index: index,
            child: _PlayerRoundCard(
              game: game,
              player: game.players[index],
              isWinner: game.draftWinnerPlayerId == game.players[index].id,
              stake: game.draftStakes[game.players[index].id],
              onStake: () => onStake(game.players[index].id),
              onPot: () async {
                HapticFeedback.selectionClick();
                await controller.setStake(game.players[index].id, game.pot);
              },
              onWinner: () async {
                HapticFeedback.selectionClick();
                await controller.setWinner(game.players[index].id);
              },
            ),
          ),
          const SizedBox(height: 11),
        ],
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: projection == null
              ? GlassCard(
                  key: const ValueKey('hint'),
                  padding: const EdgeInsets.all(15),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.touch_app_outlined,
                        color: AppColors.gold,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          game.draftStakes.length < game.players.length
                              ? 'Vul voor iedereen een inzet in — ook als die 0 is.'
                              : 'Alle inzetten staan klaar. Kies nu de winnaar.',
                        ),
                      ),
                    ],
                  ),
                )
              : _ProjectionCard(
                  key: const ValueKey('preview'),
                  game: game,
                  projection: projection,
                ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: projection == null ? null : onProcess,
          icon: const Icon(Icons.check_rounded),
          label: const Text('Ronde verwerken'),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: onClosing,
          icon: const Icon(Icons.flag_outlined),
          label: const Text('Normaal spel stoppen — start finale'),
        ),
      ],
    );
  }
}

class _PlayerRoundCard extends StatelessWidget {
  const _PlayerRoundCard({
    required this.game,
    required this.player,
    required this.isWinner,
    required this.stake,
    required this.onStake,
    required this.onPot,
    required this.onWinner,
  });

  final GameRecord game;
  final PlayerScore player;
  final bool isWinner;
  final int? stake;
  final VoidCallback onStake;
  final VoidCallback onPot;
  final VoidCallback onWinner;

  @override
  Widget build(BuildContext context) => GlassCard(
    color: isWinner
        ? AppColors.gold.withValues(alpha: .12)
        : AppColors.deepGreen.withValues(alpha: .92),
    borderColor: isWinner
        ? AppColors.gold.withValues(alpha: .85)
        : const Color(0xFF315548),
    padding: const EdgeInsets.fromLTRB(16, 12, 11, 12),
    child: Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isWinner
                ? AppColors.gold
                : AppColors.raised.withValues(alpha: .9),
            borderRadius: BorderRadius.circular(16),
          ),
          child: IconButton(
            tooltip: '${player.name} als winnaar kiezen',
            onPressed: onWinner,
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Icon(
                isWinner
                    ? Icons.emoji_events_rounded
                    : Icons.emoji_events_outlined,
                key: ValueKey(isWinner),
                color: isWinner ? AppColors.black : AppColors.mutedCream,
              ),
            ),
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(player.name, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 2),
              ScoreText(score: player.score, unit: game.unit),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            InkWell(
              onTap: onStake,
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                constraints: const BoxConstraints(minWidth: 76),
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: stake == null
                      ? AppColors.coral.withValues(alpha: .1)
                      : AppColors.mint.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: stake == null
                        ? AppColors.coral.withValues(alpha: .5)
                        : AppColors.mint.withValues(alpha: .42),
                  ),
                ),
                child: Text(
                  stake == null ? '—' : game.unit.format(stake!),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: stake == null ? AppColors.coral : AppColors.mint,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: onPot,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text('POT ${game.unit.format(game.pot)}'),
            ),
          ],
        ),
      ],
    ),
  );
}

class _ProjectionCard extends StatelessWidget {
  const _ProjectionCard({
    super.key,
    required this.game,
    required this.projection,
  });

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
  });

  final GameRecord game;
  final AppController controller;
  final VoidCallback onProcess;
  final VoidCallback onChangeSchedule;

  @override
  Widget build(BuildContext context) {
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
                ? 'Laatste winnaar & afronden'
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
    final quickAmounts = [
      for (var value = 0; value <= math.min(5, _game.pot); value++) value,
    ];
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
            const SizedBox(height: 4),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(.08, 0),
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
                    onPressed: _saving ? null : () => _saveAndAdvance(amount),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(58, 52),
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                    ),
                    child: Text(_game.unit.format(amount)),
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
    setState(() => _saving = true);
    await widget.controller.setStake(_playerId, amount);
    HapticFeedback.selectionClick();
    if (!mounted) return;
    final next = _game.players.cast<PlayerScore?>().firstWhere(
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
                                    round.kind == RoundKind.payout
                                        ? 'Finaleronde · ${winner.name}'
                                        : 'Ronde $originalIndex · ${winner.name}',
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
    required this.onFinished,
  });

  final GameRecord game;
  final RoundRecord round;
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
            duration: const Duration(milliseconds: 1150),
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
    final amount = widget.round.kind == RoundKind.payout
        ? widget.round.payout!
        : widget.round.stakes[widget.round.winnerPlayerId]!;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final entrance = Curves.elasticOut.transform(
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
                  CustomPaint(
                    painter: _BurstPainter(progress: _controller.value),
                  ),
                  Center(
                    child: Transform.scale(
                      scale: entrance,
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
                              winner.name,
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(color: AppColors.black),
                            ),
                            Text(
                              '+${widget.game.unit.format(amount)}',
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
  _BurstPainter({required this.progress});

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
    for (var index = 0; index < 30; index++) {
      final angle = index * (math.pi * 2 / 30) + (index % 3) * .12;
      final distance = (60 + (index % 6) * 24) * travel;
      final position =
          center + Offset(math.cos(angle), math.sin(angle)) * distance;
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
