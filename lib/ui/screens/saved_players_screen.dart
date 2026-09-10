import 'package:flutter/material.dart';

import '../../application/app_controller.dart';
import '../../domain/game_engine.dart';
import '../app_theme.dart';
import '../widgets/app_widgets.dart';

class SavedPlayersScreen extends StatelessWidget {
  const SavedPlayersScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, child) => FeltScaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Opgeslagen spelers'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 88, 20, 24),
          child: controller.rememberedPlayers.isEmpty
              ? Center(
                  child: GlassCard(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.group_outlined,
                          size: 42,
                          color: AppColors.gold,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Nog geen spelers',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Spelers worden onthouden zodra je een pot start.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: controller.rememberedPlayers.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final player = controller.rememberedPlayers[index];
                    return GlassCard(
                      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppColors.gold.withValues(
                              alpha: .14,
                            ),
                            foregroundColor: AppColors.gold,
                            child: Text(
                              player.name.characters.first.toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Text(
                              player.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Hernoemen',
                            onPressed: () =>
                                _rename(context, player.id, player.name),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: 'Verwijderen',
                            onPressed: () =>
                                controller.deleteRememberedPlayer(player.id),
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    ),
  );

  Future<void> _rename(
    BuildContext context,
    String id,
    String currentName,
  ) async {
    final textController = TextEditingController(text: currentName);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Speler hernoemen'),
        content: TextField(
          controller: textController,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Naam'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuleren'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, textController.text),
            child: const Text('Opslaan'),
          ),
        ],
      ),
    );
    textController.dispose();
    if (value == null) return;
    try {
      await controller.renameRememberedPlayer(id, value);
    } on GameRuleException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }
}
