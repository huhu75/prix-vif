// Statistiques globales du tableau de bord
import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../analytics/analytics.dart';

/// Section des statistiques globales
class GlobalStatsSection extends StatelessWidget {
  final DashboardStats stats;

  const GlobalStatsSection({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Statistiques Globales',
          style: theme.textTheme.titleMedium?.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _GlobalStatCard(
                icon: Icons.shopping_bag,
                label: 'Scans',
                value: stats.totalScans.toString(),
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _GlobalStatCard(
                icon: Icons.article,
                label: 'Articles',
                value: stats.totalItems.toString(),
                color: AppTheme.secondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _GlobalStatCard(
                icon: Icons.euro,
                label: 'Total',
                value: stats.totalAmount.toStringAsFixed(2),
                suffix: '€',
                color: AppTheme.accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _GlobalStatCard(
                icon: Icons.trending_up,
                label: 'Moyenne/Article',
                value: stats.averagePrice.toStringAsFixed(2),
                suffix: '€',
                color: AppTheme.accent,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Carte de statistique globale
class _GlobalStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? suffix;
  final Color color;

  const _GlobalStatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.suffix,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      decoration: AppTheme.glassmorphism(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
              if (suffix != null) ...[
                const SizedBox(width: 4),
                Text(
                  suffix!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
