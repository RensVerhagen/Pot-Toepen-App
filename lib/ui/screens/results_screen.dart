import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../application/app_controller.dart';
import '../../domain/models.dart';
import '../app_theme.dart';
import '../widgets/app_widgets.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({
    super.key,
    required this.controller,
    required this.game,
  });

  final AppController controller;
  final GameRecord game;

  @override
  Widget build(BuildContext context) {
    final ranking = [...game.players]
      ..sort((a, b) {
        final score = b.score.compareTo(a.score);
        return score == 0 ? a.name.compareTo(b.name) : score;
      });
    final completed = game.status == GameStatus.completed;
    return FeltScaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(completed ? 'Eindstand' : 'Afgebroken pot'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 86, 20, 34),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StaggeredEntrance(
                index: 0,
                child: _ResultsHero(
                  completed: completed,
                  winnerName: ranking.first.name,
                  rounds: game.rounds.length,
                ),
              ),
              const SizedBox(height: 26),
              SectionHeading(
                title: completed ? 'Definitieve scores' : 'Laatste stand',
                trailing: StatusPill(
                  label: completed ? 'AFGEROND' : 'AFGEBROKEN',
                  icon: completed ? Icons.check_rounded : Icons.stop_rounded,
                  color: completed ? AppColors.mint : AppColors.coral,
                ),
              ),
              const SizedBox(height: 13),
              GlassCard(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Column(
                  children: [
                    for (var index = 0; index < ranking.length; index++) ...[
                      _RankingRow(
                        index: index,
                        player: ranking[index],
                        unit: game.unit,
                      ),
                      if (index < ranking.length - 1)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Divider(),
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              GlassCard(
                padding: const EdgeInsets.all(15),
                child: Row(
                  children: [
                    const Icon(
                      Icons.lock_outline_rounded,
                      color: AppColors.mutedCream,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${game.players.length} spelers · ${game.normalRoundCount} speelrondes · ${game.payoutRoundCount} finalerondes',
                      ),
                    ),
                  ],
                ),
              ),
              if (completed) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => _share(context, ranking),
                  icon: const Icon(Icons.share_rounded),
                  label: const Text('Deel scores via WhatsApp'),
                ),
              ],
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.home_outlined),
                label: const Text('Terug naar overzicht'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _share(BuildContext context, List<PlayerScore> ranking) async {
    HapticFeedback.selectionClick();
    final lines = [
      'Pot Toepen — eindstand',
      '',
      for (final player in ranking)
        '${player.name}: ${game.unit.format(player.score, showPlus: true)}',
    ];
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        text: lines.join('\n'),
        subject: 'Pot Toepen — eindstand',
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }
}

class _ResultsHero extends StatelessWidget {
  const _ResultsHero({
    required this.completed,
    required this.winnerName,
    required this.rounds,
  });

  final bool completed;
  final String winnerName;
  final int rounds;

  @override
  Widget build(BuildContext context) => GlassCard(
    color: (completed ? AppColors.gold : AppColors.coral).withValues(
      alpha: .11,
    ),
    borderColor: (completed ? AppColors.gold : AppColors.coral).withValues(
      alpha: .55,
    ),
    padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
    child: Column(
      children: [
        Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            color: completed ? AppColors.gold : AppColors.coral,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: (completed ? AppColors.gold : AppColors.coral)
                    .withValues(alpha: .26),
                blurRadius: 30,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Icon(
            completed ? Icons.emoji_events_rounded : Icons.stop_circle_outlined,
            size: 42,
            color: AppColors.black,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          completed ? 'Pot uitgespeeld' : 'Pot afgebroken',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: completed ? AppColors.gold : AppColors.coral,
            letterSpacing: 1.6,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          completed ? winnerName : 'Stand opgeslagen',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: 7),
        Text(
          completed ? 'Bovenaan na $rounds rondes' : '$rounds rondes gespeeld',
        ),
      ],
    ),
  );
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({
    required this.index,
    required this.player,
    required this.unit,
  });

  final int index;
  final PlayerScore player;
  final ScoreUnit unit;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: index == 0
                ? AppColors.gold.withValues(alpha: .18)
                : AppColors.raised,
            borderRadius: BorderRadius.circular(13),
          ),
          child: index == 0
              ? const Icon(
                  Icons.emoji_events_rounded,
                  size: 20,
                  color: AppColors.gold,
                )
              : Text(
                  '${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Text(
            player.name,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        ScoreText(score: player.score, unit: unit, large: true),
      ],
    ),
  );
}
