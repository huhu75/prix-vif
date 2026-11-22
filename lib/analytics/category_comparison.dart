import '../models.dart';
import '../models/product_category.dart';
import '../utils/unit_price.dart';
import 'product_observation.dart';

/// Dernier prix connu d'un produit dans un magasin, au sein d'une catégorie
class CategoryOffer {
  final String productKey;
  final String productId;
  final String name;
  final String? brand;
  final String storeName;
  final double price;

  /// Prix au kg / L / unité, `null` si la contenance est inconnue
  final UnitPrice? unitPrice;
  final DateTime date;

  const CategoryOffer({
    required this.productKey,
    required this.productId,
    required this.name,
    this.brand,
    required this.storeName,
    required this.price,
    this.unitPrice,
    required this.date,
  });
}

/// Tous les produits d'une catégorie (toutes marques, tous magasins), pour
/// comparer des produits équivalents au kg, au litre ou à l'unité.
class CategoryGroup {
  final ProductCategory category;

  /// Unité de comparaison : la plus fréquente parmi les offres de contenance
  /// connue, `null` si aucune contenance n'est connue
  final PriceUnit? unit;

  /// Offres comparables (dans [unit]) du moins cher au plus cher, puis les
  /// autres (contenance inconnue ou d'une autre nature) par prix
  final List<CategoryOffer> offers;

  const CategoryGroup({required this.category, required this.unit, required this.offers});

  int get productCount => offers.map((o) => o.productKey).toSet().length;
  int get storeCount => offers.map((o) => o.storeName).toSet().length;

  /// L'offre se compare-t-elle dans l'unité de la catégorie ?
  bool isComparable(CategoryOffer offer) => unit != null && offer.unitPrice?.unit == unit;

  List<CategoryOffer> get comparableOffers => offers.where(isComparable).toList();

  /// Offre la moins chère au kg / L / unité (ou au prix si aucune contenance n'est connue)
  CategoryOffer? get cheapest {
    if (offers.isEmpty) return null;
    final comparable = comparableOffers;
    return comparable.isNotEmpty ? comparable.first : offers.first;
  }

  /// Meilleure offre d'un **autre** produit, moins chère au kg / L / unité que
  /// [reference] (d'au moins un demi-centime), ou `null`
  CategoryOffer? cheaperEquivalentThan(String productKey, UnitPrice? reference) {
    if (reference == null || reference.unit != unit) return null;
    for (final offer in comparableOffers) {
      if (offer.productKey == productKey) continue;
      return offer.unitPrice!.value < reference.value - 0.005 ? offer : null;
    }
    return null;
  }

  /// Groupes de toutes les catégories connues, par libellé.
  /// [categories] associe une clé produit (voir [productKeyOf]) à sa catégorie.
  static List<CategoryGroup> calculate(List<ScanSession> sessions, Map<String, ProductCategory> categories) {
    final offersByCategory = <String, List<CategoryOffer>>{};
    final categoryById = <String, ProductCategory>{};

    final groups = groupByProduct(
      ProductObservation.fromSessions(sessions).where((o) => o.storeName != null),
    );
    for (final observations in groups.values) {
      final category = categories[observations.first.key];
      if (category == null) continue;
      categoryById.putIfAbsent(category.id, () => category);
      for (final entry in latestByStore(observations).entries) {
        final o = entry.value;
        offersByCategory.putIfAbsent(category.id, () => []).add(CategoryOffer(
              productKey: o.key,
              productId: o.productId,
              name: o.item.name,
              brand: o.item.brand,
              storeName: entry.key,
              price: o.price,
              unitPrice: o.unitPrice,
              date: o.date,
            ));
      }
    }

    final result = [
      for (final entry in offersByCategory.entries) _build(categoryById[entry.key]!, entry.value),
    ]..sort((a, b) => a.category.label.toLowerCase().compareTo(b.category.label.toLowerCase()));
    return result;
  }

  /// Groupe de la catégorie [categoryId], ou `null` si aucun produit scanné n'y appartient
  static CategoryGroup? forCategory(
    String categoryId,
    List<ScanSession> sessions,
    Map<String, ProductCategory> categories,
  ) {
    for (final group in calculate(sessions, {
      for (final entry in categories.entries)
        if (entry.value.id == categoryId) entry.key: entry.value,
    })) {
      return group;
    }
    return null;
  }

  static CategoryGroup _build(ProductCategory category, List<CategoryOffer> offers) {
    final unitCounts = <PriceUnit, int>{};
    for (final offer in offers) {
      final u = offer.unitPrice?.unit;
      if (u != null) unitCounts[u] = (unitCounts[u] ?? 0) + 1;
    }
    PriceUnit? unit;
    for (final entry in unitCounts.entries) {
      if (unit == null || entry.value > unitCounts[unit]!) unit = entry.key;
    }

    final comparable = offers.where((o) => unit != null && o.unitPrice?.unit == unit).toList()
      ..sort((a, b) => a.unitPrice!.value.compareTo(b.unitPrice!.value));
    final others = offers.where((o) => !(unit != null && o.unitPrice?.unit == unit)).toList()
      ..sort((a, b) => a.price.compareTo(b.price));
    return CategoryGroup(category: category, unit: unit, offers: [...comparable, ...others]);
  }
}
