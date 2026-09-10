import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../application/app_controller.dart';
import '../../domain/models.dart';
import '../app_theme.dart';
import '../widgets/app_widgets.dart';
import 'game_screen.dart';
import 'results_screen.dart';
import 'saved_players_screen.dart';
import 'setup_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, child) => FeltScaffold(
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
              sliver: SliverList.list(
                children: [
                  _Header(
                    onPlayers: () => Navigator.of(context).push(
                      potRoute(SavedPlayersScreen(controller: controller)),
                    ),
                  ),
                  const SizedBox(height: 38),
                  if (controller.activeGame != null) ...[
                    _ActiveGameCard(
                      game: controller.activeGame!,
                      onResume: () {
                        HapticFeedback.selectionClick();
                        Navigator.of(context)
                            .push(potRoute(GameScreen(controller: controller)));
                      },
                    ),
                    const SizedBox(height: 18),
                  ],
                  FilledButton.icon(
                    onPressed: controller.activeGame == null
                        ? () {
                            HapticFeedback.selectionClick();
                            Navigator.of(context).push(
                              potRoute(SetupScreen(controller: controller)),
                            );
                          }
                        : () => _activeGameNotice(context),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(
                      controller.activeGame == null
                          ? 'Nieuwe pot starten'
                          : 'Eerst actieve pot afronden',
                    ),
                  ),
                  const SizedBox(height: 36),
                  SectionHeading(
                    title: 'Eerdere potten',
                    trailing: controller.history.isEmpty
                        ? null
                        : TextButton(
                            onPressed: () => _clearHistory(context),
                            child: const Text('Wis alles'),
                          ),
                  ),
                  const SizedBox(height: 14),
                  if (controller.history.isEmpty)
                    const _EmptyHistory()
                  else
                    for (
                      var index = 0;
                      index < controller.history.length;
                      index++
                    ) ...[
                      StaggeredEntrance(
                        index: index,
                        child: _HistoryCard(
                          game: controller.history[index],
                          onOpen: () => Navigator.of(context).push(
                            potRoute(
                              ResultsScreen(
                                controller: controller,
                                game: controller.history[index],
                              ),
                            ),
                          ),
                          onDelete: () =>
                              _deleteGame(context, controller.history[index]),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  void _activeGameNotice(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Hervat of beëindig eerst de actieve pot.')),
    );
  }

  Future<void> _deleteGame(BuildContext context, GameRecord game) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pot verwijderen?'),
        content: const Text('Deze geschiedenis kan niet worden hersteld.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuleren'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Verwijderen'),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.deleteHistoryGame(game.id);
  }

  Future<void> _clearHistory(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alle geschiedenis wissen?'),
        content: const Text('Alle afgeronde en afgebroken potten verdwijnen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuleren'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Alles wissen'),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.clearHistory();
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onPlayers});

  final VoidCallback onPlayers;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      const BrandMark(),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'POT TOEPEN',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.gold,
                letterSpacing: 2.2,
                fontSize: 12,
              ),
            ),
            Text(
              'De pot. Zonder gedoe.',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      ),
      IconButton.filledTonal(
        tooltip: 'Opgeslagen spelers',
        onPressed: onPlayers,
        icon: const Icon(Icons.group_outlined),
      ),
    ],
  );
}

class _ActiveGameCard extends StatelessWidget {
  const _ActiveGameCard({required this.game, required this.onResume});

  final GameRecord game;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) => GlassCard(
    color: AppColors.gold.withValues(alpha: .11),
    borderColor: AppColors.gold.withValues(alpha: .55),
    onTap: onResume,
    child: Row(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: .15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.play_arrow_rounded,
            color: AppColors.gold,
            size: 34,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const StatusPill(
                label: 'ACTIEVE POT',
                icon: Icons.bolt_rounded,
                color: AppColors.gold,
              ),
              const SizedBox(height: 9),
              Text(
                '${game.players.length} spelers · ${game.normalRoundCount} rondes',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                game.phase == GamePhase.closing
                    ? 'Finale ${game.closingRoundIndex + 1} van ${game.closingPayouts.length}'
                    : '${game.unit.format(game.pot)} in de pot',
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded),
      ],
    ),
  );
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) => GlassCard(
    child: Column(
      children: [
        Icon(
          Icons.auto_stories_outlined,
          color: AppColors.mutedCream.withValues(alpha: .7),
          size: 34,
        ),
        const SizedBox(height: 12),
        Text(
          'Nog geen gespeelde potten',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        const Text('Je eindstanden verschijnen hier vanzelf.'),
      ],
    ),
  );
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.game,
    required this.onOpen,
    required this.onDelete,
  });

  final GameRecord game;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ranking = [...game.players]
      ..sort((a, b) => b.score.compareTo(a.score));
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 15, 8, 15),
      onTap: onOpen,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: game.status == GameStatus.completed
                  ? AppColors.mint.withValues(alpha: .12)
                  : AppColors.coral.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              game.status == GameStatus.completed
                  ? Icons.emoji_events_outlined
                  : Icons.flag_outlined,
              color: game.status == GameStatus.completed
                  ? AppColors.mint
                  : AppColors.coral,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  game.status == GameStatus.completed
                      ? ranking.first.name
                      : 'Afgebroken pot',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '${_date(game.createdAt)} · ${game.players.length} spelers · ${game.rounds.length} rondes',
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Verwijderen',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }
}

String _date(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
