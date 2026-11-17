// Onglet « Magasins » de la fiche produit : prix du produit dans chaque magasin
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import '../../theme.dart';
import '../../models/product_analysis_models.dart';

// ==========================================
// ONGLET 2 : COMPARAISON PAR MAGASIN
// ==========================================

class StoreComparisonTab extends StatelessWidget {
  final ProductAnalysisResult analysis;
  final Function(String) onStoreDeleted;

  const StoreComparisonTab({
    super.key,
    required this.analysis,
    required this.onStoreDeleted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cheapest = analysis.storeComparison.cheapestStore;
    final stores = analysis.storeComparison.storePrices;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Magasin le moins cher (mise en évidence) - seulement si magasins existants
          if (cheapest != null && stores.isNotEmpty) ...[
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.green.withValues(alpha: 0.3),
                    Colors.green.withValues(alpha: 0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
              ),
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.emoji_events,
                      color: Colors.green,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Magasin le moins cher',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          cheapest.storeName,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.green,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${cheapest.lastPrice.toStringAsFixed(2)} €',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: Colors.green,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${cheapest.scanCount} scan${cheapest.scanCount > 1 ? 's' : ''}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Graphique comparatif
          if (stores.length > 1) ...[
            Text(
              'Comparatif des prix actuels',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _StorePriceBarChart(comparison: analysis.storeComparison),
            const SizedBox(height: 24),
          ],
          
          // Liste de tous les magasins
          Text(
            'Tous les magasins',
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          
          // Afficher un message si pas de magasin
          if (stores.isEmpty) ...[
            Container(
              decoration: AppTheme.glassmorphism(),
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'Aucun magasin défini pour ce produit',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textMuted,
                  ),
                ),
              ),
            ),
          ] else ...[
            ...stores.entries.map((entry) {
              final storeInfo = entry.value;
              final isCheapest = storeInfo.storeName == cheapest?.storeName;
              return _StorePriceCard(
                key: ValueKey('store_${entry.key}'),
                storeInfo: storeInfo,
                isCheapest: isCheapest,
                onDelete: () => onStoreDeleted(storeInfo.storeName),
              );
            }),
          ],
          
          // Résumé - seulement si au moins 2 magasins
          if (stores.length > 1) ...[
            const SizedBox(height: 24),
            Container(
              decoration: AppTheme.glassmorphism(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Résumé',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: AppTheme.surfaceLight),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Écart de prix :',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      Text(
                        _calculatePriceRange(analysis.storeComparison),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _calculatePriceRange(StorePriceComparison comparison) {
    if (comparison.storePrices.isEmpty) return 'N/A';
    
    final prices = comparison.storePrices.values.map((s) => s.lastPrice).toList();
    final minPrice = prices.reduce((a, b) => a < b ? a : b);
    final maxPrice = prices.reduce((a, b) => a > b ? a : b);
    final diff = maxPrice - minPrice;
    final diffPercent = (diff / minPrice) * 100;
    
    return '${minPrice.toStringAsFixed(2)} - ${maxPrice.toStringAsFixed(2)} € (${diffPercent.toStringAsFixed(1)}%)';
  }
}

class _StorePriceBarChart extends StatelessWidget {
  final StorePriceComparison comparison;

  const _StorePriceBarChart({required this.comparison});

  @override
  Widget build(BuildContext context) {
    final stores = comparison.storesSortedByPrice;
    if (stores.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: AppTheme.glassmorphism(),
      padding: const EdgeInsets.all(16),
      height: 60.0 + (stores.length * 45.0), // Hauteur dynamique
      child: SfCartesianChart(
        primaryXAxis: CategoryAxis(
          labelStyle: const TextStyle(color: AppTheme.textPrimary, fontSize: 10, fontWeight: FontWeight.bold),
          axisLine: const AxisLine(width: 0),
          majorGridLines: const MajorGridLines(width: 0),
        ),
        primaryYAxis: NumericAxis(
          labelStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 9),
          axisLine: const AxisLine(color: AppTheme.surfaceLight, width: 1),
          majorGridLines: const MajorGridLines(color: AppTheme.surfaceLight, width: 1),
          numberFormat: NumberFormat.currency(symbol: '€', decimalDigits: 2),
        ),
        series: <CartesianSeries>[
          BarSeries<StorePriceInfo, String>(
            dataSource: stores,
            xValueMapper: (info, _) => info.storeName,
            yValueMapper: (info, _) => info.lastPrice,
            pointColorMapper: (info, _) {
              // Mettre en vert le moins cher
              return info.storeName == comparison.cheapestStore?.storeName
                  ? Colors.green.withValues(alpha: 0.8)
                  : AppTheme.primary.withValues(alpha: 0.8);
            },
            dataLabelSettings: const DataLabelSettings(
              isVisible: true,
              textStyle: TextStyle(color: AppTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.bold),
              labelAlignment: ChartDataLabelAlignment.outer,
            ),
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
          )
        ],
      ),
    );
  }
}

class _StorePriceCard extends StatelessWidget {
  final StorePriceInfo storeInfo;
  final bool isCheapest;
  final VoidCallback? onDelete;

  const _StorePriceCard({
    super.key,
    required this.storeInfo,
    this.isCheapest = false,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: isCheapest 
            ? Border.all(color: Colors.green, width: 2)
            : Border.all(color: AppTheme.surfaceLight, width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  storeInfo.storeName,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Dernier scan : ${_formatDate(storeInfo.lastScanDate)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Prix
              Text(
                '${storeInfo.lastPrice.toStringAsFixed(2)} €',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: isCheapest ? Colors.green : AppTheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 4),
              // Prix moyen
              Text(
                'Moy. : ${storeInfo.averagePrice.toStringAsFixed(2)} €',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              // Nombre de scans
              Text(
                '${storeInfo.scanCount} scan${storeInfo.scanCount > 1 ? 's' : ''}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          // Bouton de suppression
          if (onDelete != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_forever, size: 18),
              color: Colors.red.withValues(alpha: 0.7),
              tooltip: 'Supprimer ce magasin',
              onPressed: onDelete,
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays == 0) return 'Aujourd\'hui';
    if (diff.inDays == 1) return 'Hier';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays}j';
    return '${date.day}/${date.month}/${date.year}';
  }
}
