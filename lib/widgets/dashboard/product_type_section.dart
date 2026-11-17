// Comparaison par type de produit Open Food Facts et par enseigne
import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../analytics/analytics.dart';
import '../../utils/product_type_utils.dart';

class ProductTypeComparisonSection extends StatefulWidget {
  static const int _maxVisibleTypes = 8;

  final Map<String, ProductTypeStats> productTypeStats;
  final double globalAveragePrice;

  const ProductTypeComparisonSection({
    super.key,
    required this.productTypeStats,
    required this.globalAveragePrice,
  });

  @override
  State<ProductTypeComparisonSection> createState() =>
      _ProductTypeComparisonSectionState();
}

class _ProductTypeComparisonSectionState
    extends State<ProductTypeComparisonSection> {
  int _selectedView = 0; // 0 = Par type de produit, 1 = Par enseigne

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Séparer les vrais types OFF des articles non catégorisés
    final uncategorized = widget.productTypeStats[uncategorizedTypeLabel];
    final categorizedEntries = widget.productTypeStats.entries
        .where((e) => e.key != uncategorizedTypeLabel)
        .toList()
      ..sort((a, b) => b.value.totalAmount.compareTo(a.value.totalAmount));

    if (categorizedEntries.isEmpty && uncategorized == null) {
      return const SizedBox.shrink();
    }

    // Calculer les données par enseigne pour la vue comparative
    final storesMap = <String, Map<String, ProductTypeStoreStats>>{};
    for (final entry in widget.productTypeStats.entries) {
      final type = entry.key;
      for (final storeEntry in entry.value.storeStats.entries) {
        final storeName = storeEntry.key;
        storesMap.putIfAbsent(storeName, () => {})[type] = storeEntry.value;
      }
    }
    final hasMultiStores = storesMap.length >= 2;

    final visibleEntries =
        categorizedEntries.take(ProductTypeComparisonSection._maxVisibleTypes).toList();
    final hiddenCount = categorizedEntries.length - visibleEntries.length;
    final maxAverage = visibleEntries.isEmpty
        ? 0.0
        : visibleEntries
            .map((e) => e.value.averagePrice)
            .reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Comparaison par type de produit',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasMultiStores
                        ? 'Prix moyen par type (Open Food Facts) et comparatif inter-magasins'
                        : 'Prix moyen par type (catégories Open Food Facts)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (hasMultiStores) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              _buildViewChip(0, 'Par type de produit', Icons.category_outlined),
              const SizedBox(width: 8),
              _buildViewChip(1, 'Par enseigne', Icons.store),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Container(
          decoration: AppTheme.glassmorphism(),
          padding: const EdgeInsets.all(16),
          child: _selectedView == 0 || !hasMultiStores
              ? Column(
                  children: [
                    ...visibleEntries.map((entry) {
                      final stats = entry.value;
                      final ratio = maxAverage > 0
                          ? (stats.averagePrice / maxAverage).clamp(0.0, 1.0)
                          : 0.0;
                      final color = stats.averagePrice >= widget.globalAveragePrice
                          ? AppTheme.warning
                          : AppTheme.primary;
                      return _ProductTypeBar(
                        type: entry.key,
                        stats: stats,
                        ratio: ratio.toDouble(),
                        color: color,
                      );
                    }),
                    if (hiddenCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '+ $hiddenCount autres types',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.textMuted,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    if (uncategorized != null && uncategorized.itemCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${uncategorized.itemCount} article${uncategorized.itemCount > 1 ? 's' : ''} non catégorisé${uncategorized.itemCount > 1 ? 's' : ''}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.textMuted,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    if (categorizedEntries.isEmpty && uncategorized != null)
                      Text(
                        'Aucun type Open Food Facts disponible pour le moment',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                  ],
                )
              : _buildStoresView(storesMap),
        ),
      ],
    );
  }

  Widget _buildViewChip(int index, String label, IconData icon) {
    final isSelected = _selectedView == index;
    return InkWell(
      onTap: () => setState(() => _selectedView = index),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withValues(alpha: 0.2)
              : AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.surfaceLight,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoresView(
      Map<String, Map<String, ProductTypeStoreStats>> storesMap) {
    final theme = Theme.of(context);
    final sortedStores = storesMap.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sortedStores.map((storeName) {
        final typesMap = storesMap[storeName]!;
        final cheapestTypes = typesMap.entries.where((e) {
          final stats = widget.productTypeStats[e.key];
          return stats != null &&
              stats.storesSortedByAveragePrice.length >= 2 &&
              stats.isCheapestStore(e.value);
        }).map((e) => e.key).toList();

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.surfaceLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.store, size: 16, color: AppTheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        storeName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${typesMap.length} type${typesMap.length > 1 ? 's' : ''}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              if (cheapestTypes.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.emoji_events_outlined,
                        size: 12,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Moins cher sur : ${cheapestTypes.join(', ')}',
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              ...typesMap.entries.map((e) {
                final type = e.key;
                final storeStats = e.value;
                final globalTypeStats = widget.productTypeStats[type];
                final isCheapest = globalTypeStats != null &&
                    globalTypeStats.isCheapestStore(storeStats);

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        type,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      Row(
                        children: [
                          if (isCheapest &&
                              globalTypeStats.storesSortedByAveragePrice.length >= 2) ...[
                            const Icon(
                              Icons.check,
                              size: 12,
                              color: AppTheme.primary,
                            ),
                            const SizedBox(width: 3),
                          ],
                          Text(
                            globalTypeStats?.formatStorePrice(storeStats) ??
                                '${storeStats.averagePrice.toStringAsFixed(2)} €/art',
                            style: TextStyle(
                              color: isCheapest
                                  ? AppTheme.primary
                                  : AppTheme.textPrimary,
                              fontSize: 12,
                              fontWeight: isCheapest
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// Ligne de comparaison pour un type de produit
class _ProductTypeBar extends StatelessWidget {
  final String type;
  final ProductTypeStats stats;
  final double ratio;
  final Color color;

  const _ProductTypeBar({
    required this.type,
    required this.stats,
    required this.ratio,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sortedStores = stats.storesSortedByAveragePrice;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  type,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${stats.averagePrice.toStringAsFixed(2)} €/article',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${stats.itemCount} article${stats.itemCount > 1 ? 's' : ''} · total ${stats.totalAmount.toStringAsFixed(2)} € · ${stats.minPrice.toStringAsFixed(2)}–${stats.maxPrice.toStringAsFixed(2)} €',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
              fontSize: 11,
            ),
          ),
          if (stats.averageUnitPrice != null) ...[
            const SizedBox(height: 2),
            Text(
              'Moyenne ${stats.averageUnitPrice!.format()} · ${stats.unitPricedCount}/${stats.itemCount} article${stats.itemCount > 1 ? 's' : ''} de contenance connue',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.accent,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Container(
            height: 20,
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.7 * ratio,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          if (sortedStores.length >= 2) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.backgroundDark.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.store,
                              size: 12, color: AppTheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            'Comparatif enseignes (${sortedStores.length})',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      if (stats.storePriceSpread > 0.01)
                        Text(
                          'Écart : ${stats.storePriceSpread.toStringAsFixed(2)} ${stats.spreadLabel}',
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: sortedStores.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final store = entry.value;
                      final isCheapest = idx == 0;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isCheapest
                              ? AppTheme.primary.withValues(alpha: 0.16)
                              : AppTheme.surfaceDark,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isCheapest
                                ? AppTheme.primary.withValues(alpha: 0.5)
                                : AppTheme.surfaceLight,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isCheapest) ...[
                              const Icon(
                                Icons.emoji_events_outlined,
                                size: 11,
                                color: AppTheme.primary,
                              ),
                              const SizedBox(width: 3),
                            ],
                            Text(
                              '${store.storeName} : ${stats.formatStorePrice(store)}',
                              style: TextStyle(
                                color: isCheapest
                                    ? AppTheme.primary
                                    : AppTheme.textSecondary,
                                fontSize: 11,
                                fontWeight: isCheapest
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
