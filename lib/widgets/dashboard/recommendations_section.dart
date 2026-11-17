// Alternatives moins chères repérées dans d'autres enseignes
import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../analytics/analytics.dart';

/// Section des recommandations de produits alternatifs moins chers
class ProductRecommendationSection extends StatelessWidget {
  static const int _maxDisplayed = 3;

  final List<ProductRecommendationItem> recommendations;
  final void Function(String productId, String productName) onProductTap;
  final VoidCallback? onViewAllProducts;

  const ProductRecommendationSection({
    super.key,
    required this.recommendations,
    required this.onProductTap,
    this.onViewAllProducts,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayed = recommendations.take(_maxDisplayed).toList();
    final remainingCount = recommendations.length - displayed.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.lightbulb_outline,
                  color: AppTheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Alternatives moins chères',
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
          recommendations.isNotEmpty
              ? 'Produits équivalents repérés à moindre coût dans d\'autres enseignes'
              : 'Trouvez des alternatives plus économiques dans d\'autres magasins',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppTheme.textMuted,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: AppTheme.glassmorphism(),
          padding: const EdgeInsets.all(14),
          child: recommendations.isEmpty
              ? _buildEmptyState(context)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...displayed.map((item) => _ProductRecommendationCard(
                          item: item,
                          onTap: () => onProductTap(
                            item.referenceProductId,
                            item.referenceProductName,
                          ),
                        )),
                    if (remainingCount > 0 && onViewAllProducts != null)
                      Center(
                        child: TextButton.icon(
                          onPressed: onViewAllProducts,
                          icon: const Icon(Icons.arrow_forward,
                              size: 14, color: AppTheme.primary),
                          label: Text(
                            'Voir les $remainingCount autres recommandations',
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
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lightbulb_outline,
            size: 36,
            color: AppTheme.textMuted.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 8),
          Text(
            'Aucune alternative moins chère trouvée',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Scannez des produits équivalents dans différentes enseignes pour identifier des économies potentielles.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textMuted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte de recommandation d'une alternative moins chère
class _ProductRecommendationCard extends StatelessWidget {
  final ProductRecommendationItem item;
  final VoidCallback onTap;

  const _ProductRecommendationCard({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
              color: AppTheme.primary.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ligne 1 : Catégorie + Badge Économie
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundDark.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.category_outlined,
                          size: 11,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item.category,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.savings_outlined,
                          size: 12,
                          color: AppTheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '-${item.savingAmount.toStringAsFixed(2)} € (-${item.savingPercent.toStringAsFixed(0)}%)',
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

              // Bloc Produit Alternatif (Recommandé)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 16,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Prenez ',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  item.alternativeProductName,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (item.alternativeBrand != null &&
                              item.alternativeBrand!.isNotEmpty)
                            Text(
                              item.alternativeBrand!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppTheme.textMuted,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              if (item.alternativeStore != null) ...[
                                const Icon(
                                  Icons.store,
                                  size: 12,
                                  color: AppTheme.primary,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  item.alternativeStore!,
                                  style: const TextStyle(
                                    color: AppTheme.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Text(
                                '${item.alternativePrice.toStringAsFixed(2)} €',
                                style: const TextStyle(
                                  color: AppTheme.primary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          if (item.comparesByUnit) ...[
                            const SizedBox(height: 2),
                            Text(
                              '${item.alternativeUnitPrice!.format()} au lieu de ${item.referenceUnitPrice!.format()} · économie à quantité égale',
                              style: const TextStyle(
                                color: AppTheme.accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // Bloc Produit de Référence (Au lieu de...)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  children: [
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward,
                      size: 12,
                      color: AppTheme.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Au lieu de ${item.referenceProductName}${item.referenceBrand != null && item.referenceBrand!.isNotEmpty ? " (${item.referenceBrand})" : ""}${item.referenceStore != null ? " chez ${item.referenceStore}" : ""} (${item.referencePrice.toStringAsFixed(2)} €)',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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
            ],
          ),
        ),
      ),
    );
  }
}
