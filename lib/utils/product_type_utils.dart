// ===================================================
// Utilitaires pour le « type » de produit issu d'Open Food Facts
// ===================================================

/// Label affiché quand un produit n'a aucune catégorie OFF connue
const String uncategorizedTypeLabel = 'Non catégorisé';

/// Retourne le type de produit le plus spécifique à partir des catégories OFF.
///
/// `categories_tags` d'Open Food Facts est ordonné du plus général au plus
/// spécifique (ex: ["Foods", "Beverages", "Milks"]) : le dernier élément est
/// donc le type le plus précis. On retombe sur le premier élément si la liste
/// ne contient qu'une seule catégorie.
///
/// Retourne `null` si aucune catégorie n'est disponible.
String? productTypeOf(List<String>? categories) {
  if (categories == null) return null;
  final cleaned = categories
      .map((c) => c.trim())
      .where((c) => c.isNotEmpty)
      .toList();
  if (cleaned.isEmpty) return null;
  return cleaned.last;
}

/// Retourne le type de produit affichable (jamais null).
///
/// Utilise [productTypeOf] et retombe sur [uncategorizedTypeLabel].
String productTypeLabel(List<String>? categories) {
  return productTypeOf(categories) ?? uncategorizedTypeLabel;
}

/// Indique si le type retourné par [productTypeLabel] est un vrai type OFF
/// (et non le label par défaut pour les produits sans catégorie).
bool isCategorized(List<String>? categories) {
  return productTypeOf(categories) != null;
}
