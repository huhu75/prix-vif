// Choix de la catégorie d'un produit, parmi celles déjà connues ou en créant une nouvelle
import 'package:flutter/material.dart';

import '../models/product_category.dart';
import '../theme.dart';

/// Ouvre le choix de catégorie : recherche parmi [known], ou création d'une
/// nouvelle catégorie à partir du texte tapé. Retourne la catégorie choisie
/// (marquée « choisie à la main »), ou `null` si l'utilisateur annule.
Future<ProductCategory?> showCategoryPickerSheet(
  BuildContext context, {
  required List<ProductCategory> known,
  ProductCategory? current,
}) {
  return showModalBottomSheet<ProductCategory>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surfaceDark,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _CategoryPicker(known: known, current: current),
  );
}

class _CategoryPicker extends StatefulWidget {
  final List<ProductCategory> known;
  final ProductCategory? current;

  const _CategoryPicker({required this.known, this.current});

  @override
  State<_CategoryPicker> createState() => _CategoryPickerState();
}

class _CategoryPickerState extends State<_CategoryPicker> {
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = _query.text.trim();
    final lower = text.toLowerCase();
    final matches = widget.known.where((c) => lower.isEmpty || c.label.toLowerCase().contains(lower)).toList();
    final exists = widget.known.any((c) => c.label.toLowerCase() == lower);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Catégorie du produit',
                style: theme.textTheme.titleMedium?.copyWith(color: AppTheme.textPrimary, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Les produits d\'une même catégorie sont comparés entre eux, toutes marques et tous magasins.',
                style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('category_picker_query'),
                controller: _query,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Jus de pomme, lessive liquide…',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  children: [
                    if (text.isNotEmpty && !exists)
                      ListTile(
                        key: const ValueKey('category_picker_create'),
                        leading: const Icon(Icons.add_circle_outline, color: AppTheme.primary),
                        title: Text('Créer « $text »', style: const TextStyle(color: AppTheme.primary)),
                        onTap: () => Navigator.of(context).pop(ProductCategory.custom(text)),
                      ),
                    for (final category in matches)
                      ListTile(
                        key: ValueKey('category_picker_${category.id}'),
                        leading: Icon(
                          category == widget.current ? Icons.check_circle : Icons.category_outlined,
                          color: category == widget.current ? AppTheme.success : AppTheme.textMuted,
                        ),
                        title: Text(category.label, style: const TextStyle(color: AppTheme.textPrimary)),
                        onTap: () => Navigator.of(context).pop(category.asManual()),
                      ),
                    if (matches.isEmpty && text.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Aucune catégorie connue pour l\'instant : tape un nom pour en créer une.',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
