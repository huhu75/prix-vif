import '../models.dart';
import 'product_observation.dart';

/// Dernier prix connu d'un produit dans un magasin
class StorePrice {
  final String storeName;
  final double price;
  final DateTime date;

  const StorePrice(this.storeName, this.price, this.date);
}

/// Prix d'un produit dans chaque magasin où il a été vu (dernier prix connu),
/// du moins cher au plus cher : où ce produit est-il le moins cher ?
class ProductStorePrices {
  /// Clé produit (voir [productKeyOf]), pour retrouver sa catégorie
  final String productKey;
  final String productId;
  final String name;
  final String? brand;

  /// Magasins, du moins cher au plus cher
  final List<StorePrice> storePrices;

  ProductStorePrices({
    this.productKey = '',
    required this.productId,
    required this.name,
    this.brand,
    required this.storePrices,
  });

  StorePrice get cheapest => storePrices.first;
  StorePrice get mostExpensive => storePrices.last;
  int get storeCount => storePrices.length;

  /// Écart entre le magasin le plus cher et le moins cher
  double get priceDiff => mostExpensive.price - cheapest.price;

  /// Économie possible en % du prix le plus cher
  double get savingPercent => mostExpensive.price > 0 ? priceDiff / mostExpensive.price * 100 : 0.0;

  /// Vu dans au moins 2 magasins avec un vrai écart de prix
  bool get hasPriceDifference => storeCount >= 2 && priceDiff > 0.01;

  /// Tous les produits vus dans au moins un magasin : d'abord ceux qui ont un
  /// écart de prix entre magasins (du plus gros au plus petit), puis les autres
  /// par nom.
  static List<ProductStorePrices> calculate(List<ScanSession> sessions) {
    final groups = groupByProduct(
      ProductObservation.fromSessions(sessions).where((o) => o.storeName != null),
    );
    final products = <ProductStorePrices>[];

    for (final observations in groups.values) {
      final latest = latestByStore(observations);
      if (latest.isEmpty) continue;
      final prices = [
        for (final entry in latest.entries) StorePrice(entry.key, entry.value.price, entry.value.date),
      ]..sort((a, b) => a.price.compareTo(b.price));

      // Nom et marque du scan le plus récent
      final meta = observations.reduce((a, b) => b.date.isAfter(a.date) ? b : a);
      products.add(ProductStorePrices(
        productKey: meta.key,
        productId: meta.productId,
        name: meta.item.name,
        brand: meta.item.brand,
        storePrices: prices,
      ));
    }

    products.sort((a, b) {
      if (a.hasPriceDifference != b.hasPriceDifference) return a.hasPriceDifference ? -1 : 1;
      if (a.hasPriceDifference) return b.priceDiff.compareTo(a.priceDiff);
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return products;
  }
}
