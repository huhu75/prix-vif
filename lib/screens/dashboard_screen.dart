import 'package:flutter/material.dart';
import '../theme.dart';
import '../models.dart';
import '../models/product_analysis_models.dart';
import '../analytics/analytics.dart';
import '../services/scan_repository.dart';
import '../utils/product_type_utils.dart';
import '../widgets/dashboard/price_alerts_section.dart';
import '../widgets/dashboard/shopping_basket_section.dart';
import '../widgets/magic_title.dart';
import 'product_detail_screen.dart';

/// Écran de tableau de bord avec analyse nutritionnelle et tendances
class DashboardScreen extends StatelessWidget {
  final List<ScanSession> sessions;
  final Function(ScanSession) onSessionSelected;
  final VoidCallback? onProductAnalysisRequested;
  final void Function(String productId, String productName, {int initialTabIndex})? onProductSelected;
  final ScanRepository? repository;

  const DashboardScreen({
    super.key,
    required this.sessions,
    required this.onSessionSelected,
    this.onProductAnalysisRequested,
    this.onProductSelected,
    this.repository,
  });

  @override
  Widget build(BuildContext context) {
    // Calculer les statistiques globales
    final stats = DashboardStats.fromSessions(sessions);
    
    return Scaffold(
      key: const ValueKey('dashboard_scaffold'),
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const NeonTitle(text: 'TABLEAU DE BORD', fontSize: 20),
        actions: [
          if (onProductAnalysisRequested != null)
            IconButton(
              icon: const Icon(Icons.analytics, color: AppTheme.textPrimary),
              tooltip: 'Analyser un produit',
              onPressed: onProductAnalysisRequested,
            ),
        ],
      ),
      body: sessions.isEmpty
          ? _EmptyDashboardState()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bouton d'analyse par produit
                  if (onProductAnalysisRequested != null)
                    _ProductAnalysisButton(
                      onPressed: onProductAnalysisRequested!,
                    ),
                  const SizedBox(height: 24),
                  // Statistiques globales
                  _GlobalStatsSection(stats: stats),
                  const SizedBox(height: 24),

                  // Où faire mes courses ? (panier habituel par magasin)
                  ShoppingBasketSection(analysis: stats.shoppingBasket),
                  const SizedBox(height: 24),

                  // Alertes de hausse de prix
                  PriceAlertsSection(
                    sessions: sessions,
                    repository: repository,
                    onProductTap: (productId, productName) => _handleProductTap(
                      context,
                      productId,
                      productName,
                      initialTabIndex: 1,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Évolution des prix des produits
                  _ProductPriceEvolutionSection(
                    evolutions: stats.productEvolutions,
                    onProductTap: (productId, productName) => _handleProductTap(
                      context,
                      productId,
                      productName,
                      initialTabIndex: 1,
                    ),
                    onViewAllProducts: onProductAnalysisRequested,
                  ),
                  const SizedBox(height: 24),

                  // Comparateur multi-magasins
                  _ProductStoreComparisonSection(
                    comparisons: stats.storeComparisons,
                    onProductTap: (productId, productName) => _handleProductTap(
                      context,
                      productId,
                      productName,
                      initialTabIndex: 2,
                    ),
                    onViewAllProducts: onProductAnalysisRequested,
                  ),
                  const SizedBox(height: 24),

                  // Alternatives moins chères (Recommandations d'économies)
                  _ProductRecommendationSection(
                    recommendations: stats.recommendations,
                    onProductTap: (productId, productName) => _handleProductTap(
                      context,
                      productId,
                      productName,
                      initialTabIndex: 3,
                    ),
                    onViewAllProducts: onProductAnalysisRequested,
                  ),
                  const SizedBox(height: 24),
                  
                  // Comparaison par type de produit (Open Food Facts)
                  _ProductTypeComparisonSection(
                    productTypeStats: stats.productTypeStats,
                    globalAveragePrice: stats.averagePrice,
                  ),
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

  void _handleProductTap(
    BuildContext context,
    String productId,
    String productName, {
    int initialTabIndex = 0,
  }) {
    if (onProductSelected != null) {
      onProductSelected!(productId, productName, initialTabIndex: initialTabIndex);
    } else if (repository != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ProductDetailScreen(
            repository: repository!,
            productId: productId,
            productName: productName,
            initialTabIndex: initialTabIndex,
          ),
        ),
      );
    } else if (onProductAnalysisRequested != null) {
      onProductAnalysisRequested!();
    }
  }
}

// ==================== SECTIONS ====================

/// Section des statistiques globales
class _GlobalStatsSection extends StatelessWidget {
  final DashboardStats stats;

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

// ==================== ÉVOLUTION DES PRIX DES PRODUITS ====================

/// Section affichant l'évolution des prix des produits scannés
class _ProductPriceEvolutionSection extends StatelessWidget {
  static const int _maxDisplayed = 5;

  final List<ProductPriceEvolutionItem> evolutions;
  final void Function(String productId, String productName) onProductTap;
  final VoidCallback? onViewAllProducts;

  const _ProductPriceEvolutionSection({
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

// ==================== COMPARATEUR MULTI-MAGASINS ====================

/// Section comparateur multi-magasins sur le tableau de bord
class _ProductStoreComparisonSection extends StatelessWidget {
  static const int _maxDisplayed = 5;

  final List<ProductStoreComparisonItem> comparisons;
  final void Function(String productId, String productName) onProductTap;
  final VoidCallback? onViewAllProducts;

  const _ProductStoreComparisonSection({
    required this.comparisons,
    required this.onProductTap,
    this.onViewAllProducts,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayed = comparisons.take(_maxDisplayed).toList();
    final remainingCount = comparisons.length - displayed.length;

    return Column(
      key: const ValueKey('store_comparison_section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.store,
                  color: AppTheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Comparateur multi-magasins',
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
          comparisons.isNotEmpty
              ? 'Écarts de prix constatés pour un même produit selon l\'enseigne'
              : 'Comparez les prix d\'un même article entre vos magasins habituels',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppTheme.textMuted,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: AppTheme.glassmorphism(),
          padding: const EdgeInsets.all(14),
          child: comparisons.isEmpty
              ? _buildEmptyState(context)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...displayed.map((item) => _ProductStoreComparisonCard(
                          item: item,
                          onTap: () => onProductTap(item.productId, item.name),
                        )),
                    if (remainingCount > 0 && onViewAllProducts != null)
                      Center(
                        child: TextButton.icon(
                          onPressed: onViewAllProducts,
                          icon: const Icon(Icons.arrow_forward, size: 14, color: AppTheme.primary),
                          label: Text(
                            'Voir les $remainingCount autres comparaisons',
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.storefront_outlined,
            color: AppTheme.primary,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Scannez dans plusieurs enseignes',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Dès qu\'un même produit sera scanné dans deux magasins différents, le meilleur prix et l\'économie réalisable apparaîtront ici automatiquement.',
                style: TextStyle(
                  color: AppTheme.textSecondary.withValues(alpha: 0.8),
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Carte comparative d'un produit entre magasins
class _ProductStoreComparisonCard extends StatelessWidget {
  final ProductStoreComparisonItem item;
  final VoidCallback onTap;

  const _ProductStoreComparisonCard({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasDiff = item.hasPriceDifference;

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
              color: hasDiff
                  ? AppTheme.primary.withValues(alpha: 0.3)
                  : AppTheme.surfaceLight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ligne 1 : Nom du produit + Badge d'économie
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                        if (item.brand != null && item.brand!.isNotEmpty)
                          Text(
                            item.brand!,
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
                  if (hasDiff)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.savings_outlined, size: 12, color: AppTheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            '-${item.priceDiff.toStringAsFixed(2)} € (-${item.savingPercent.toStringAsFixed(0)}%)',
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
              // Ligne 2 : Comparatif des magasins
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundDark.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    // Moins cher
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.emoji_events, size: 14, color: AppTheme.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.cheapestStore,
                                  style: const TextStyle(
                                    color: AppTheme.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${item.cheapestPrice.toStringAsFixed(2)} €',
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasDiff) ...[
                      Container(
                        height: 24,
                        width: 1,
                        color: AppTheme.surfaceLight,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      // Plus cher
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.mostExpensiveStore,
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${item.mostExpensivePrice.toStringAsFixed(2)} €',
                              style: TextStyle(
                                color: AppTheme.textSecondary.withValues(alpha: 0.8),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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

// ==================== ALTERNATIVES MOINS CHÈRES ====================

/// Section des recommandations de produits alternatifs moins chers
class _ProductRecommendationSection extends StatelessWidget {
  static const int _maxDisplayed = 3;

  final List<ProductRecommendationItem> recommendations;
  final void Function(String productId, String productName) onProductTap;
  final VoidCallback? onViewAllProducts;

  const _ProductRecommendationSection({
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

// ==================== COMPARAISON PAR TYPE DE PRODUIT ====================

class _ProductTypeComparisonSection extends StatefulWidget {
  static const int _maxVisibleTypes = 8;

  final Map<String, ProductTypeStats> productTypeStats;
  final double globalAveragePrice;

  const _ProductTypeComparisonSection({
    required this.productTypeStats,
    required this.globalAveragePrice,
  });

  @override
  State<_ProductTypeComparisonSection> createState() =>
      _ProductTypeComparisonSectionState();
}

class _ProductTypeComparisonSectionState
    extends State<_ProductTypeComparisonSection> {
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
        categorizedEntries.take(_ProductTypeComparisonSection._maxVisibleTypes).toList();
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

// ==================== TENDANCES TEMPORELLES ====================

class _TimeTrendSection extends StatelessWidget {
  final Map<String, PeriodStats> weeklyStats;
  final Map<String, PeriodStats> monthlyStats;

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

// ==================== BOUTON ANALYSE PAR PRODUIT ====================

class _ProductAnalysisButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _ProductAnalysisButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primary.withValues(alpha: 0.3),
              AppTheme.primary.withValues(alpha: 0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.search,
              color: AppTheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Analyser un produit',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Voir l\'évolution des prix, comparer les magasins',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward,
            color: AppTheme.primary,
            size: 20,
          ),
        ],
      ),
    ),
  );
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
              color: AppTheme.primary.withValues(alpha: 0.1),
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
