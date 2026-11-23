import 'package:flutter_test/flutter_test.dart';
import 'package:prix_vif/utils/product_search.dart';

void main() {
  group('normalizeForSearch', () {
    test('retire accents, majuscules et ponctuation', () {
      expect(normalizeForSearch('Lait Demi-Écrémé'), 'lait demi ecreme');
      expect(normalizeForSearch("  Pâtes  d'Œuf  "), 'pates d oeuf');
      expect(normalizeForSearch('Coca-Cola 1,5L'), 'coca cola 1 5l');
    });
  });

  group('ProductSearchQuery', () {
    bool matches(String query, String name, {String? brand, List<String> stores = const [], String? barcode}) =>
        ProductSearchQuery(query).matches(name: name, brand: brand, stores: stores, barcode: barcode);

    test('sans accent ni majuscule', () {
      expect(matches('pate', 'Pâtes Barilla'), isTrue);
      expect(matches('ECREME', 'Lait demi-écrémé'), isTrue);
    });

    test('mot par mot, dans n\'importe quel ordre, en début de mot', () {
      expect(matches('lait demi', 'Lait demi-écrémé'), isTrue);
      expect(matches('demi lait', 'Lait demi-écrémé'), isTrue);
      expect(matches('lait entier', 'Lait demi-écrémé'), isFalse, reason: 'chaque mot doit correspondre');
    });

    test('cherche aussi dans la marque, les magasins et le code-barres', () {
      expect(matches('lactel', 'Lait demi-écrémé', brand: 'Lactel'), isTrue);
      expect(matches('lidl', 'Lait demi-écrémé', stores: ['Lidl', 'Carrefour']), isTrue);
      expect(matches('3017620', 'Nutella', barcode: '3017620422003'), isTrue);
    });

    test('une faute de frappe dans un mot long', () {
      expect(matches('yahourt', 'Yaourt nature'), isTrue);
      expect(matches('jambom', 'Jambon blanc'), isTrue);
      // Mots courts : pas de tolérance (trop de faux résultats)
      expect(matches('lais', 'Lait'), isFalse);
      expect(matches('xyz', 'Lait'), isFalse);
    });

    test('recherche vide : tout correspond', () {
      expect(ProductSearchQuery('  ').isEmpty, isTrue);
      expect(matches('', 'Lait'), isTrue);
    });

    test('le nom compte plus que la marque ou le magasin, et le début du nom encore plus', () {
      final query = ProductSearchQuery('lait');
      final byName = query.score(name: 'Lait demi-écrémé')!;
      final inName = query.score(name: 'Café au lait')!;
      final byBrand = query.score(name: 'Yaourt', brand: 'Lait de nos régions')!;
      expect(byName, greaterThan(inName));
      expect(inName, greaterThan(byBrand));
    });
  });
}
