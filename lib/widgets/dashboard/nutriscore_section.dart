// Répartition Nutri-Score des achats
import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../models.dart';

class NutriScoreDistributionSection extends StatelessWidget {
  final List<ScanSession> sessions;
  final Map<String, int> distribution;

  const NutriScoreDistributionSection({
    super.key,
    required this.sessions,
    required this.distribution,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalItems = sessions.fold(0, (sum, session) => sum + session.items.length);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Répartition Nutri-Score',
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
              // Légende des scores
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NutriScoreLegendItem(score: 'A', color: const Color(0xFF038141)),
                  _NutriScoreLegendItem(score: 'B', color: const Color(0xFF85BB2F)),
                  _NutriScoreLegendItem(score: 'C', color: const Color(0xFFFECB02)),
                  _NutriScoreLegendItem(score: 'D', color: const Color(0xFFEE8100)),
                  _NutriScoreLegendItem(score: 'E', color: const Color(0xFFE63E11)),
                ],
              ),
              const SizedBox(height: 16),
              
              // Graphique à barres horizontales
              ...['a', 'b', 'c', 'd', 'e'].map((score) {
                final count = distribution[score] ?? 0;
                final percentage = totalItems > 0 ? (count / totalItems * 100).toDouble() : 0.0;
                return _NutriScoreBar(
                  score: score.toUpperCase(),
                  count: count,
                  percentage: percentage,
                  color: _getNutriScoreColor(score),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Color _getNutriScoreColor(String score) {
    switch (score) {
      case 'a': return const Color(0xFF038141);
      case 'b': return const Color(0xFF85BB2F);
      case 'c': return const Color(0xFFFECB02);
      case 'd': return const Color(0xFFEE8100);
      case 'e': return const Color(0xFFE63E11);
      default: return AppTheme.textMuted;
    }
  }
}

/// Élément de légende pour Nutri-Score
class _NutriScoreLegendItem extends StatelessWidget {
  final String score;
  final Color color;

  const _NutriScoreLegendItem({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Text(
              score,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          score,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.textSecondary,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

/// Barre de progression pour Nutri-Score
class _NutriScoreBar extends StatelessWidget {
  final String score;
  final int count;
  final double percentage;
  final Color color;

  const _NutriScoreBar({
    required this.score,
    required this.count,
    required this.percentage,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                score,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$count articles (${percentage.toStringAsFixed(1)}%)',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: 24,
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.7 * (percentage / 100),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
