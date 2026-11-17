import '../models.dart';

// ===================================================
// Briques communes aux calculs d'analyse des prix
// ===================================================

/// Clé d'identité d'un produit : EAN si connu, sinon nom + marque normalisés.
String productKeyOf(ScannedItem item) {
  final barcode = item.barcode?.trim();
  if (barcode != null && barcode.isNotEmpty) return 'bc_$barcode';
  return 'name_${item.name.trim().toLowerCase()}_${(item.brand ?? '').trim().toLowerCase()}';
}

/// Identifiant à passer à la fiche produit : EAN, sinon nom, sinon id.
String productIdOf(ScannedItem item) {
  final barcode = item.barcode?.trim();
  if (barcode != null && barcode.isNotEmpty) return barcode;
  final name = item.name.trim();
  return name.isNotEmpty ? name : item.id;
}

/// Magasin d'un article : celui de l'article, sinon celui de sa session.
String? resolveStoreName(ScannedItem item, ScanSession session) {
  final raw = (item.storeName ?? session.storeName ?? '').trim();
  return raw.isEmpty ? null : raw;
}

/// Un article scanné avec son identité produit et son magasin résolus.
class ProductObservation {
  final ScannedItem item;
  final String key;
  final String productId;
  final String? storeName;

  ProductObservation(this.item, ScanSession session)
      : key = productKeyOf(item),
        productId = productIdOf(item),
        storeName = resolveStoreName(item, session);

  double get price => item.price;
  DateTime get date => item.scanDate;

  /// Toutes les observations d'une liste de sessions, dans l'ordre des sessions.
  static List<ProductObservation> fromSessions(List<ScanSession> sessions) => [
        for (final session in sessions)
          for (final item in session.items) ProductObservation(item, session),
      ];
}

/// Regroupe les observations par produit, en conservant l'ordre de première apparition.
Map<String, List<ProductObservation>> groupByProduct(Iterable<ProductObservation> observations) {
  final groups = <String, List<ProductObservation>>{};
  for (final observation in observations) {
    groups.putIfAbsent(observation.key, () => []).add(observation);
  }
  return groups;
}

/// Dernière observation de chaque magasin (les observations sans magasin sont ignorées).
Map<String, ProductObservation> latestByStore(Iterable<ProductObservation> observations) {
  final latest = <String, ProductObservation>{};
  for (final observation in observations) {
    final store = observation.storeName;
    if (store == null) continue;
    final existing = latest[store];
    if (existing == null || observation.date.isAfter(existing.date)) {
      latest[store] = observation;
    }
  }
  return latest;
}
