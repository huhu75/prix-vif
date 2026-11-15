import 'package:flutter_test/flutter_test.dart';
import 'package:prix_vif/utils/product_type_utils.dart';

void main() {
  group('productTypeOf', () {
    test('retourne la catégorie la plus spécifique (dernier élément)', () {
      expect(
        productTypeOf(['Foods', 'Beverages', 'Milks']),
        'Milks',
      );
    });

    test('retourne la seule catégorie si une seule est présente', () {
      expect(productTypeOf(['Snacks']), 'Snacks');
    });

    test('retourne null si la liste est null', () {
      expect(productTypeOf(null), isNull);
    });

    test('retourne null si la liste est vide', () {
      expect(productTypeOf([]), isNull);
    });

    test('ignore les catégories vides ou espaces', () {
      expect(productTypeOf(['Foods', ' ', '']), 'Foods');
      expect(productTypeOf(['', '   ']), isNull);
    });
  });

  group('productTypeLabel', () {
    test('retourne le type quand des catégories existent', () {
      expect(
        productTypeLabel(['Foods', 'Biscuits']),
        'Biscuits',
      );
    });

    test('retombe sur le label par défaut sans catégorie', () {
      expect(productTypeLabel(null), uncategorizedTypeLabel);
      expect(productTypeLabel([]), uncategorizedTypeLabel);
    });
  });

  group('isCategorized', () {
    test('true quand une catégorie existe', () {
      expect(isCategorized(['Milks']), isTrue);
    });

    test('false sans catégorie', () {
      expect(isCategorized(null), isFalse);
      expect(isCategorized([]), isFalse);
    });
  });
}
