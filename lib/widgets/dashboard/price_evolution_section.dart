// Évolution des prix des produits scannés
import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../models/product_analysis_models.dart';
import '../../analytics/analytics.dart';

/// Section affichant l'évolution des prix des produits scannés
class ProductPriceEvolutionSection extends StatelessWidget {
  static const int _maxDisplayed = 5;

  final List<ProductPriceEvolutionItem> evolutions;
  final void Function(String productId, String productName) onProductTap;
  final VoidCallback? onViewAllProducts;

  const ProductPriceEvolutionSection({
    super.key,
    required this.evolutions,
    required this.onProductTap,
    this.onViewAllProducts,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (evolutions.isEmpty) {
      return const SizedBox.shrink();
    }

    final hasVariations = evolutions.any((e) => e.hasEvolution && e.priceDiff.abs() > 0.01);
    final displayed = evolutions.take(_maxDisplayed).toList();
    final remainingCount = evolutions.length - displayed.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.trending_up,
                  color: AppTheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Évolution des prix des produits',
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
          hasVariations
              ? 'Variations de prix constatées au fil de vos achats'
              : 'Suivi de vos articles scannés (cliquez pour voir la courbe)',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppTheme.textMuted,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: AppTheme.glassmorphism(),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...displayed.map((item) => _ProductPriceEvolutionCard(
                    item: item,
                    onTap: () => onProductTap(item.productId, item.name),
                  )),
              if (remainingCount > 0 && onViewAllProducts != null)
                Center(
                  child: TextButton.icon(
                    onPressed: onViewAllProducts,
                    icon: const Icon(Icons.arrow_forward, size: 14, color: AppTheme.primary),
                    label: Text(
                      'Voir les $remainingCount autres produits',
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
}

/// Carte synthétique pour un produit dans la section d'évolution
class _ProductPriceEvolutionCard extends StatelessWidget {
  final ProductPriceEvolutionItem item;
  final VoidCallback onTap;

  const _ProductPriceEvolutionCard({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUp = item.trend == PriceTrend.up;
    final isDown = item.trend == PriceTrend.down;

    final Color badgeColor;
    final Color badgeBg;
    if (isUp) {
      badgeColor = AppTheme.error;
      badgeBg = AppTheme.error.withValues(alpha: 0.14);
    } else if (isDown) {
      badgeColor = AppTheme.primary;
      badgeBg = AppTheme.primary.withValues(alpha: 0.14);
    } else {
      badgeColor = AppTheme.textMuted;
      badgeBg = AppTheme.surfaceLight;
    }

    final String changeLabel;
    if (item.hasEvolution) {
      if (item.trend == PriceTrend.stable) {
        changeLabel = 'Stable';
      } else {
        final sign = item.priceDiff > 0 ? '+' : '';
        changeLabel = '$sign${item.priceDiff.toStringAsFixed(2)} € ($sign${item.percentDiff.toStringAsFixed(1)}%)';
      }
    } else {
      changeLabel = '1 scan';
    }

    final metaList = <String>[];
    if (item.brand != null && item.brand!.isNotEmpty) {
      metaList.add(item.brand!);
    }
    if (item.latestStore != null && item.latestStore!.isNotEmpty) {
      metaList.add(item.latestStore!);
    }
    metaList.add('${item.scanCount} scan${item.scanCount > 1 ? 's' : ''}');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isUp
                  ? AppTheme.error.withValues(alpha: 0.28)
                  : (isDown ? AppTheme.primary.withValues(alpha: 0.28) : AppTheme.surfaceLight),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  item.hasEvolution ? item.trend.icon : Icons.insights_outlined,
                  color: badgeColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
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
                    const SizedBox(height: 2),
                    Text(
                      metaList.join(' · '),
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
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${item.latestPrice.toStringAsFixed(2)} €',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      changeLabel,
                      style: TextStyle(
                        color: badgeColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right,
                size: 16,
                color: AppTheme.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
