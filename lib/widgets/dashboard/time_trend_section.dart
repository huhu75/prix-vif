// Dépenses par semaine et par mois
import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../analytics/analytics.dart';

class TimeTrendSection extends StatelessWidget {
  final Map<String, PeriodStats> weeklyStats;
  final Map<String, PeriodStats> monthlyStats;

  const TimeTrendSection({
    super.key,
    required this.weeklyStats,
    required this.monthlyStats,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Évolution dans le temps',
          style: theme.textTheme.titleMedium?.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        
        // Graphique hebdomadaire
        Container(
          decoration: AppTheme.glassmorphism(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Par semaine',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 150,
                child: _TrendChart(
                  stats: weeklyStats,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        
        // Graphique mensuel
        Container(
          decoration: AppTheme.glassmorphism(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Par mois',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 150,
                child: _TrendChart(
                  stats: monthlyStats,
                  color: AppTheme.secondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Graphique de tendance simplifié (barres verticales)
class _TrendChart extends StatelessWidget {
  final Map<String, PeriodStats> stats;
  final Color color;

  const _TrendChart({required this.stats, required this.color});

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) {
      return const Center(
        child: Text(
          'Aucune donnée disponible',
          style: TextStyle(color: AppTheme.textMuted),
        ),
      );
    }
    
    // Trouver la valeur maximale pour normaliser
    final maxValue = stats.values
        .map((s) => s.totalAmount)
        .reduce((a, b) => a > b ? a : b);
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: stats.entries.map((entry) {
        final percentage = maxValue > 0 ? (entry.value.totalAmount / maxValue).toDouble() : 0.0;
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              entry.value.totalAmount.toStringAsFixed(1),
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 32,
              height: (100 * percentage.clamp(0, 1)).toDouble(),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              entry.key,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );
      }).toList(),
    );
  }
}
