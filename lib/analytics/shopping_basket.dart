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

  /// Relevé dans au moins deux magasins : il permet de les comparer
  bool get isCompared => latestPriceByStore.length >= 2;

  /// Magasin le moins cher pour ce produit
  MapEntry<String, double> get cheapest =>
      latestPriceByStore.entries.reduce((a, b) => b.value < a.value ? b : a);
}

/// Un magasin du panier, comparé à l'identique au magasin le moins cher :
/// seuls des prix réellement relevés comptent, aucun n'est estimé.
class StoreBasketCost {
  final String storeName;

  /// Produits du panier relevés ici et dans au moins un autre magasin
  final int comparedCount;

  /// Indice de prix : 1.0 = toujours au prix le plus bas relevé pour chaque
  /// produit, 1.04 = 4 % au-dessus en moyenne. Sert à classer les magasins.
  final double priceIndex;

  /// Produits relevés à la fois ici et dans le magasin le moins cher
  final int commonWithBest;

  /// Total de ces produits communs, ici et dans le magasin le moins cher
  final double total;
  final double bestTotal;

  StoreBasketCost({
    required this.storeName,
    required this.comparedCount,
    required this.priceIndex,
    required this.commonWithBest,
    required this.total,
    required this.bestTotal,
  });

  /// Surcoût par rapport au magasin le moins cher, sur les produits communs
  double get extraVsBest => total - bestTotal;

  /// Même surcoût en % du total chez le moins cher
  double get percentVsBest => bestTotal > 0 ? extraVsBest / bestTotal * 100 : 0;
}

/// « Où faire mes courses ? » : quel magasin revient le moins cher pour le
/// panier habituel, en ne comparant que des prix réellement relevés.
class ShoppingBasketAnalysis {
  /// Produits du panier, du plus acheté au moins acheté
  final List<BasketProduct> products;

  /// Magasins comparables (au moins un produit relevé aussi ailleurs), du
  /// moins cher au plus cher selon leur indice de prix
  final List<StoreBasketCost> stores;

  /// Magasins dont aucun produit du panier n'a été relevé ailleurs
  final List<String> uncomparedStores;

  /// Indique si le panier se limite aux produits achetés plusieurs fois
  final bool usesRegularPurchases;

  ShoppingBasketAnalysis({
    required this.products,
    required this.stores,
    this.uncomparedStores = const [],
    required this.usesRegularPurchases,
  });

  /// Nombre de produits communs à partir duquel on conclut qu'un magasin est
  /// moins cher qu'un autre (sur un ou deux produits, c'est du hasard)
  static const int minCommonProducts = 3;

  StoreBasketCost get bestStore => stores.first;

  /// Produits relevés dans au moins deux magasins
  List<BasketProduct> get comparedProducts => products.where((p) => p.isCompared).toList();

  /// Le magasin comparé au moins cher pour conclure : au moins
  /// [minCommonProducts] produits en commun, et le plus gros surcoût.
  /// `null` s'il n'y a pas encore assez de produits en commun.
  StoreBasketCost? get comparisonStore {
    StoreBasketCost? result;
    for (final store in stores.skip(1)) {
      if (store.commonWithBest < minCommonProducts) continue;
      if (result == null || store.extraVsBest > result.extraVsBest) result = store;
    }
    return result;
  }

  /// Assez de produits en commun pour dire quel magasin est le moins cher
  bool get isConclusive => comparisonStore != null;

  /// Produits relevés dans le magasin le moins cher et dans au moins un autre
  List<BasketProduct> get _bestStoreProducts =>
      comparedProducts.where((p) => p.latestPriceByStore.containsKey(bestStore.storeName)).toList();

  /// Économie supplémentaire en achetant chacun de ces produits là où il est
  /// le moins cher plutôt que tout dans le magasin le moins cher
  double get optimalSavingVsBestStore => _bestStoreProducts.fold(
        0.0,
        (sum, p) => sum + p.latestPriceByStore[bestStore.storeName]! - p.cheapest.value,
      );

  /// Panier panaché : magasin → produits à y acheter (produits comparés)
  Map<String, List<BasketProduct>> get optimalPlan {
    final plan = <String, List<BasketProduct>>{};
    for (final product in comparedProducts) {
      plan.putIfAbsent(product.cheapest.key, () => []).add(product);
    }
    return plan;
  }

  /// Nombre minimal de produits « habituels » (achetés au moins [minPurchases] fois)
  /// en dessous duquel le panier prend tous les produits dont un magasin est connu.
  static const int minRegularProducts = 3;

  /// Analyse le panier, ou `null` si aucun produit n'a été relevé dans deux
  /// magasins (rien à comparer).
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

    // Seuls les produits relevés dans au moins deux magasins départagent les magasins
    final compared = products.where((p) => p.isCompared).toList();
    final comparedStores = {for (final p in compared) ...p.latestPriceByStore.keys};
    if (comparedStores.length < 2) return null;

    // Indice de prix : moyenne, sur les produits comparés vendus ici, du
    // rapport entre le prix ici et le prix le plus bas relevé
    final indexed = [
      for (final store in comparedStores)
        () {
          final ratios = [
            for (final p in compared)
              if (p.latestPriceByStore[store] case final price?) price / p.cheapest.value,
          ];
          return (store: store, count: ratios.length, index: ratios.reduce((a, b) => a + b) / ratios.length);
        }(),
    ]..sort((a, b) {
        final byIndex = a.index.compareTo(b.index);
        return byIndex != 0 ? byIndex : b.count.compareTo(a.count);
      });

    // Comparaison à l'identique avec le moins cher : produits relevés dans les deux
    final best = indexed.first.store;
    final stores = [
      for (final s in indexed)
        () {
          final common = compared.where((p) => p.latestPriceByStore.containsKey(s.store) &&
              p.latestPriceByStore.containsKey(best));
          return StoreBasketCost(
            storeName: s.store,
            comparedCount: s.count,
            priceIndex: s.index,
            commonWithBest: common.length,
            total: common.fold(0.0, (sum, p) => sum + p.latestPriceByStore[s.store]!),
            bestTotal: common.fold(0.0, (sum, p) => sum + p.latestPriceByStore[best]!),
          );
        }(),
    ];

    final allStores = {for (final p in products) ...p.latestPriceByStore.keys};
    final uncompared = allStores.where((s) => !comparedStores.contains(s)).toList()..sort();

    return ShoppingBasketAnalysis(
      products: products,
      stores: stores,
      uncomparedStores: uncompared,
      usesRegularPurchases: usesRegular,
    );
  }
}
