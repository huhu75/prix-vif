/// Catégorie d'un produit, pour le comparer aux produits équivalents (toutes
/// marques et tous magasins confondus).
///
/// L'identifiant vient d'Open Food Facts (`compared_to_category`, ex.
/// `en:apple-juices`), ou commence par `perso:` pour une catégorie choisie à la
/// main. Le libellé est en français (« Jus de pomme »).
class ProductCategory {
  final String id;
  final String label;

  /// Choisie à la main : jamais remplacée par la catégorie Open Food Facts
  final bool manual;

  const ProductCategory({required this.id, required this.label, this.manual = false});

  /// Catégorie créée à la main à partir de son nom
  factory ProductCategory.custom(String label) {
    final clean = label.trim();
    return ProductCategory(id: 'perso:${slugify(clean)}', label: clean, manual: true);
  }

  Map<String, dynamic> toMap() => {'id': id, 'label': label, 'manual': manual};

  factory ProductCategory.fromMap(Map<dynamic, dynamic> map) => ProductCategory(
        id: map['id'] as String,
        label: map['label'] as String,
        manual: map['manual'] as bool? ?? false,
      );

  ProductCategory asManual() => ProductCategory(id: id, label: label, manual: true);

  @override
  bool operator ==(Object other) => other is ProductCategory && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// « Jus de Pomme Bio » → « jus-de-pomme-bio » (accents retirés)
String slugify(String text) {
  const accents = {
    'à': 'a', 'â': 'a', 'ä': 'a', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', 'î': 'i', 'ï': 'i',
    'ô': 'o', 'ö': 'o', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ç': 'c', 'œ': 'oe',
  };
  final lower = text.toLowerCase().split('').map((c) => accents[c] ?? c).join();
  return lower.replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
}

/// Libellé lisible d'un identifiant de catégorie quand son nom français est
/// inconnu : « en:apple-juices » → « Apple juices »
String humanizeCategoryId(String id) {
  final raw = id.contains(':') ? id.substring(id.indexOf(':') + 1) : id;
  final words = raw.replaceAll('-', ' ').trim();
  if (words.isEmpty) return id;
  return words[0].toUpperCase() + words.substring(1);
}
