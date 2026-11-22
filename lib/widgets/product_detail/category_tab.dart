// Onglet « Catégorie » de la fiche produit : toutes les marques de la catégorie, au kg / L
import 'package:flutter/material.dart';

import '../../analytics/analytics.dart';
import '../../models/product_category.dart';
import '../../theme.dart';
import '../../utils/unit_price.dart';

String _euros(double value) => '${value.toStringAsFixed(2)} €';

/// Produits de la même catégorie (toutes marques, tous magasins), du moins
/// cher au plus cher au kg / L ; le produit ouvert est mis en évidence.
class CategoryTab extends StatelessWidget {
  final ProductCategory? category;
  final CategoryGroup? group;

  /// Clé du produit ouvert (pour le repérer dans la liste)
  final String productKey;

  /// Ouvre le choix de catégorie
  final VoidCallback onChooseCategory;

  /// Ouvre la fiche d'un autre produit de la catégorie
  final void Function(String productId, String productName) onOpenProduct;

  const CategoryTab({
    super.key,
    required this.category,
    required this.group,
    required this.productKey,
    required this.onChooseCategory,
    required this.onOpenProduct,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final group = this.group;
    final others = group?.offers.where((o) => o.productKey != productKey).length ?? 0;

    return ListView(
      key: const ValueKey('product_category_tab'),
      padding: const EdgeInsets.all(16),
      children: [
        // Catégorie et bouton pour la changer
        Container(
          decoration: AppTheme.glassmorphism(),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.category_outlined, color: AppTheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Catégorie', style: theme.textTheme.labelSmall?.copyWith(color: AppTheme.textMuted)),
                    Text(
                      category?.label ?? 'Sans catégorie',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: category == null ? AppTheme.textSecondary : AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                key: const ValueKey('choose_category'),
                onPressed: onChooseCategory,
                child: Text(category == null ? 'Choisir' : 'Modifier'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (category == null)
          _message(
            context,
            'Choisis une catégorie (par exemple « Jus de pomme ») pour comparer ce produit aux autres marques '
            'et aux autres magasins.',
          )
        else if (group == null || others == 0)
          _message(
            context,
            'C\'est le seul produit de cette catégorie pour l\'instant. Scanne d\'autres marques pour comparer.',
          )
        else ...[
          Text(
            '${group.productCount} produits · ${group.storeCount} magasin${group.storeCount > 1 ? 's' : ''}'
            '${group.unit != null ? ' · du moins cher au plus cher en ${group.unit!.label}' : ''}',
            style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          for (final offer in group.offers)
            _OfferTile(
              offer: offer,
              comparable: group.isComparable(offer),
              isCheapest: identical(offer, group.cheapest),
              isCurrent: offer.productKey == productKey,
              onTap: offer.productKey == productKey ? null : () => onOpenProduct(offer.productId, offer.name),
            ),
        ],
      ],
    );
  }

  Widget _message(BuildContext context, String text) => Container(
        decoration: AppTheme.glassmorphism(),
        padding: const EdgeInsets.all(14),
        child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary)),
      );
}

class _OfferTile extends StatelessWidget {
  final CategoryOffer offer;
  final bool comparable;
  final bool isCheapest;
  final bool isCurrent;
  final VoidCallback? onTap;

  const _OfferTile({
    required this.offer,
    required this.comparable,
    required this.isCheapest,
    required this.isCurrent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = isCheapest ? AppTheme.success : AppTheme.textPrimary;
    final brand = offer.brand == null || offer.brand!.isEmpty ? '' : ' · ${offer.brand}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isCurrent ? AppTheme.primary : (isCheapest ? AppTheme.success.withValues(alpha: 0.6) : AppTheme.surfaceLight),
              width: isCurrent ? 1.5 : 1,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (isCheapest) ...[
                              const Icon(Icons.emoji_events, color: AppTheme.success, size: 16),
                              const SizedBox(width: 4),
                            ],
                            Expanded(
                              child: Text(
                                '${offer.name}$brand',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(color: accent, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${offer.storeName} · ${_euros(offer.price)}'
                          '${isCurrent ? ' · ce produit' : ''}${comparable ? '' : ' · contenance inconnue'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isCurrent ? AppTheme.primary : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    comparable ? offer.unitPrice!.format() : _euros(offer.price),
                    style: theme.textTheme.bodyLarge?.copyWith(color: accent, fontWeight: FontWeight.w800),
                  ),
                  if (onTap != null) const Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
