// Feuilles de la fiche produit pour modifier un magasin ou y ajouter un prix
import 'package:flutter/material.dart';

import '../../theme.dart';

String _euros(double value) => '${value.toStringAsFixed(2)} €';

double? _parsePrice(String text) {
  final value = double.tryParse(text.trim().replaceAll(',', '.'));
  return value != null && value > 0 ? value : null;
}

/// Choix fait dans [showStoreEditSheet]
sealed class StoreEditAction {
  const StoreEditAction();
}

/// Les scans de ce produit dans ce magasin passent dans [newStore]
class StoreMoved extends StoreEditAction {
  final String newStore;
  const StoreMoved(this.newStore);
}

/// Le magasin est renommé en [newName] partout (tous les produits)
class StoreRenamed extends StoreEditAction {
  final String newName;
  const StoreRenamed(this.newName);
}

/// Corriger le dernier prix relevé dans ce magasin
class StoreLastPriceEdit extends StoreEditAction {
  const StoreLastPriceEdit();
}

/// Retirer ce magasin des scans de ce produit (confirmé dans la feuille)
class StoreRemoved extends StoreEditAction {
  const StoreRemoved();
}

/// Feuille d'un magasin de la fiche produit : changer de magasin (ce produit
/// ou partout), corriger le dernier prix, retirer le magasin.
/// Retourne `null` si l'utilisateur ferme la feuille.
Future<StoreEditAction?> showStoreEditSheet(
  BuildContext context, {
  required String storeName,
  required double lastPrice,
  required int productScanCount,
  required int storeScanCount,
  required List<String> knownStores,
  bool canRename = true,
  bool canRemove = true,
}) {
  return showModalBottomSheet<StoreEditAction>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surfaceDark,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _StoreEditSheet(
      storeName: storeName,
      lastPrice: lastPrice,
      productScanCount: productScanCount,
      storeScanCount: storeScanCount,
      knownStores: knownStores,
      canRename: canRename,
      canRemove: canRemove,
    ),
  );
}

class _StoreEditSheet extends StatefulWidget {
  final String storeName;
  final double lastPrice;
  final int productScanCount;
  final int storeScanCount;
  final List<String> knownStores;
  final bool canRename;
  final bool canRemove;

  const _StoreEditSheet({
    required this.storeName,
    required this.lastPrice,
    required this.productScanCount,
    required this.storeScanCount,
    required this.knownStores,
    required this.canRename,
    required this.canRemove,
  });

  @override
  State<_StoreEditSheet> createState() => _StoreEditSheetState();
}

class _StoreEditSheetState extends State<_StoreEditSheet> {
  final TextEditingController _store = TextEditingController();

  /// `true` : renommer le magasin partout ; `false` : ce produit seulement
  bool _everywhere = false;
  bool _confirmRemove = false;

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  String get _target => _store.text.trim();

  bool get _canApply =>
      _target.isNotEmpty &&
      (_everywhere ? _target != widget.storeName : _target.toLowerCase() != widget.storeName.toLowerCase());

  void _apply() {
    if (!_canApply) return;
    Navigator.of(context).pop(_everywhere ? StoreRenamed(_target) : StoreMoved(_target));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scans = widget.productScanCount;
    final suggestions = widget.knownStores.where((s) => s.toLowerCase() != widget.storeName.toLowerCase()).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          key: const ValueKey('store_edit_sheet'),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // En-tête : magasin, dernier prix, nombre de scans
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.storefront, color: AppTheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.storeName,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '$scans scan${scans > 1 ? 's' : ''} de ce produit',
                          style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _euros(widget.lastPrice),
                    style: theme.textTheme.titleLarge?.copyWith(color: AppTheme.primary, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Changer de magasin
              Text(
                'Pas le bon magasin ?',
                style: theme.textTheme.titleSmall?.copyWith(color: AppTheme.textPrimary, fontWeight: FontWeight.w700),
              ),
              if (widget.canRename) ...[
                const SizedBox(height: 10),
                SegmentedButton<bool>(
                  key: const ValueKey('store_edit_scope'),
                  segments: [
                    ButtonSegment(
                      value: false,
                      label: Text('Ce produit ($scans)', key: const ValueKey('store_scope_product')),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text('Partout (${widget.storeScanCount})', key: const ValueKey('store_scope_everywhere')),
                    ),
                  ],
                  selected: {_everywhere},
                  onSelectionChanged: (selection) => setState(() => _everywhere = selection.first),
                  showSelectedIcon: false,
                ),
              ],
              const SizedBox(height: 8),
              Text(
                _everywhere
                    ? '« ${widget.storeName} » est renommé dans tous tes produits, tes tickets et le scanner '
                          '(${widget.storeScanCount} scan${widget.storeScanCount > 1 ? 's' : ''}). '
                          'Choisir un magasin existant regroupe les deux.'
                    : 'Les $scans scan${scans > 1 ? 's' : ''} de ce produit chez ${widget.storeName} '
                          'passent dans le magasin choisi. Les autres produits ne changent pas.',
                style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              if (suggestions.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final store in suggestions)
                      ChoiceChip(
                        key: ValueKey('store_suggestion_$store'),
                        label: Text(store),
                        selected: _target.toLowerCase() == store.toLowerCase(),
                        onSelected: (_) => setState(() => _store.text = store),
                        selectedColor: AppTheme.primary.withValues(alpha: 0.3),
                        backgroundColor: AppTheme.surfaceLight,
                        showCheckmark: false,
                      ),
                  ],
                ),
              const SizedBox(height: 10),
              TextField(
                key: const ValueKey('store_edit_input'),
                controller: _store,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _apply(),
                decoration: InputDecoration(
                  labelText: _everywhere ? 'Nouveau nom du magasin' : 'Autre magasin',
                  hintText: 'ex. Lidl Bastille',
                  isDense: true,
                  prefixIcon: const Icon(Icons.edit_location_alt_outlined),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const ValueKey('store_edit_apply'),
                onPressed: _canApply ? _apply : null,
                icon: Icon(_everywhere ? Icons.drive_file_rename_outline : Icons.swap_horiz),
                label: Text(
                  _target.isEmpty
                      ? (_everywhere ? 'Renommer le magasin' : 'Changer de magasin')
                      : (_everywhere ? 'Renommer en « $_target »' : 'Déplacer vers « $_target »'),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(color: AppTheme.surfaceLight, height: 1),

              // Autres actions
              ListTile(
                key: const ValueKey('store_edit_last_price'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.edit_outlined, color: AppTheme.accent),
                title: const Text('Corriger le dernier prix', style: TextStyle(color: AppTheme.textPrimary)),
                subtitle: Text(
                  '${_euros(widget.lastPrice)} chez ${widget.storeName}',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                onTap: () => Navigator.of(context).pop(const StoreLastPriceEdit()),
              ),
              if (widget.canRemove)
                _confirmRemove
                    ? Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.error.withValues(alpha: 0.4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Les $scans scan${scans > 1 ? 's' : ''} de ce produit chez ${widget.storeName} '
                              'n\'auront plus de magasin. Les prix restent dans l\'historique.',
                              style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textPrimary),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () => setState(() => _confirmRemove = false),
                                  child: const Text('Annuler'),
                                ),
                                const SizedBox(width: 8),
                                FilledButton(
                                  key: const ValueKey('store_edit_confirm_remove'),
                                  style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
                                  onPressed: () => Navigator.of(context).pop(const StoreRemoved()),
                                  child: const Text('Retirer'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                    : ListTile(
                        key: const ValueKey('store_edit_remove'),
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.remove_circle_outline, color: AppTheme.error),
                        title: const Text('Retirer ce magasin du produit', style: TextStyle(color: AppTheme.error)),
                        onTap: () => setState(() => _confirmRemove = true),
                      ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Feuille « Ajouter un prix » de la fiche produit : un prix relevé dans un
/// magasin sans scanner le produit. Retourne le magasin et le prix, ou `null`.
Future<({String store, double price})?> showAddStorePriceSheet(
  BuildContext context, {
  required String productName,
  required List<String> knownStores,

  /// Magasins où le produit a déjà un prix (proposés après les autres)
  List<String> productStores = const [],
}) {
  return showModalBottomSheet<({String store, double price})>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surfaceDark,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) =>
        _AddStorePriceSheet(productName: productName, knownStores: knownStores, productStores: productStores),
  );
}

class _AddStorePriceSheet extends StatefulWidget {
  final String productName;
  final List<String> knownStores;
  final List<String> productStores;

  const _AddStorePriceSheet({required this.productName, required this.knownStores, required this.productStores});

  @override
  State<_AddStorePriceSheet> createState() => _AddStorePriceSheetState();
}

class _AddStorePriceSheetState extends State<_AddStorePriceSheet> {
  final TextEditingController _store = TextEditingController();
  final TextEditingController _price = TextEditingController();

  @override
  void dispose() {
    _store.dispose();
    _price.dispose();
    super.dispose();
  }

  bool get _valid => _store.text.trim().isNotEmpty && _parsePrice(_price.text) != null;

  void _save() {
    final price = _parsePrice(_price.text);
    final store = _store.text.trim();
    if (store.isEmpty || price == null) return;
    Navigator.of(context).pop((store: store, price: price));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final already = widget.productStores.map((s) => s.toLowerCase()).toSet();
    // D'abord les magasins où le produit n'a pas encore de prix
    final suggestions = [
      ...widget.knownStores.where((s) => !already.contains(s.toLowerCase())),
      ...widget.knownStores.where((s) => already.contains(s.toLowerCase())),
    ];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          key: const ValueKey('add_price_sheet'),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Ajouter un prix',
                style: theme.textTheme.titleLarge?.copyWith(color: AppTheme.textPrimary, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Le prix de « ${widget.productName} » vu dans un magasin, sans le scanner.',
                style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final store in suggestions)
                    ChoiceChip(
                      key: ValueKey('add_price_store_$store'),
                      label: Text(store),
                      selected: _store.text.trim().toLowerCase() == store.toLowerCase(),
                      onSelected: (_) => setState(() => _store.text = store),
                      selectedColor: AppTheme.primary.withValues(alpha: 0.3),
                      backgroundColor: AppTheme.surfaceLight,
                      showCheckmark: false,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                key: const ValueKey('add_price_store_input'),
                controller: _store,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Magasin',
                  isDense: true,
                  prefixIcon: Icon(Icons.storefront_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('add_price_input'),
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _save(),
                decoration: const InputDecoration(
                  labelText: 'Prix',
                  suffixText: '€',
                  isDense: true,
                  prefixIcon: Icon(Icons.euro),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const ValueKey('add_price_save'),
                onPressed: _valid ? _save : null,
                icon: const Icon(Icons.check),
                label: const Text('Enregistrer le prix'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
