// Onglet « Magasins » de la fiche produit : prix du produit dans chaque magasin
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import '../../analytics/analytics.dart';
import '../../theme.dart';
import '../../models/product_analysis_models.dart';
import '../price_advice_card.dart';

// ==========================================
// ONGLET 2 : COMPARAISON PAR MAGASIN
// ==========================================

class StoreComparisonTab extends StatelessWidget {
  final ProductAnalysisResult analysis;

  /// Ouvre la feuille d'un magasin (changer, renommer, corriger le prix, retirer)
  final void Function(String storeName)? onStoreEdit;

  /// Ajoute un prix relevé dans un magasin, sans scanner
  final VoidCallback? onAddPrice;

  /// Conseil d'achat dans chaque magasin (recommandé / trop cher)
  final Map<String, PriceAdvice> adviceByStore;

  const StoreComparisonTab({
    super.key,
    required this.analysis,
    this.onStoreEdit,
    this.onAddPrice,
    this.adviceByStore = const {},
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cheapest = analysis.storeComparison.cheapestStore;
    final stores = analysis.storeComparison.storePrices;
    final bestAdvice = cheapest == null ? null : adviceByStore[cheapest.storeName];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Où l'acheter : magasin recommandé et équivalent moins cher de la catégorie
          if (bestAdvice != null) ...[
            PriceAdviceCard(
              key: const ValueKey('where_to_buy'),
              advice: bestAdvice,
              title: bestAdvice.verdict == AdviceVerdict.recommended
                  ? 'Où l\'acheter : ${bestAdvice.store}'
                  : 'Vu seulement chez ${bestAdvice.store}',
            ),
            const SizedBox(height: 16),
          ],
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
          if (onStoreEdit != null && stores.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'Touche un magasin pour le changer, le renommer ou corriger son prix',
              style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
            ),
          ],
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
                advice: adviceByStore[entry.key],
                onEdit: onStoreEdit != null ? () => onStoreEdit!(storeInfo.storeName) : null,
              );
            }),
          ],

          // Prix vu dans un autre magasin, sans scanner
          if (onAddPrice != null) ...[
            const SizedBox(height: 4),
            OutlinedButton.icon(
              key: const ValueKey('add_store_price'),
              onPressed: onAddPrice,
              icon: const Icon(Icons.add_business_outlined),
              label: const Text('Ajouter un prix dans un magasin'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.5)),
                minimumSize: const Size.fromHeight(44),
              ),
            ),
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

  /// Toucher la carte ouvre la feuille du magasin
  final VoidCallback? onEdit;

  /// Conseil d'achat dans ce magasin
  final PriceAdvice? advice;

  const _StorePriceCard({
    super.key,
    required this.storeInfo,
    this.isCheapest = false,
    this.onEdit,
    this.advice,
  });

  /// « Recommandé » / « Trop cher : 0.14 € de moins chez Leclerc »
  Widget? _verdict(ThemeData theme) {
    final advice = this.advice;
    if (advice == null) return null;
    final (color, icon, text) = switch (advice.verdict) {
      AdviceVerdict.recommended => (AppTheme.success, Icons.thumb_up_alt_outlined, 'Recommandé'),
      AdviceVerdict.discouraged => (
          AppTheme.error,
          Icons.thumb_down_alt_outlined,
          'Trop cher : ${advice.savingElsewhere!.toStringAsFixed(2)} € de moins chez ${advice.cheaperElsewhere!.storeName}',
        ),
      AdviceVerdict.unknown => (AppTheme.textMuted, Icons.info_outline, 'Pas encore comparé'),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isCheapest
              ? const BorderSide(color: Colors.green, width: 2)
              : const BorderSide(color: AppTheme.surfaceLight, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('store_card_${storeInfo.storeName}'),
          onTap: onEdit,
          child: Padding(
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
                      ?_verdict(theme),
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
                // Repère « modifiable » : la carte entière ouvre la feuille du magasin
                if (onEdit != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    key: ValueKey('edit_store_btn_${storeInfo.storeName}'),
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    color: AppTheme.accent,
                    tooltip: 'Modifier ce magasin',
                    onPressed: onEdit,
                  ),
                ],
              ],
            ),
          ),
        ),
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
