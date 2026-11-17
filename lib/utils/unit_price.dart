// ===================================================
// Prix au kilo, au litre ou à l'unité
// ===================================================
// Les produits n'ont pas tous la même contenance (1 L, 6 x 1,5 L, 500 g…) :
// comparer leurs prix par article fausse les comparaisons. Ce fichier
// convertit une contenance (quantité + unité, au format Open Food Facts
// ou saisi) en prix normalisé : €/kg, €/L ou €/unité.

/// Unité de référence d'un prix normalisé
enum PriceUnit { kilogram, liter, piece }

extension PriceUnitLabel on PriceUnit {
  /// Libellé court affiché après un prix (ex. « €/kg »)
  String get label => switch (this) {
        PriceUnit.kilogram => '€/kg',
        PriceUnit.liter => '€/L',
        PriceUnit.piece => '€/unité',
      };
}

/// Contenance d'un article, exprimée en kg, en L ou en unités
class PackageSize {
  final double amount;
  final PriceUnit unit;

  const PackageSize(this.amount, this.unit);

  @override
  bool operator ==(Object other) =>
      other is PackageSize && other.unit == unit && (other.amount - amount).abs() < 1e-9;

  @override
  int get hashCode => Object.hash(unit, amount.toStringAsFixed(6));

  @override
  String toString() => 'PackageSize($amount ${unit.name})';
}

/// Prix normalisé (par kg, par litre ou par unité)
class UnitPrice {
  final double value;
  final PriceUnit unit;

  const UnitPrice(this.value, this.unit);

  /// Prix normalisé d'un article, ou `null` si sa contenance est inconnue
  static UnitPrice? of(double price, double? quantity, String? unit) {
    final size = parsePackageSize(quantity, unit);
    if (size == null || size.amount <= 0 || price <= 0) return null;
    return UnitPrice(price / size.amount, size.unit);
  }

  /// Ex. « 1.49 €/L »
  String format() => '${value.toStringAsFixed(2)} ${unit.label}';

  @override
  String toString() => format();
}

// Facteur de conversion de chaque unité vers l'unité de référence
const Map<String, (PriceUnit, double)> _units = {
  'kg': (PriceUnit.kilogram, 1),
  'kilo': (PriceUnit.kilogram, 1),
  'kilos': (PriceUnit.kilogram, 1),
  'g': (PriceUnit.kilogram, 0.001),
  'gr': (PriceUnit.kilogram, 0.001),
  'grs': (PriceUnit.kilogram, 0.001),
  'gramme': (PriceUnit.kilogram, 0.001),
  'grammes': (PriceUnit.kilogram, 0.001),
  'mg': (PriceUnit.kilogram, 0.000001),
  'l': (PriceUnit.liter, 1),
  'lt': (PriceUnit.liter, 1),
  'litre': (PriceUnit.liter, 1),
  'litres': (PriceUnit.liter, 1),
  'dl': (PriceUnit.liter, 0.1),
  'cl': (PriceUnit.liter, 0.01),
  'ml': (PriceUnit.liter, 0.001),
  'u': (PriceUnit.piece, 1),
  'unite': (PriceUnit.piece, 1),
  'unites': (PriceUnit.piece, 1),
  'unité': (PriceUnit.piece, 1),
  'unités': (PriceUnit.piece, 1),
  'piece': (PriceUnit.piece, 1),
  'pieces': (PriceUnit.piece, 1),
  'pièce': (PriceUnit.piece, 1),
  'pièces': (PriceUnit.piece, 1),
  'pc': (PriceUnit.piece, 1),
  'pcs': (PriceUnit.piece, 1),
  'sachet': (PriceUnit.piece, 1),
  'sachets': (PriceUnit.piece, 1),
  'oeuf': (PriceUnit.piece, 1),
  'oeufs': (PriceUnit.piece, 1),
  'œufs': (PriceUnit.piece, 1),
};

final _number = r'(\d+(?:\.\d+)?)';
final _word = r'([a-zàâäéèêëîïôöùûüçœ]+)';
final _packPattern = RegExp('^$_number\\s*x\\s*$_number\\s*$_word');
final _simplePattern = RegExp('^$_number\\s*$_word');

/// Convertit une contenance en [PackageSize].
///
/// Accepte les formes rencontrées dans l'app : `quantity: 1, unit: 'L'`,
/// `quantity: 500, unit: 'g'`, `quantity: 6, unit: 'x 1.5L'` (pack), ou la
/// chaîne Open Food Facts brute dans [unit] (`'6 x 1,5 L'`, `'33 cl'`).
/// Retourne `null` si la contenance est absente ou illisible.
PackageSize? parsePackageSize(double? quantity, String? unit) {
  final rawUnit = unit?.trim() ?? '';
  String text;
  if (RegExp(r'\d').hasMatch(rawUnit)) {
    // L'unité porte elle-même une contenance (« x 1.5L », « 6 x 1,5 L »)
    final startsWithMultiplier = RegExp(r'^[x×*]', caseSensitive: false).hasMatch(rawUnit);
    text = startsWithMultiplier && quantity != null ? '${formatAmount(quantity)} $rawUnit' : rawUnit;
  } else {
    if (quantity == null || rawUnit.isEmpty) return null;
    text = '${formatAmount(quantity)} $rawUnit';
  }

  text = text
      .toLowerCase()
      .replaceAll(',', '.')
      .replaceAll(RegExp(r'[×*]'), 'x')
      // Symboles avant le nombre (« ℮ 500 g », « env. 1 kg »)
      .replaceFirst(RegExp(r'^[^\d]+'), '')
      .trim();

  final pack = _packPattern.firstMatch(text);
  if (pack != null) {
    final count = double.parse(pack.group(1)!);
    final size = _toPackageSize(double.parse(pack.group(2)!), pack.group(3)!);
    return size == null ? null : PackageSize(count * size.amount, size.unit);
  }

  final simple = _simplePattern.firstMatch(text);
  if (simple != null) {
    return _toPackageSize(double.parse(simple.group(1)!), simple.group(2)!);
  }
  return null;
}

PackageSize? _toPackageSize(double amount, String unitWord) {
  final conversion = _units[unitWord];
  if (conversion == null) return null;
  return PackageSize(amount * conversion.$2, conversion.$1);
}

/// Nombre sans « .0 » inutile (1.0 → « 1 », 1.5 → « 1.5 »)
String formatAmount(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toString();
}

/// Contenance d'une ligne de ticket de caisse.
///
/// [count] est le nombre d'articles achetés (lu sur le ticket) et
/// [packQuantity]/[packUnit] la contenance d'un article (Open Food Facts).
/// Plusieurs articles deviennent un pack (`6` + `x 1.5 L`) pour que le prix
/// de la ligne, qui est un total, se ramène correctement au kg ou au litre.
({double? quantity, String? unit}) ticketLineQuantity({
  required double count,
  double? packQuantity,
  String? packUnit,
}) {
  final unit = packUnit?.trim();
  if (unit == null || unit.isEmpty) return (quantity: count, unit: 'unité');
  if (count <= 1) return (quantity: packQuantity, unit: unit);
  if (packQuantity != null && !RegExp(r'\d').hasMatch(unit)) {
    return (quantity: count, unit: 'x ${formatAmount(packQuantity)} $unit');
  }
  // Contenance déjà composée (« 6 x 1,5 L ») : on ne peut pas l'empiler
  return (quantity: packQuantity, unit: unit);
}
