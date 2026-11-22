// Dialogue « Gérer les magasins » : liste les magasins proposés dans le
// scanner et permet d'en supprimer (avec confirmation).
import 'package:flutter/material.dart';
import '../../theme.dart';

/// Ouvre le dialogue de gestion des magasins. [onRemove] est appelé après
/// confirmation pour chaque magasin supprimé.
Future<void> showStoreManagementDialog(
  BuildContext context, {
  required List<String> stores,
  required Future<void> Function(String store) onRemove,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => _StoreManagementDialog(
      stores: stores,
      onRemove: onRemove,
    ),
  );
}

class _StoreManagementDialog extends StatefulWidget {
  final List<String> stores;
  final Future<void> Function(String store) onRemove;

  const _StoreManagementDialog({required this.stores, required this.onRemove});

  @override
  State<_StoreManagementDialog> createState() => _StoreManagementDialogState();
}

class _StoreManagementDialogState extends State<_StoreManagementDialog> {
  late List<String> _stores;

  @override
  void initState() {
    super.initState();
    _stores = List.of(widget.stores);
  }

  Future<void> _remove(String store) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (confirmContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Supprimer « $store » ?'),
        content: const Text(
          'Le magasin disparaîtra de la liste. Les prix déjà relevés dans ce '
          'magasin restent dans ton historique.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(confirmContext).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(confirmContext).pop(true),
            child: const Text('Supprimer', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.onRemove(store);
    if (mounted) {
      setState(() => _stores.removeWhere((s) => s.toLowerCase() == store.toLowerCase()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Gérer les magasins'),
      content: SizedBox(
        width: double.maxFinite,
        child: _stores.isEmpty
            ? const Text(
                'Aucun magasin dans la liste.',
                style: TextStyle(color: AppTheme.textSecondary),
              )
            : ListView.separated(
                shrinkWrap: true,
                itemCount: _stores.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final store = _stores[index];
                  return ListTile(
                    key: ValueKey('manage_store_$store'),
                    dense: true,
                    contentPadding: const EdgeInsets.only(left: 4),
                    title: Text(
                      store,
                      style: const TextStyle(color: AppTheme.textPrimary),
                    ),
                    trailing: IconButton(
                      tooltip: 'Supprimer ce magasin',
                      icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                      onPressed: () => _remove(store),
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
      ],
    );
  }
}
