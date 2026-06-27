import 'package:flutter/material.dart';
import '../theme.dart';
import '../models.dart';
import '../widgets/magic_title.dart';
import 'package:intl/intl.dart';

/// Écran de tableau de bord avec analyse nutritionnelle et tendances
class DashboardScreen extends StatelessWidget {
  final List<ScanSession> sessions;
  final Function(ScanSession) onSessionSelected;

  const DashboardScreen({
    super.key,
    required this.sessions,
    required this.onSessionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Debug: afficher le nombre de sessions
    print('DEBUG Dashboard: sessions.length = ${sessions.length}');
    print('DEBUG Dashboard: sessions.isEmpty = ${sessions.isEmpty}');
    
    // Calculer les statistiques globales
    final stats = _calculateDashboardStats(sessions);
    
    return Scaffold(
      key: const ValueKey('dashboard_scaffold'),
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const NeonTitle(text: 'TABLEAU DE BORD', fontSize: 20),
      ),
      body: sessions.isEmpty
          ? _EmptyDashboardState()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Statistiques globales
                  _GlobalStatsSection(stats: stats),
                  const SizedBox(height: 24),
                  
                  // Répartition Nutri-Score
                  _NutriScoreDistributionSection(
                    sessions: sessions,
                    distribution: stats.nutriScoreDistribution,
                  ),
                  const SizedBox(height: 24),
                  
                  // Évolution temporelle
                  _TimeTrendSection(
                    weeklyStats: stats.weeklyStats,
                    monthlyStats: stats.monthlyStats,
                  ),
                  const SizedBox(height: 24),
                  
                  // Totaux par période
                  _PeriodTotalsSection(
                    weeklyTotal: stats.weeklyTotal,
                    monthlyTotal: stats.monthlyTotal,
                  ),
                  const SizedBox(height: 24),
                  
                  // Derniers scans
                  _RecentScansSection(
                    sessions: sessions,
                    onSessionSelected: onSessionSelected,
                  ),
                ],
              ),
            ),
    );
  }

  /// Calcule toutes les statistiques pour le tableau de bord
  _DashboardStats _calculateDashboardStats(List<ScanSession> sessions) {
    final allItems = <ScannedItem>[];
    for (final session in sessions) {
      allItems.addAll(session.items);
    }
    
    // Calculer la répartition Nutri-Score
    final nutriscoreCounts = <String, int>{};
    for (final item in allItems) {
      if (item.nutriscore != null) {
        final score = item.nutriscore!.toLowerCase();
        nutriscoreCounts[score] = (nutriscoreCounts[score] ?? 0) + 1;
      }
    }
    
    // Calculer les statistiques par semaine
    final weeklyStats = _calculateWeeklyStats(sessions);
    
    // Calculer les statistiques par mois
    final monthlyStats = _calculateMonthlyStats(sessions);
    
    // Calculer les totaux
    final totalAmount = allItems.fold(0.0, (sum, item) => sum + item.price);
    final totalItems = allItems.length;
    final avgPrice = totalItems > 0 ? totalAmount / totalItems : 0.0;
    
    // Calculer les totaux par période
    final now = DateTime.now();
    final weeklyTotal = _calculatePeriodTotal(sessions, now, 7);
    final monthlyTotal = _calculatePeriodTotal(sessions, now, 30);
    
    return _DashboardStats(
      totalScans: sessions.length,
      totalItems: totalItems,
      totalAmount: totalAmount,
      averagePrice: avgPrice,
      nutriScoreDistribution: nutriscoreCounts,
      weeklyStats: weeklyStats,
      monthlyStats: monthlyStats,
      weeklyTotal: weeklyTotal,
      monthlyTotal: monthlyTotal,
    );
  }

  Map<String, _PeriodStats> _calculateWeeklyStats(List<ScanSession> sessions) {
    final weeklyStats = <String, _PeriodStats>{};
    
    for (final session in sessions) {
      final weekKey = _formatWeekKey(session.date);
      if (!weeklyStats.containsKey(weekKey)) {
        weeklyStats[weekKey] = _PeriodStats(scanCount: 0, itemCount: 0, totalAmount: 0.0);
      }
      
      weeklyStats[weekKey]!.scanCount += 1;
      weeklyStats[weekKey]!.itemCount += session.items.length;
      weeklyStats[weekKey]!.totalAmount += session.totalAmount;
    }
    
    return weeklyStats;
  }

  Map<String, _PeriodStats> _calculateMonthlyStats(List<ScanSession> sessions) {
    final monthlyStats = <String, _PeriodStats>{};
    
    for (final session in sessions) {
      final monthKey = _formatMonthKey(session.date);
      if (!monthlyStats.containsKey(monthKey)) {
        monthlyStats[monthKey] = _PeriodStats(scanCount: 0, itemCount: 0, totalAmount: 0.0);
      }
      
      monthlyStats[monthKey]!.scanCount += 1;
      monthlyStats[monthKey]!.itemCount += session.items.length;
      monthlyStats[monthKey]!.totalAmount += session.totalAmount;
    }
    
    return monthlyStats;
  }

  double _calculatePeriodTotal(List<ScanSession> sessions, DateTime now, int days) {
    final cutoff = now.subtract(Duration(days: days));
    double total = 0.0;
    
    for (final session in sessions) {
      if (session.date.isAfter(cutoff) || session.date.isAtSameMomentAs(cutoff)) {
        total += session.totalAmount;
      }
    }
    
    return total;
  }

  String _formatWeekKey(DateTime date) {
    final startOfWeek = date.subtract(Duration(days: date.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    final formatter = DateFormat('dd MMM', 'fr_FR');
    return '${formatter.format(startOfWeek)} - ${formatter.format(endOfWeek)}';
  }

  String _formatMonthKey(DateTime date) {
    final formatter = DateFormat('MMM yyyy', 'fr_FR');
    return formatter.format(date);
  }
}

/// Statistiques pour le tableau de bord
class _DashboardStats {
  final int totalScans;
  final int totalItems;
  final double totalAmount;
  final double averagePrice;
  final Map<String, int> nutriScoreDistribution;
  final Map<String, _PeriodStats> weeklyStats;
  final Map<String, _PeriodStats> monthlyStats;
  final double weeklyTotal;
  final double monthlyTotal;

  _DashboardStats({
    required this.totalScans,
    required this.totalItems,
    required this.totalAmount,
    required this.averagePrice,
    required this.nutriScoreDistribution,
    required this.weeklyStats,
    required this.monthlyStats,
    required this.weeklyTotal,
    required this.monthlyTotal,
  });
}

/// Statistiques pour une période
class _PeriodStats {
  int scanCount;
  int itemCount;
  double totalAmount;

  _PeriodStats({
    required this.scanCount,
    required this.itemCount,
    required this.totalAmount,
  });
}

// ==================== SECTIONS ====================

/// Section des statistiques globales
class _GlobalStatsSection extends StatelessWidget {
  final _DashboardStats stats;

  const _GlobalStatsSection({required this.stats});

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
                  color: color.withOpacity(0.15),
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

// ==================== RÉPARTITION NUTRI-SCORE ====================

class _NutriScoreDistributionSection extends StatelessWidget {
  final List<ScanSession> sessions;
  final Map<String, int> distribution;

  const _NutriScoreDistributionSection({
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
              }).toList(),
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

// ==================== TENDANCES TEMPORELLES ====================

class _TimeTrendSection extends StatelessWidget {
  final Map<String, _PeriodStats> weeklyStats;
  final Map<String, _PeriodStats> monthlyStats;

  const _TimeTrendSection({
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
  final Map<String, _PeriodStats> stats;
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
                color: color.withOpacity(0.8),
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

// ==================== TOTAUX PAR PÉRIODE ====================

class _PeriodTotalsSection extends StatelessWidget {
  final double weeklyTotal;
  final double monthlyTotal;

  const _PeriodTotalsSection({
    required this.weeklyTotal,
    required this.monthlyTotal,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Totaux par période',
          style: theme.textTheme.titleMedium?.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _PeriodTotalCard(
                period: 'Semaine',
                amount: weeklyTotal,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PeriodTotalCard(
                period: 'Mois',
                amount: monthlyTotal,
                color: AppTheme.secondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Carte de total par période
class _PeriodTotalCard extends StatelessWidget {
  final String period;
  final double amount;
  final Color color;

  const _PeriodTotalCard({
    required this.period,
    required this.amount,
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
          Text(
            period,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                amount.toStringAsFixed(2),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 24,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                '€',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ==================== DERNIERS SCANS ====================

class _RecentScansSection extends StatelessWidget {
  final List<ScanSession> sessions;
  final Function(ScanSession) onSessionSelected;

  const _RecentScansSection({
    required this.sessions,
    required this.onSessionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recentSessions = sessions.take(3).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Derniers scans',
          style: theme.textTheme.titleMedium?.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        ...recentSessions.map((session) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _RecentSessionCard(
            session: session,
            onTap: () => onSessionSelected(session),
          ),
        )).toList(),
        
        if (sessions.length > 3)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '+ ${sessions.length - 3} autres scans',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.textMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }
}

/// Carte de scan récent
class _RecentSessionCard extends StatelessWidget {
  final ScanSession session;
  final VoidCallback onTap;

  const _RecentSessionCard({
    required this.session,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stores = session.items.map((i) => i.storeName).toSet();
    final storeLabel = stores.isEmpty ? '-' : stores.join(', ');
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: AppTheme.glassmorphism(),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                session.type == 'ticket' ? Icons.receipt_long : Icons.qr_code_scanner,
                color: session.type == 'ticket' ? AppTheme.secondary : AppTheme.accent,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatDate(session.date),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    storeLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${session.items.length} articles',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  session.totalAmount.toStringAsFixed(2),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Aujourd\'hui';
    } else if (difference.inDays == 1) {
      return 'Hier';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays}j';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

// ==================== ÉTAT VIDE ====================

class _EmptyDashboardState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.analytics,
              color: AppTheme.primary,
              size: 40,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Aucune donnée',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Scannez vos premiers produits pour voir vos statistiques',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
