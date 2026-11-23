// Onglet Produits : où chaque produit est le moins cher, et l'évolution des prix
// (version provisoire, remplacée par la liste unique à l'étape suivante)
import 'package:flutter/material.dart';

import '../analytics/analytics.dart';
import '../models.dart';
import '../models/product_category.dart';
import '../theme.dart';
import '../widgets/dashboard/empty_dashboard_state.dart';
import '../widgets/dashboard/prices_tab.dart';
import '../widgets/dashboard/products_tab.dart';
import '../widgets/magic_title.dart';
import '../widgets/nav_buttons.dart';
import 'home_screen.dart' show ProductTap;

/// Vues de l'onglet Produits
enum ProductsView { whereToBuy, evolution }

class ProductsScreen extends StatelessWidget {
  final List<ScanSession> sessions;

  /// Catégorie de chaque produit (clé produit → catégorie)
  final Map<String, ProductCategory> categories;
  final ProductTap onProductTap;

  /// « Tous mes produits » (liste complète avec tri et filtres)
  final VoidCallback? onAllProducts;

  /// Chaque nouvelle valeur rouvre l'onglet sur [initialView]
  final int requestId;
  final ProductsView initialView;

  /// Curseur dans la recherche à l'ouverture (recherche de l'accueil)
  final bool focusSearch;

  /// Recherche déjà remplie (raccourci de catégorie de l'accueil)
  final String initialQuery;

  // Onglets de la fiche produit
  static const int _evolutionTab = 1;
  static const int _storesTab = 2;

  const ProductsScreen({
    super.key,
    required this.sessions,
    this.categories = const {},
    required this.onProductTap,
    this.onAllProducts,
    this.requestId = 0,
    this.initialView = ProductsView.whereToBuy,
    this.focusSearch = false,
    this.initialQuery = '',
  });

  PreferredSizeWidget _appBar({PreferredSizeWidget? tabs}) => AppBar(
        title: const NeonTitle(text: 'PRODUITS', fontSize: 20),
        actions: [
          if (onAllProducts != null)
            AppNavActionButton(
              key: const ValueKey('products_all'),
              icon: Icons.inventory_2_outlined,
              tooltip: 'Tous mes produits',
              onPressed: onAllProducts!,
            ),
          const SizedBox(width: 8),
        ],
        bottom: tabs,
      );

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        appBar: _appBar(),
        body: const EmptyDashboardState(),
      );
    }
    final stats = DashboardStats.fromSessions(sessions, categories: categories);
    return DefaultTabController(
      // Nouvelle demande (recherche, « Tout voir ») : repartir de la vue demandée
      key: ValueKey('products_tabs_$requestId'),
      length: 2,
      initialIndex: initialView.index,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        appBar: _appBar(
          tabs: const TabBar(
            indicatorColor: AppTheme.primary,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textSecondary,
            tabs: [
              Tab(key: ValueKey('products_view_where'), icon: Icon(Icons.local_offer_outlined), text: 'Où acheter'),
              Tab(key: ValueKey('products_view_evolution'), icon: Icon(Icons.trending_up), text: 'Évolution'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ProductsTab(
              products: stats.productPrices,
              categoryGroups: stats.categoryGroups,
              categoryOf: stats.categoryOf,
              autofocusSearch: focusSearch,
              initialQuery: initialQuery,
              onProductTap: (id, name) => onProductTap(id, name, initialTabIndex: _storesTab),
            ),
            PricesTab(
              increases: stats.increases,
              decreases: stats.decreases,
              onProductTap: (id, name) => onProductTap(id, name, initialTabIndex: _evolutionTab),
            ),
          ],
        ),
      ),
    );
  }
}
