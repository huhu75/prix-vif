import '../models.dart';
import 'product_observation.dart';

/// Un produit du panier habituel, avec son dernier prix connu dans chaque magasin
class BasketProduct {
  final String productId;
  final String name;
  final String? brand;
  final int purchaseCount;
  final Map<String, double> latestPriceByStore;

  BasketProduct({
    required this.productId,
    required this.name,
    this.brand,
    required this.purchaseCount,
    required this.latestPriceByStore,
  });

  /// Prix moyen observé dans les magasins où le produit a été vu
  double get averagePrice =>
      latestPriceByStore.values.fold(0.0, (sum, p) => sum + p) / latestPriceByStore.length;

  /// Magasin le moins cher pour ce produit
  MapEntry<String, double> get cheapest =>
      latestPriceByStore.entries.reduce((a, b) => b.value < a.value ? b : a);
}

/// Coût estimé du panier dans un magasin
class StoreBasketCost {
  final String storeName;

  /// Total du panier : prix connus dans ce magasin + prix moyen observé ailleurs pour les autres
  final double total;

  /// Nombre de produits du panier dont le prix est connu dans ce magasin
  final int pricedCount;

  /// Nombre total de produits du panier
  final int productCount;

  StoreBasketCost({
    required this.storeName,
    required this.total,
    required this.pricedCount,
    required this.productCount,
  });

  /// Nombre de produits estimés (prix inconnu dans ce magasin)
  int get estimatedCount => productCount - pricedCount;
}

/// « Où faire mes courses ? » : coût du panier habituel par magasin
/// et panier optimal en combinant les magasins.
class ShoppingBasketAnalysis {
  /// Produits du panier, du plus acheté au moins acheté
  final List<BasketProduct> products;

  /// Magasins, du moins cher au plus cher
  final List<StoreBasketCost> stores;

  /// Indique si le panier se limite aux produits achetés plusieurs fois
  final bool usesRegularPurchases;

  ShoppingBasketAnalysis({
    required this.products,
    required this.stores,
    required this.usesRegularPurchases,
  });

  StoreBasketCost get bestStore => stores.first;
  StoreBasketCost get mostExpensiveStore => stores.last;

  /// Économie en faisant tout le panier dans le meilleur magasin plutôt que dans le plus cher
  double get savingVsMostExpensive => mostExpensiveStore.total - bestStore.total;

  /// Coût du panier en achetant chaque produit là où il est le moins cher
  double get optimalTotal => products.fold(0.0, (sum, p) => sum + p.cheapest.value);

  /// Économie du panier optimal par rapport au meilleur magasin unique
  double get optimalSavingVsBestStore => bestStore.total - optimalTotal;

  /// Panier optimal : magasin → produits à y acheter
  Map<String, List<BasketProduct>> get optimalPlan {
    final plan = <String, List<BasketProduct>>{};
    for (final product in products) {
      plan.putIfAbsent(product.cheapest.key, () => []).add(product);
    }
    return plan;
  }

  /// Nombre minimal de produits « habituels » (achetés au moins [minPurchases] fois)
  /// en dessous duquel le panier prend tous les produits dont un magasin est connu.
  static const int minRegularProducts = 3;

  /// Analyse le panier, ou `null` s'il n'y a pas au moins 2 magasins à comparer.
  static ShoppingBasketAnalysis? calculate(List<ScanSession> sessions, {int minPurchases = 2}) {
    final groups = groupByProduct(
      ProductObservation.fromSessions(sessions).where((o) => o.storeName != null),
    );

    final allProducts = <BasketProduct>[];
    for (final observations in groups.values) {
      final latest = latestByStore(observations);
      final meta = observations.last;
      allProducts.add(BasketProduct(
        productId: meta.productId,
        name: meta.item.name,
        brand: meta.item.brand,
        purchaseCount: observations.length,
        latestPriceByStore: latest.map((store, o) => MapEntry(store, o.price)),
      ));
    }

    final regular = allProducts.where((p) => p.purchaseCount >= minPurchases).toList();
    final usesRegular = regular.length >= minRegularProducts;
    final products = (usesRegular ? regular : allProducts)
      ..sort((a, b) => b.purchaseCount.compareTo(a.purchaseCount));

    final storeNames = {for (final p in products) ...p.latestPriceByStore.keys};
    if (storeNames.length < 2) return null;

    final stores = storeNames.map((store) {
      var total = 0.0;
      var priced = 0;
      for (final product in products) {
        final price = product.latestPriceByStore[store];
        if (price != null) {
          total += price;
          priced += 1;
        } else {
          total += product.averagePrice;
        }
      }
      return StoreBasketCost(
        storeName: store,
        total: total,
        pricedCount: priced,
        productCount: products.length,
      );
    }).toList()
      ..sort((a, b) {
        final byTotal = a.total.compareTo(b.total);
        return byTotal != 0 ? byTotal : b.pricedCount.compareTo(a.pricedCount);
      });

    return ShoppingBasketAnalysis(
      products: products,
      stores: stores,
      usesRegularPurchases: usesRegular,
    );
  }
}
