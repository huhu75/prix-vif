import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import '../utils/unit_price.dart';

/// Résultat de [showArticleEditDialog]
sealed class ArticleEditResult {
  const ArticleEditResult();
}

/// L'article a été modifié
class ArticleUpdated extends ArticleEditResult {
  final ScannedItem item;
  const ArticleUpdated(this.item);
}

/// L'utilisateur a demandé la suppression de l'article
class ArticleDeleted extends ArticleEditResult {
  const ArticleDeleted();
}

double? _parseNumber(String text) => double.tryParse(text.trim().replaceAll(',', '.'));

/// Ouvre la fenêtre de modification d'un article déjà enregistré.
/// Retourne `null` si l'utilisateur annule.
Future<ArticleEditResult?> showArticleEditDialog(BuildContext context, ScannedItem item) {
  return showDialog<ArticleEditResult>(
    context: context,
    builder: (_) => _ArticleEditDialog(item: item),
  );
}

class _ArticleEditDialog extends StatefulWidget {
  final ScannedItem item;

  const _ArticleEditDialog({required this.item});

  @override
  State<_ArticleEditDialog> createState() => _ArticleEditDialogState();
}

class _ArticleEditDialogState extends State<_ArticleEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _price;
  late final TextEditingController _quantity;
  late final TextEditingController _unit;
  late final TextEditingController _store;
  bool _confirmDelete = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _name = TextEditingController(text: item.name);
    _price = TextEditingController(text: item.price.toStringAsFixed(2));
    _quantity = TextEditingController(text: item.quantity != null ? formatAmount(item.quantity!) : '');
    _unit = TextEditingController(text: item.unit ?? '');
    _store = TextEditingController(text: item.storeName ?? '');
  }

  @override
  void dispose() {
    for (final c in [_name, _price, _quantity, _unit, _store]) {
      c.dispose();
    }
    super.dispose();
  }

  UnitPrice? get _previewUnitPrice {
    final price = _parseNumber(_price.text);
    if (price == null) return null;
    return UnitPrice.of(price, _parseNumber(_quantity.text), _unit.text.trim());
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final quantityText = _quantity.text.trim();
    final unitText = _unit.text.trim();
    final storeText = _store.text.trim();
    final item = widget.item;
    final updated = ScannedItem(
      id: item.id,
      name: _name.text.trim(),
      brand: item.brand,
      price: _parseNumber(_price.text)!,
      currency: item.currency,
      quantity: _parseNumber(quantityText),
      unit: unitText.isEmpty ? null : unitText,
      scanDate: item.scanDate,
      imageUrl: item.imageUrl,
      barcode: item.barcode,
      storeName: storeText.isEmpty ? null : storeText,
      nutriscore: item.nutriscore,
      categories: item.categories,
    );
    Navigator.of(context).pop(ArticleUpdated(updated));
  }

  InputDecoration _decoration(String label, {String? hint, String? suffix}) => InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffix,
        isDense: true,
        border: const OutlineInputBorder(),
      );

  @override
  Widget build(BuildContext context) {
    final unitPrice = _previewUnitPrice;

    return AlertDialog(
      backgroundColor: AppTheme.surfaceDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Modifier l\'article'),
      content: Form(
        key: _formKey,
        onChanged: () => setState(() {}),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const ValueKey('edit_name'),
                controller: _name,
                decoration: _decoration('Nom'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Nom obligatoire' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('edit_price'),
                controller: _price,
                decoration: _decoration('Prix', suffix: '€'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  final price = _parseNumber(v ?? '');
                  if (price == null || price <= 0) return 'Prix invalide';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const ValueKey('edit_quantity'),
                      controller: _quantity,
                      decoration: _decoration('Quantité', hint: '500'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        final text = v?.trim() ?? '';
                        if (text.isNotEmpty && _parseNumber(text) == null) return 'Nombre';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      key: const ValueKey('edit_unit'),
                      controller: _unit,
                      decoration: _decoration('Unité', hint: 'g, L, x 1.5L'),
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    unitPrice != null ? 'Soit ${unitPrice.format()}' : 'Contenance inconnue : pas de prix au kg / L',
                    style: TextStyle(
                      color: unitPrice != null ? AppTheme.accent : AppTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('edit_store'),
                controller: _store,
                decoration: _decoration('Magasin'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('edit_delete'),
          onPressed: () {
            if (_confirmDelete) {
              Navigator.of(context).pop(const ArticleDeleted());
            } else {
              setState(() => _confirmDelete = true);
            }
          },
          child: Text(
            _confirmDelete ? 'Confirmer la suppression' : 'Supprimer',
            style: const TextStyle(color: AppTheme.error),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          key: const ValueKey('edit_save'),
          onPressed: _save,
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
