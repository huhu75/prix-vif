// Choix du magasin dans le scanner (étape 1, avant de scanner)
import 'package:flutter/material.dart';
import '../../theme.dart';

/// Étape 1 du scanner : liste déroulante des magasins + bouton d'ajout.
/// [selectedStore] vaut `null` tant qu'aucun magasin n'est choisi pour la
/// séance ; [lastStore] est alors proposé en raccourci (« Dernier : … »).
class StoreSelector extends StatelessWidget {
  final List<String> stores;
  final String? selectedStore;
  final String? lastStore;

  /// Texte affiché dans la liste ; le scanner le vide à chaque nouvelle séance
  final TextEditingController? controller;
  final ValueChanged<String> onSelected;
  final VoidCallback onAdd;

  /// Ouvre la gestion des magasins (suppression) ; bouton affiché si non `null`
  final VoidCallback? onManage;

  const StoreSelector({
    super.key,
    required this.stores,
    required this.selectedStore,
    required this.onSelected,
    required this.onAdd,
    this.controller,
    this.lastStore,
    this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    final chosen = selectedStore != null;
    final shortcut = !chosen && lastStore != null && stores.contains(lastStore) ? lastStore : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                chosen ? Icons.check_circle : Icons.looks_one,
                size: 16,
                color: chosen ? AppTheme.success : AppTheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                chosen ? 'Magasin' : 'Choisis ton magasin',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: chosen ? AppTheme.success : AppTheme.primary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownMenu<String>(
                  key: const ValueKey('store_dropdown'),
                  controller: controller,
                  initialSelection: selectedStore,
                  hintText: 'Choisir un magasin…',
                  onSelected: (String? value) {
                    if (value != null) onSelected(value);
                  },
                  dropdownMenuEntries: stores
                      .map<DropdownMenuEntry<String>>((String value) {
                    return DropdownMenuEntry<String>(
                      value: value,
                      label: value,
                    );
                  }).toList(),
                  width: double.infinity,
                  inputDecorationTheme: InputDecorationTheme(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    constraints: const BoxConstraints(minHeight: 48),
                    isDense: true,
                    filled: true,
                    fillColor: AppTheme.surfaceLight,
                    hintStyle: const TextStyle(color: AppTheme.textSecondary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
                    ),
                    // Bordure bleue tant que le magasin reste à choisir
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: chosen
                          ? BorderSide(color: Colors.black.withValues(alpha: 0.08))
                          : BorderSide(color: AppTheme.primary.withValues(alpha: 0.6), width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                    ),
                  ),
                  textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _AddStoreButton(
                onAdd: onAdd,
              ),
              if (onManage != null) ...[
                const SizedBox(width: 8),
                _ManageStoresButton(onManage: onManage!),
              ],
            ],
          ),
          if (shortcut != null) ...[
            const SizedBox(height: 8),
            ActionChip(
              key: const ValueKey('store_last_shortcut'),
              avatar: const Icon(Icons.history, size: 18, color: AppTheme.primary),
              label: Text('Dernier : $shortcut'),
              labelStyle: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
              backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
              side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.4)),
              onPressed: () => onSelected(shortcut),
            ),
          ],
        ],
      ),
    );
  }
}

class _AddStoreButton extends StatefulWidget {
  final VoidCallback onAdd;
  const _AddStoreButton({required this.onAdd});

  @override
  State<_AddStoreButton> createState() => _AddStoreButtonState();
}

class _AddStoreButtonState extends State<_AddStoreButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onAdd();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Icon(Icons.add, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }
}

/// Bouton secondaire « gérer les magasins » (suppression), à côté du « + »
class _ManageStoresButton extends StatefulWidget {
  final VoidCallback onManage;
  const _ManageStoresButton({required this.onManage});

  @override
  State<_ManageStoresButton> createState() => _ManageStoresButtonState();
}

class _ManageStoresButtonState extends State<_ManageStoresButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onManage();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          decoration: BoxDecoration(
            color: AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Icon(Icons.delete_outline, color: AppTheme.textSecondary, size: 24),
          ),
        ),
      ),
    );
  }
}
