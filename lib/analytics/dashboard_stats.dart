import '../models.dart';
import '../models/product_category.dart';
import 'category_comparison.dart';
import 'price_changes.dart';
import 'shopping_basket.dart';
import 'store_comparison.dart';

/// Données des trois onglets du tableau de bord : Produits, Magasins, Évolution
class DashboardStats {
  /// Onglet Produits : chaque produit avec ses prix par magasin (écarts d'abord)
  final List<ProductStorePrices> productPrices;

  /// Onglet Produits, vue « Par catégorie » : les produits de chaque catégorie,
  /// toutes marques et tous magasins confondus, par libellé
  final List<CategoryGroup> categoryGroups;

  /// Catégorie de chaque produit (clé produit → catégorie)
  final Map<String, ProductCategory> categories;

  /// Onglet Magasins : « Où faire mes courses ? », `null` tant qu'il n'y a pas
  /// 2 magasins à comparer
  final ShoppingBasketAnalysis? shoppingBasket;

  /// Onglet Évolution : changements de prix, de la plus forte hausse à la plus forte baisse
  final List<PriceChange> priceChanges;

  DashboardStats({
    required this.productPrices,
    this.categoryGroups = const [],
    this.categories = const {},
    required this.shoppingBasket,
    required this.priceChanges,
  });

  /// Catégorie d'un produit de [productPrices]
  ProductCategory? categoryOf(ProductStorePrices product) => categories[product.productKey];

  /// Produits vus dans plusieurs magasins à des prix différents
  List<ProductStorePrices> get comparedProducts => productPrices.where((p) => p.hasPriceDifference).toList();

  /// Produits sans catégorie (à choisir depuis leur fiche)
  List<ProductStorePrices> get uncategorizedProducts =>
      productPrices.where((p) => categoryOf(p) == null).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  /// Pour chaque magasin, les produits qui y sont le moins chers (parmi les
  /// produits comparés), magasins avec le plus de produits d'abord
  Map<String, List<ProductStorePrices>> get cheapestByStore {
    final byStore = <String, List<ProductStorePrices>>{};
    for (final product in comparedProducts) {
      byStore.putIfAbsent(product.cheapest.storeName, () => []).add(product);
    }
    final stores = byStore.keys.toList()
      ..sort((a, b) {
        final byCount = byStore[b]!.length.compareTo(byStore[a]!.length);
        return byCount != 0 ? byCount : a.compareTo(b);
      });
    return {for (final store in stores) store: byStore[store]!};
  }

  /// Hausses, de la plus forte à la plus faible
  List<PriceChange> get increases => priceChanges.where((c) => c.isIncrease).toList();

  /// Baisses, de la plus forte à la plus faible
  List<PriceChange> get decreases => priceChanges.reversed.where((c) => !c.isIncrease).toList();

  /// [categories] : catégorie de chaque produit (clé produit → catégorie)
  factory DashboardStats.fromSessions(
    List<ScanSession> sessions, {
    Map<String, ProductCategory> categories = const {},
  }) {
    return DashboardStats(
      productPrices: ProductStorePrices.calculate(sessions),
      categoryGroups: CategoryGroup.calculate(sessions, categories),
      categories: categories,
      shoppingBasket: ShoppingBasketAnalysis.calculate(sessions),
      priceChanges: PriceChange.calculate(sessions),
    );
  }
}
