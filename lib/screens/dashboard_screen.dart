import 'package:flutter/material.dart';
import '../theme.dart';
import '../models.dart';
import '../analytics/analytics.dart';
import '../services/scan_repository.dart';
import '../widgets/dashboard/empty_dashboard_state.dart';
import '../widgets/dashboard/global_stats_section.dart';
import '../widgets/dashboard/nutriscore_section.dart';
import '../widgets/dashboard/period_totals_section.dart';
import '../widgets/dashboard/price_alerts_section.dart';
import '../widgets/dashboard/price_evolution_section.dart';
import '../widgets/dashboard/product_analysis_button.dart';
import '../widgets/dashboard/product_type_section.dart';
import '../widgets/dashboard/recent_scans_section.dart';
import '../widgets/dashboard/recommendations_section.dart';
import '../widgets/dashboard/store_comparison_section.dart';
import '../widgets/dashboard/time_trend_section.dart';
import '../widgets/dashboard/shopping_basket_section.dart';
import '../widgets/magic_title.dart';
import '../widgets/nav_buttons.dart';
import 'product_detail_screen.dart';

/// Écran de tableau de bord avec analyse nutritionnelle et tendances
class DashboardScreen extends StatelessWidget {
  final List<ScanSession> sessions;
  final Function(ScanSession) onSessionSelected;
  final VoidCallback? onProductAnalysisRequested;
  final void Function(String productId, String productName, {int initialTabIndex})? onProductSelected;
  final ScanRepository? repository;

  /// Bouton Retour de la barre d'app (onglet précédent) ; absent si `null`
  final VoidCallback? onBack;

  const DashboardScreen({
    super.key,
    required this.sessions,
    required this.onSessionSelected,
    this.onProductAnalysisRequested,
    this.onProductSelected,
    this.repository,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    // Calculer les statistiques globales
    final stats = DashboardStats.fromSessions(sessions);
    
    return Scaffold(
      key: const ValueKey('dashboard_scaffold'),
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        leading: onBack != null ? AppBackButton(onPressed: onBack) : null,
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
          ? const EmptyDashboardState()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bouton d'analyse par produit
                  if (onProductAnalysisRequested != null)
                    ProductAnalysisButton(
                      onPressed: onProductAnalysisRequested!,
                    ),
                  const SizedBox(height: 24),
                  // Statistiques globales
                  GlobalStatsSection(stats: stats),
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
                  ProductPriceEvolutionSection(
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
                  ProductStoreComparisonSection(
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
                  ProductRecommendationSection(
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
                  ProductTypeComparisonSection(
                    productTypeStats: stats.productTypeStats,
                    globalAveragePrice: stats.averagePrice,
                  ),
                  const SizedBox(height: 24),

                  // Répartition Nutri-Score
                  NutriScoreDistributionSection(
                    sessions: sessions,
                    distribution: stats.nutriScoreDistribution,
                  ),
                  const SizedBox(height: 24),
                  
                  // Évolution temporelle
                  TimeTrendSection(
                    weeklyStats: stats.weeklyStats,
                    monthlyStats: stats.monthlyStats,
                  ),
                  const SizedBox(height: 24),
                  
                  // Totaux par période
                  PeriodTotalsSection(
                    weeklyTotal: stats.weeklyTotal,
                    monthlyTotal: stats.monthlyTotal,
                  ),
                  const SizedBox(height: 24),
                  
                  // Derniers scans
                  RecentScansSection(
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
