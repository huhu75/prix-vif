import 'package:flutter/material.dart';
import '../theme.dart';
import '../models.dart';
import '../models/product_category.dart';
import '../analytics/analytics.dart';
import '../services/scan_repository.dart';
import '../widgets/dashboard/empty_dashboard_state.dart';
import '../widgets/dashboard/prices_tab.dart';
import '../widgets/dashboard/products_tab.dart';
import '../widgets/dashboard/stores_tab.dart';
import '../widgets/magic_title.dart';
import '../widgets/nav_buttons.dart';
import 'product_detail_screen.dart';

/// Tableau de bord en trois onglets, centré sur le prix des produits :
/// Produits (où chaque produit est le moins cher), Magasins (où faire mes
/// courses, ce que chaque magasin a de moins cher) et Évolution (ce qui
/// augmente ou baisse).
class DashboardScreen extends StatelessWidget {
  final List<ScanSession> sessions;

  /// Catégorie de chaque produit (clé produit → catégorie)
  final Map<String, ProductCategory> categories;

  /// Bouton « Tous mes produits » de la barre d'app (liste des produits)
  final VoidCallback? onProductAnalysisRequested;
  final void Function(String productId, String productName, {int initialTabIndex})? onProductSelected;
  final ScanRepository? repository;

  /// Bouton Retour de la barre d'app (onglet précédent) ; absent si `null`
  final VoidCallback? onBack;

  /// « Où l'acheter ? » : chaque nouvelle valeur rouvre l'onglet Produits avec
  /// le curseur dans la recherche
  final int searchRequestId;

  const DashboardScreen({
    super.key,
    required this.sessions,
    this.categories = const {},
    this.onProductAnalysisRequested,
    this.onProductSelected,
    this.repository,
    this.onBack,
    this.searchRequestId = 0,
  });

  // Onglets de la fiche produit ouverts depuis le tableau de bord
  static const int _productEvolutionTab = 1;
  static const int _productStoresTab = 2;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return Scaffold(
        key: const ValueKey('dashboard_scaffold'),
        backgroundColor: AppTheme.backgroundDark,
        appBar: _buildAppBar(),
        body: const EmptyDashboardState(),
      );
    }

    final stats = DashboardStats.fromSessions(sessions, categories: categories);
    return DefaultTabController(
      // Nouvelle demande « Où l'acheter ? » : repartir de l'onglet Produits
      key: ValueKey('dashboard_tabs_$searchRequestId'),
      length: 3,
      child: Scaffold(
        key: const ValueKey('dashboard_scaffold'),
        backgroundColor: AppTheme.backgroundDark,
        appBar: _buildAppBar(
          tabs: const TabBar(
            indicatorColor: AppTheme.primary,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textSecondary,
            tabs: [
              Tab(key: ValueKey('dashboard_tab_products'), icon: Icon(Icons.local_offer_outlined), text: 'Produits'),
              Tab(key: ValueKey('dashboard_tab_stores'), icon: Icon(Icons.store), text: 'Magasins'),
              Tab(key: ValueKey('dashboard_tab_prices'), icon: Icon(Icons.trending_up), text: 'Évolution'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ProductsTab(
              products: stats.productPrices,
              categoryGroups: stats.categoryGroups,
              categoryOf: stats.categoryOf,
              autofocusSearch: searchRequestId > 0,
              onProductTap: (id, name) => _openProduct(context, id, name, _productStoresTab),
            ),
            StoresTab(
              basket: stats.shoppingBasket,
              cheapestByStore: stats.cheapestByStore,
              onProductTap: (id, name) => _openProduct(context, id, name, _productStoresTab),
            ),
            PricesTab(
              increases: stats.increases,
              decreases: stats.decreases,
              onProductTap: (id, name) => _openProduct(context, id, name, _productEvolutionTab),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar({PreferredSizeWidget? tabs}) {
    return AppBar(
      leading: onBack != null ? AppBackButton(onPressed: onBack) : null,
      title: const NeonTitle(text: 'TABLEAU DE BORD', fontSize: 20),
      actions: [
        if (onProductAnalysisRequested != null)
          AppNavActionButton(
            key: const ValueKey('dashboard_all_products'),
            icon: Icons.inventory_2_outlined,
            tooltip: 'Tous mes produits',
            onPressed: onProductAnalysisRequested!,
          ),
        const SizedBox(width: 8),
      ],
      bottom: tabs,
    );
  }

  void _openProduct(BuildContext context, String productId, String productName, int initialTabIndex) {
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
    }
  }
}
