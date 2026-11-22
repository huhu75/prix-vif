import '../models.dart';
import '../models/product_category.dart';
import '../utils/unit_price.dart';
import 'category_comparison.dart';
import 'product_observation.dart';
import 'store_comparison.dart';

/// Verdict d'achat d'un produit dans un magasin
enum AdviceVerdict {
  /// Aucun autre magasin connu ne le vend moins cher
  recommended,

  /// Un autre magasin le vend moins cher, même de quelques centimes
  discouraged,

  /// Pas assez de prix connus pour conclure
  unknown,
}

/// Conseil « acheter ici ou pas » pour un produit dans un magasin, d'après les
/// derniers prix relevés du même produit ailleurs et des équivalents de sa catégorie.
class PriceAdvice {
  final AdviceVerdict verdict;
  final String store;

  /// Prix considéré dans ce magasin (saisi, ou dernier prix relevé), `null` si inconnu
  final double? price;

  /// Le prix vient du dernier relevé dans ce magasin (pas d'une saisie)
  final bool priceIsLastKnown;

  /// Magasin le moins cher pour ce même produit, s'il est moins cher que [price]
  final StorePrice? cheaperElsewhere;

  /// Meilleur prix du même produit ailleurs (pour un prix encore inconnu ici)
  final StorePrice? bestElsewhere;

  /// Nombre d'autres magasins où le produit a été vu
  final int otherStoreCount;

  /// Prix au kg / L / unité ici, `null` si la contenance est inconnue
  final UnitPrice? unitPrice;

  /// Catégorie du produit et équivalent moins cher au kg / L / unité
  final ProductCategory? category;
  final CategoryOffer? cheaperEquivalent;

  const PriceAdvice({
    required this.verdict,
    required this.store,
    this.price,
    this.priceIsLastKnown = false,
    this.cheaperElsewhere,
    this.bestElsewhere,
    this.otherStoreCount = 0,
    this.unitPrice,
    this.category,
    this.cheaperEquivalent,
  });

  /// Économie en achetant le même produit dans [cheaperElsewhere]
  double? get savingElsewhere => cheaperElsewhere == null || price == null ? null : price! - cheaperElsewhere!.price;

  /// Calcule le conseil pour le produit [productKey] dans le magasin [store].
  ///
  /// [price] : prix saisi (sinon le dernier prix relevé dans ce magasin).
  /// [quantity] / [unit] : contenance, pour le prix au kg / L (sinon celle du
  /// dernier relevé). [categoryId] : catégorie à utiliser si le produit n'en a
  /// pas encore dans [categories] (produit en cours de scan).
  static PriceAdvice calculate({
    required List<ScanSession> sessions,
    required Map<String, ProductCategory> categories,
    required String productKey,
    required String store,
    double? price,
    double? quantity,
    String? unit,
    ProductCategory? category,
  }) {
    final observations = ProductObservation.fromSessions(sessions).where((o) => o.key == productKey).toList();
    final latest = latestByStore(observations);
    final here = latest[store];
    final others = latest.entries.where((e) => e.key != store).toList()
      ..sort((a, b) => a.value.price.compareTo(b.value.price));

    final effectivePrice = price ?? here?.price;
    final best = others.isEmpty ? null : StorePrice(others.first.key, others.first.value.price, others.first.value.date);

    StorePrice? cheaper;
    if (effectivePrice != null && best != null && best.price < effectivePrice - 0.009) cheaper = best;

    final verdict = effectivePrice == null || best == null
        ? AdviceVerdict.unknown
        : cheaper != null
            ? AdviceVerdict.discouraged
            : AdviceVerdict.recommended;

    // Prix au kg / L : contenance fournie, sinon celle du dernier relevé du produit
    UnitPrice? unitPrice;
    if (effectivePrice != null) {
      unitPrice = UnitPrice.of(effectivePrice, quantity, unit);
      if (unitPrice == null && observations.isNotEmpty) {
        final reference = observations.reduce((a, b) => b.date.isAfter(a.date) ? b : a).item;
        unitPrice = UnitPrice.of(effectivePrice, reference.quantity, reference.unit);
      }
    }

    final productCategory = categories[productKey] ?? category;
    CategoryOffer? equivalent;
    if (productCategory != null) {
      final group = CategoryGroup.forCategory(productCategory.id, sessions, {
        ...categories,
        productKey: productCategory,
      });
      equivalent = group?.cheaperEquivalentThan(productKey, unitPrice);
    }

    return PriceAdvice(
      verdict: verdict,
      store: store,
      price: effectivePrice,
      priceIsLastKnown: price == null && here != null,
      cheaperElsewhere: cheaper,
      bestElsewhere: best,
      otherStoreCount: others.length,
      unitPrice: unitPrice,
      category: productCategory,
      cheaperEquivalent: equivalent,
    );
  }
}
