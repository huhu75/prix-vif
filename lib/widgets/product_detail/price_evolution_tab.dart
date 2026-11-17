// Onglet « Évolution » de la fiche produit : courbes et historique des prix par magasin
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import '../../theme.dart';
import '../../models/product_analysis_models.dart';

// ==========================================
// ONGLET 1 : ÉVOLUTION DES PRIX
// ==========================================

class PriceEvolutionTab extends StatelessWidget {
  final ProductAnalysisResult analysis;

  const PriceEvolutionTab({
    super.key,required this.analysis});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Si un seul magasin, afficher directement son historique
    if (analysis.priceHistoryByStore.length == 1) {
      final storeName = analysis.priceHistoryByStore.keys.first;
      final history = analysis.priceHistoryByStore[storeName]!;
      return _SingleStorePriceHistory(history: history);
    }
    
    // Sinon, proposer de sélectionner un magasin et montrer un graphique combiné
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tendance globale
          _GlobalTrendCard(analysis: analysis),
          const SizedBox(height: 24),
          
          // Graphique combiné de tous les magasins
          Text(
            'Comparatif de l\'évolution des prix',
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _CombinedPriceEvolutionChart(analysis: analysis),
          const SizedBox(height: 24),
          
          // Sélecteur de magasin
          Text(
            'Historique détaillé par magasin',
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          
          ...analysis.priceHistoryByStore.entries.map((entry) {
            final storeName = entry.key;
            final history = entry.value;
            return _StoreSelectionCard(
              storeName: storeName,
              history: history,
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: AppTheme.backgroundDark,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  builder: (context) => DraggableScrollableSheet(
                    initialChildSize: 0.75,
                    minChildSize: 0.5,
                    maxChildSize: 0.95,
                    expand: false,
                    builder: (context, scrollController) => SingleChildScrollView(
                      controller: scrollController,
                      child: _SingleStorePriceHistory(history: history),
                    ),
                  ),
                );
              },
            );
          }),
        ],
      ),
    );
  }
}

class _CombinedPriceEvolutionChart extends StatelessWidget {
  final ProductAnalysisResult analysis;

  const _CombinedPriceEvolutionChart({required this.analysis});

  @override
  Widget build(BuildContext context) {
    // Générer une série de courbes par magasin
    final List<CartesianSeries> seriesList = [];
    final List<Color> lineColors = [
      AppTheme.primary,
      AppTheme.secondary,
      AppTheme.accent,
      Colors.green,
      Colors.orange,
      Colors.pink,
    ];
    
    int colorIdx = 0;

    for (final entry in analysis.priceHistoryByStore.entries) {
      final storeName = entry.key;
      final history = entry.value.sortedByDate();
      final color = lineColors[colorIdx % lineColors.length];
      colorIdx++;

      seriesList.add(
        LineSeries<PricePoint, String>(
          name: storeName,
          dataSource: history.pricePoints,
          xValueMapper: (point, _) => '${point.date.day}/${point.date.month}',
          yValueMapper: (point, _) => point.price,
          color: color,
          width: 2,
          markerSettings: MarkerSettings(
            isVisible: true,
            shape: DataMarkerType.circle,
            borderWidth: 1,
            borderColor: color,
          ),
          dataLabelSettings: const DataLabelSettings(
            isVisible: false,
          ),
        ),
      );
    }

    return Container(
      decoration: AppTheme.glassmorphism(),
      padding: const EdgeInsets.all(16),
      height: 250,
      child: SfCartesianChart(
        legend: Legend(
          isVisible: true,
          position: LegendPosition.bottom,
          textStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
        ),
        primaryXAxis: CategoryAxis(
          labelStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 9),
          axisLine: const AxisLine(color: AppTheme.surfaceLight, width: 1),
          majorGridLines: const MajorGridLines(color: AppTheme.surfaceLight, width: 1),
        ),
        primaryYAxis: NumericAxis(
          labelStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 9),
          axisLine: const AxisLine(color: AppTheme.surfaceLight, width: 1),
          majorGridLines: const MajorGridLines(color: AppTheme.surfaceLight, width: 1),
          numberFormat: NumberFormat.currency(symbol: '€', decimalDigits: 2),
        ),
        series: seriesList,
      ),
    );
  }
}

class _GlobalTrendCard extends StatelessWidget {
  final ProductAnalysisResult analysis;

  const _GlobalTrendCard({required this.analysis});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trend = analysis.overallTrend;
    
    return Container(
      decoration: AppTheme.glassmorphism(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: trend.color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(trend.icon, color: trend.color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tendance globale',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      trend.label,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: trend.color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppTheme.surfaceLight, height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _TrendStatCard(
                label: 'Magasins',
                value: analysis.priceHistoryByStore.length.toString(),
                icon: Icons.store,
              ),
              _TrendStatCard(
                label: 'Prix moyen',
                value: analysis.storeComparison.storePrices.isNotEmpty
                    ? '${analysis.storeComparison.storePrices.values.first.averagePrice.toStringAsFixed(2)} €'
                    : 'N/A',
                icon: Icons.euro,
              ),
              _TrendStatCard(
                label: 'Total scans',
                value: analysis.priceHistoryByStore.values
                    .fold(0, (sum, h) => sum + h.pricePoints.length)
                    .toString(),
                icon: Icons.analytics,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrendStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _TrendStatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.textMuted, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.textMuted,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _SingleStorePriceHistory extends StatelessWidget {
  final ProductPriceHistory history;

  const _SingleStorePriceHistory({required this.history});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sortedHistory = history.sortedByDate();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête avec tendance
          Container(
            decoration: AppTheme.glassmorphism(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: history.trend.color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(history.trend.icon, color: history.trend.color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Magasin : ${history.storeName}',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tendance : ${history.trend.label} (${history.priceEvolutionPercent.toStringAsFixed(1)}%)',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: history.trend.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: AppTheme.surfaceLight),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _PriceStat(
                      label: 'Premier prix',
                      value: history.firstPrice?.toStringAsFixed(2) ?? 'N/A',
                    ),
                    _PriceStat(
                      label: 'Dernier prix',
                      value: history.lastPrice?.toStringAsFixed(2) ?? 'N/A',
                    ),
                    _PriceStat(
                      label: 'Moyenne',
                      value: history.averagePrice.toStringAsFixed(2),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Graphique d'évolution
          if (sortedHistory.pricePoints.length >= 2) ...[
            Text(
              'Évolution du prix dans le temps',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: AppTheme.glassmorphism(),
              padding: const EdgeInsets.all(16),
              height: 300,
              child: SfCartesianChart(
                primaryXAxis: CategoryAxis(
                  labelStyle: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 10,
                  ),
                  axisLine: const AxisLine(
                    color: AppTheme.surfaceLight,
                    width: 1,
                  ),
                  majorGridLines: const MajorGridLines(
                    color: AppTheme.surfaceLight,
                    width: 1,
                  ),
                ),
                primaryYAxis: NumericAxis(
                  labelStyle: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 10,
                  ),
                  axisLine: const AxisLine(
                    color: AppTheme.surfaceLight,
                    width: 1,
                  ),
                  majorGridLines: const MajorGridLines(
                    color: AppTheme.surfaceLight,
                    width: 1,
                  ),
                  numberFormat: NumberFormat.currency(
                    symbol: '€',
                    decimalDigits: 2,
                  ),
                ),
                series: <CartesianSeries>[
                  LineSeries<PricePoint, String>(
                    dataSource: sortedHistory.pricePoints,
                    xValueMapper: (point, _) => 
                        '${point.date.day}/${point.date.month}',
                    yValueMapper: (point, _) => point.price,
                    color: AppTheme.primary,
                    width: 2,
                    markerSettings: const MarkerSettings(
                      isVisible: true,
                      shape: DataMarkerType.circle,
                      borderWidth: 2,
                      borderColor: AppTheme.primary,
                    ),
                    dataLabelSettings: const DataLabelSettings(
                      isVisible: true,
                      labelAlignment: ChartDataLabelAlignment.top,
                      textStyle: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          
          // Tableau des prix
          Text(
            'Historique des prix',
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: AppTheme.glassmorphism(),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // En-tête du tableau
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Date',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        'Prix',
                        textAlign: TextAlign.right,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        'Qté',
                        textAlign: TextAlign.right,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(color: AppTheme.surfaceLight, height: 1),
                const SizedBox(height: 8),
                // Lignes du tableau
                ...sortedHistory.pricePoints.map((point) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${point.date.day}/${point.date.month}/${point.date.year}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          '${point.price.toStringAsFixed(2)} €',
                          textAlign: TextAlign.right,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          point.quantity != null ? '${point.quantity} ${point.unit ?? ''}' : '-',
                          textAlign: TextAlign.right,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceStat extends StatelessWidget {
  final String label;
  final String value;

  const _PriceStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppTheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.textMuted,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _StoreSelectionCard extends StatelessWidget {
  final String storeName;
  final ProductPriceHistory history;
  final VoidCallback onTap;

  const _StoreSelectionCard({
    required this.storeName,
    required this.history,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: AppTheme.glassmorphism(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    storeName,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${history.averagePrice.toStringAsFixed(2)} €',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${history.pricePoints.length} scans',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  history.trend.icon,
                  color: history.trend.color,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  '${history.trend.label} (${history.priceEvolutionPercent.toStringAsFixed(1)}%)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: history.trend.color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
