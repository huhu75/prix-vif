// Mes magasins (depuis le Profil) : ajouter, renommer ou retirer un magasin
import 'package:flutter/material.dart';

import '../services/scan_repository.dart';
import '../theme.dart';
import '../widgets/magic_button.dart';
import '../widgets/magic_title.dart';
import '../widgets/nav_buttons.dart';

class StoresScreen extends StatefulWidget {
  final ScanRepository repository;

  /// Appelé après une modification, pour recharger l'app
  final Future<void> Function()? onChanged;

  const StoresScreen({super.key, required this.repository, this.onChanged});

  @override
  State<StoresScreen> createState() => _StoresScreenState();
}

class _StoresScreenState extends State<StoresScreen> {
  ScanRepository get _repo => widget.repository;

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _changed() async {
    await widget.onChanged?.call();
    if (mounted) setState(() {});
  }

  Future<void> _add() async {
    final name = await _askName(title: 'Ajouter un magasin', action: 'Ajouter');
    if (name == null) return;
    await _repo.addCustomStore(name);
    await _changed();
    _toast('« $name » ajouté');
  }

  Future<void> _edit(String store) async {
    final count = _repo.countStoreArticles(store);
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                store,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
              ),
              Text(
                '$count prix relevé${count > 1 ? 's' : ''}',
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              ListTile(
                key: const ValueKey('store_rename'),
                leading: const Icon(Icons.drive_file_rename_outline, color: AppTheme.primary),
                title: const Text('Renommer'),
                subtitle: const Text('Partout : produits, tickets et scanner'),
                onTap: () => Navigator.of(sheetContext).pop('rename'),
              ),
              ListTile(
                key: const ValueKey('store_remove'),
                leading: const Icon(Icons.remove_circle_outline, color: AppTheme.error),
                title: const Text('Retirer de la liste', style: TextStyle(color: AppTheme.error)),
                subtitle: const Text('Les prix déjà relevés restent dans l\'historique'),
                onTap: () => Navigator.of(sheetContext).pop('remove'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'rename') {
      final name = await _askName(title: 'Renommer « $store »', action: 'Renommer', initial: store);
      if (name == null || name == store) return;
      final renamed = await _repo.renameStore(store, name);
      await _changed();
      _toast('« $store » renommé en « $name » ($renamed prix)');
    } else if (choice == 'remove') {
      await _repo.removeStore(store);
      await _changed();
      _toast('« $store » retiré de la liste');
    }
  }

  Future<String?> _askName({required String title, required String action, String initial = ''}) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(title: title, action: action, initial: initial),
    );
    return name == null || name.isEmpty ? null : name;
  }

  @override
  Widget build(BuildContext context) {
    final stores = _repo.getAllKnownStores();
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const NeonTitle(text: 'MES MAGASINS', fontSize: 20),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        itemCount: stores.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final store = stores[i];
          final count = _repo.countStoreArticles(store);
          return Material(
            color: Colors.transparent,
            child: Ink(
              decoration: AppTheme.glassmorphism().copyWith(borderRadius: BorderRadius.circular(16)),
              child: InkWell(
                key: ValueKey('store_row_$store'),
                borderRadius: BorderRadius.circular(16),
                onTap: () => _edit(store),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                        child: Text(
                          store.characters.first.toUpperCase(),
                          style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          store,
                          style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        count == 0 ? 'aucun prix' : '$count prix',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                      const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: MagicButton(
            key: const ValueKey('store_add'),
            text: 'AJOUTER UN MAGASIN',
            icon: Icons.add_business_outlined,
            onPressed: _add,
          ),
        ),
      ),
    );
  }
}

/// Dialogue de saisie d'un nom de magasin (il garde son champ jusqu'à la fin
/// de son animation de fermeture)
class _NameDialog extends StatefulWidget {
  final String title;
  final String action;
  final String initial;

  const _NameDialog({required this.title, required this.action, required this.initial});

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surfaceDark,
      title: Text(widget.title),
      content: TextField(
        key: const ValueKey('store_name_input'),
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(hintText: 'Lidl Bastille'),
        onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
        FilledButton(
          key: const ValueKey('store_name_confirm'),
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: Text(widget.action),
        ),
      ],
    );
  }
}
