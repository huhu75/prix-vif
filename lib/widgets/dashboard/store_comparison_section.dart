// Comparateur multi-magasins (même produit, enseignes différentes)
import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../analytics/analytics.dart';

/// Section comparateur multi-magasins sur le tableau de bord
class ProductStoreComparisonSection extends StatelessWidget {
  static const int _maxDisplayed = 5;

  final List<ProductStoreComparisonItem> comparisons;
  final void Function(String productId, String productName) onProductTap;
  final VoidCallback? onViewAllProducts;

  const ProductStoreComparisonSection({
    super.key,
    required this.comparisons,
    required this.onProductTap,
    this.onViewAllProducts,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayed = comparisons.take(_maxDisplayed).toList();
    final remainingCount = comparisons.length - displayed.length;

    return Column(
      key: const ValueKey('store_comparison_section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.store,
                  color: AppTheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Comparateur multi-magasins',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (onViewAllProducts != null)
              TextButton(
                onPressed: onViewAllProducts,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Tous',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          comparisons.isNotEmpty
              ? 'Écarts de prix constatés pour un même produit selon l\'enseigne'
              : 'Comparez les prix d\'un même article entre vos magasins habituels',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppTheme.textMuted,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: AppTheme.glassmorphism(),
          padding: const EdgeInsets.all(14),
          child: comparisons.isEmpty
              ? _buildEmptyState(context)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...displayed.map((item) => _ProductStoreComparisonCard(
                          item: item,
                          onTap: () => onProductTap(item.productId, item.name),
                        )),
                    if (remainingCount > 0 && onViewAllProducts != null)
                      Center(
                        child: TextButton.icon(
                          onPressed: onViewAllProducts,
                          icon: const Icon(Icons.arrow_forward, size: 14, color: AppTheme.primary),
                          label: Text(
                            'Voir les $remainingCount autres comparaisons',
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.storefront_outlined,
            color: AppTheme.primary,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Scannez dans plusieurs enseignes',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Dès qu\'un même produit sera scanné dans deux magasins différents, le meilleur prix et l\'économie réalisable apparaîtront ici automatiquement.',
                style: TextStyle(
                  color: AppTheme.textSecondary.withValues(alpha: 0.8),
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Carte comparative d'un produit entre magasins
class _ProductStoreComparisonCard extends StatelessWidget {
  final ProductStoreComparisonItem item;
  final VoidCallback onTap;

  const _ProductStoreComparisonCard({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasDiff = item.hasPriceDifference;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hasDiff
                  ? AppTheme.primary.withValues(alpha: 0.3)
                  : AppTheme.surfaceLight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ligne 1 : Nom du produit + Badge d'économie
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (item.brand != null && item.brand!.isNotEmpty)
                          Text(
                            item.brand!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.textMuted,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  if (hasDiff)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.savings_outlined, size: 12, color: AppTheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            '-${item.priceDiff.toStringAsFixed(2)} € (-${item.savingPercent.toStringAsFixed(0)}%)',
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              // Ligne 2 : Comparatif des magasins
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundDark.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    // Moins cher
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.emoji_events, size: 14, color: AppTheme.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.cheapestStore,
                                  style: const TextStyle(
                                    color: AppTheme.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${item.cheapestPrice.toStringAsFixed(2)} €',
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasDiff) ...[
                      Container(
                        height: 24,
                        width: 1,
                        color: AppTheme.surfaceLight,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      // Plus cher
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.mostExpensiveStore,
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${item.mostExpensivePrice.toStringAsFixed(2)} €',
                              style: TextStyle(
                                color: AppTheme.textSecondary.withValues(alpha: 0.8),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: AppTheme.textMuted,
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
