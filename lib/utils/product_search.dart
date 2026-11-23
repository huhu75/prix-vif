// Recherche de produits tolérante : sans accents ni majuscules, mot par mot
// et en début de mot, avec une faute de frappe permise dans les mots longs.

const Map<String, String> _accents = {
  'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a', 'å': 'a',
  'ç': 'c',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ñ': 'n',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
  'ý': 'y', 'ÿ': 'y',
  'œ': 'oe', 'æ': 'ae',
};

final RegExp _wordChar = RegExp(r'[a-z0-9]');
final RegExp _spaces = RegExp(r'\s+');

/// Texte en minuscules, sans accents ni ponctuation (« Demi-Écrémé » → « demi ecreme »)
String normalizeForSearch(String text) {
  final buffer = StringBuffer();
  for (final rune in text.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    final plain = _accents[char];
    if (plain != null) {
      buffer.write(plain);
    } else if (_wordChar.hasMatch(char)) {
      buffer.write(char);
    } else {
      buffer.write(' ');
    }
  }
  return buffer.toString().replaceAll(_spaces, ' ').trim();
}

List<String> _words(String text) => normalizeForSearch(text).split(' ').where((w) => w.isNotEmpty).toList();

/// Les deux mots sont-ils à au plus une lettre près (ajout, retrait ou remplacement) ?
bool _withinOneEdit(String a, String b) {
  if ((a.length - b.length).abs() > 1) return false;
  var i = 0;
  var j = 0;
  var edits = 0;
  while (i < a.length && j < b.length) {
    if (a[i] == b[j]) {
      i++;
      j++;
      continue;
    }
    if (++edits > 1) return false;
    if (a.length > b.length) {
      i++;
    } else if (a.length < b.length) {
      j++;
    } else {
      i++;
      j++;
    }
  }
  return edits + (a.length - i) + (b.length - j) <= 1;
}

/// Qualité de la correspondance d'un mot tapé avec un mot du produit :
/// 3 début de mot, 2 milieu de mot, 1 une faute de frappe, 0 aucune
int _wordMatch(String typed, String word) {
  if (word.startsWith(typed)) return 3;
  if (typed.length >= 3 && word.contains(typed)) return 2;
  if (typed.length >= 5) {
    // Faute de frappe : le mot entier, ou son début de même longueur (± 1)
    if (_withinOneEdit(typed, word)) return 1;
    for (final length in [typed.length - 1, typed.length, typed.length + 1]) {
      if (length <= word.length && _withinOneEdit(typed, word.substring(0, length))) return 1;
    }
  }
  return 0;
}

/// Une recherche tapée, prête à noter des produits
class ProductSearchQuery {
  final String raw;
  final List<String> words;
  final String normalized;

  ProductSearchQuery(this.raw)
      : words = _words(raw),
        normalized = normalizeForSearch(raw);

  bool get isEmpty => words.isEmpty;

  /// Pertinence du produit (plus haut = meilleur), `null` s'il ne correspond
  /// pas : chaque mot tapé doit se retrouver dans le nom, la marque, la
  /// catégorie, un magasin ou le code-barres. Le nom compte plus que la
  /// marque, qui compte plus que la catégorie et les magasins.
  /// Sans recherche, tout correspond (pertinence 0).
  double? score({
    required String name,
    String? brand,
    Iterable<String> categories = const [],
    Iterable<String> stores = const [],
    String? barcode,
  }) {
    if (isEmpty) return 0;
    final fields = <(List<String>, double)>[
      (_words(name), 3),
      (_words(brand ?? ''), 2),
      (categories.expand(_words).toList(), 1),
      (stores.expand(_words).toList(), 1),
    ];
    final ean = barcode?.trim() ?? '';

    var total = 0.0;
    for (final typed in words) {
      var best = 0.0;
      if (ean.isNotEmpty && typed.length >= 4 && ean.contains(typed)) best = 9;
      for (final (fieldWords, weight) in fields) {
        for (final word in fieldWords) {
          final match = _wordMatch(typed, word);
          if (match * weight > best) best = match * weight;
        }
      }
      if (best == 0) return null;
      total += best;
    }
    // Le nom commence par la recherche entière : en tête de liste
    if (normalizeForSearch(name).startsWith(normalized)) total += 10;
    return total;
  }

  /// Le produit correspond-il à la recherche ? (voir [score])
  bool matches({
    required String name,
    String? brand,
    Iterable<String> categories = const [],
    Iterable<String> stores = const [],
    String? barcode,
  }) =>
      score(name: name, brand: brand, categories: categories, stores: stores, barcode: barcode) != null;
}
