import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../application/app_controller.dart';
import '../../domain/game_engine.dart';
import '../../domain/models.dart';
import '../app_theme.dart';
import '../widgets/app_widgets.dart';
import '../widgets/feedback_widgets.dart';
import 'game_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _nameController = TextEditingController();
  final _focusNode = FocusNode();
  final List<String> _players = [];
  ScoreUnit _unit = ScoreUnit.euro;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = widget.controller.rememberedPlayers
        .where(
          (saved) => !_players.any(
            (name) => name.toLowerCase() == saved.name.toLowerCase(),
          ),
        )
        .toList();
    return FeltScaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Nieuwe pot'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 88, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Wie doen er mee?',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Voeg 2 tot 8 spelers toe. Iedereen begint automatisch op −1.',
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(color: AppColors.mutedCream),
              ),
              const SizedBox(height: 22),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      focusNode: _focusNode,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _addTypedPlayer(),
                      decoration: const InputDecoration(
                        labelText: 'Naam speler',
                        hintText: 'Bijv. Rens',
                        prefixIcon: Icon(Icons.person_add_alt_1_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    onPressed: _players.length < 8 ? _addTypedPlayer : null,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(58, 58),
                    ),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              if (suggestions.isNotEmpty) ...[
                const SizedBox(height: 15),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final saved in suggestions.take(8))
                      ActionChip(
                        avatar: const Icon(Icons.add_rounded, size: 17),
                        label: Text(saved.name),
                        onPressed: _players.length < 8
                            ? () => _addPlayer(saved.name)
                            : null,
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              if (_players.isEmpty)
                GlassCard(
                  child: Text(
                    'Je spelerslijst is nog leeg.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                )
              else
                GlassCard(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: _players.length,
                    onReorderItem: (oldIndex, newIndex) {
                      setState(() {
                        final player = _players.removeAt(oldIndex);
                        _players.insert(newIndex, player);
                      });
                      HapticFeedback.selectionClick();
                    },
                    itemBuilder: (context, index) => ListTile(
                      key: ValueKey(_players[index]),
                      leading: CircleAvatar(
                        backgroundColor: AppColors.gold.withValues(alpha: .12),
                        foregroundColor: AppColors.gold,
                        child: Text('${index + 1}'),
                      ),
                      title: Text(
                        _players[index],
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      subtitle: const Text('Start op −1'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ReorderableDragStartListener(
                            index: index,
                            child: const Padding(
                              padding: EdgeInsets.all(10),
                              child: Icon(Icons.drag_indicator_rounded),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Verwijderen',
                            onPressed: () =>
                                setState(() => _players.removeAt(index)),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 30),
              const SectionHeading(title: 'Waar spelen jullie om?'),
              const SizedBox(height: 12),
              SegmentedButton<ScoreUnit>(
                segments: [
                  for (final unit in ScoreUnit.values)
                    ButtonSegment(
                      value: unit,
                      label: Text(unit.label),
                      icon: Text(
                        unit.symbol,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                ],
                selected: {_unit},
                onSelectionChanged: (selection) {
                  HapticFeedback.selectionClick();
                  setState(() => _unit = selection.first);
                },
                showSelectedIcon: false,
                multiSelectionEnabled: false,
              ),
              const SizedBox(height: 30),
              FilledButton.icon(
                onPressed: _players.length >= 2 && !_saving ? _start : null,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow_rounded),
                label: Text(
                  _players.length < 2
                      ? 'Voeg minimaal 2 spelers toe'
                      : 'Start met ${_unit.format(_players.length)} in de pot',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addTypedPlayer() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    _addPlayer(name);
    _nameController.clear();
    _focusNode.requestFocus();
  }

  void _addPlayer(String name) {
    if (_players.length >= 8) return;
    if (_players.any((item) => item.toLowerCase() == name.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deze speler staat al in de lijst.')),
      );
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _players.add(name.trim()));
  }

  Future<void> _start() async {
    setState(() => _saving = true);
    try {
      final preview = widget.controller.engine.startGame(_players, _unit);
      final amounts = await showModalBottomSheet<List<int>>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => RoundSettingsSheet(game: preview),
      );
      if (amounts == null) return;
      await widget.controller.startGame(_players, _unit);
      await widget.controller.configureRound(amounts[0], amounts[1]);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      await Navigator.of(context)
          .pushReplacement(potRoute(GameScreen(controller: widget.controller)));
    } on GameRuleException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
