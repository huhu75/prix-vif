import 'package:flutter_test/flutter_test.dart';
import 'package:prix_vif/analytics/analytics.dart';
import 'package:prix_vif/models.dart';
import 'package:prix_vif/models/product_category.dart';
import 'package:prix_vif/services/open_food_facts_service.dart';
import 'package:prix_vif/utils/unit_price.dart';

final _day = DateTime(2026, 11, 10);

ScannedItem _juice(String id, String ean, String name, String brand, double price, String store,
        {double? liters = 1, int day = 0}) =>
    ScannedItem(
      id: id,
      name: name,
      brand: brand,
      price: price,
      quantity: liters,
      unit: liters == null ? null : 'L',
      scanDate: _day.add(Duration(days: day)),
      barcode: ean,
      storeName: store,
    );

const _appleJuice = ProductCategory(id: 'en:apple-juices', label: 'Jus de pomme');

void main() {
  group('ProductCategory', () {
    test('catégorie créée à la main : identifiant « perso: » sans accents', () {
      final category = ProductCategory.custom('  Jus de Pomme Pressé ');
      expect(category.id, 'perso:jus-de-pomme-presse');
      expect(category.label, 'Jus de Pomme Pressé');
      expect(category.manual, isTrue);
    });

    test('libellé tiré de l\'identifiant quand le nom français est inconnu', () {
      expect(humanizeCategoryId('en:apple-juices'), 'Apple juices');
      expect(humanizeCategoryId('fr:jus-de-pomme'), 'Jus de pomme');
    });

    test('aller-retour Hive', () {
      final back = ProductCategory.fromMap(_appleJuice.asManual().toMap());
      expect(back, _appleJuice);
      expect(back.label, 'Jus de pomme');
      expect(back.manual, isTrue);
    });
  });

  group('OFFProduct.comparedCategoryOf', () {
    test('compared_to_category d\'abord, sinon la dernière catégorie « en: »', () {
      expect(OFFProduct.comparedCategoryOf({'compared_to_category': 'en:apple-juices'}), 'en:apple-juices');
      expect(
        OFFProduct.comparedCategoryOf({
          'categories_tags': ['en:beverages', 'en:fruit-juices', 'es:jus-de-fruits'],
        }),
        'en:fruit-juices',
      );
      expect(OFFProduct.comparedCategoryOf({}), isNull);
    });

    test('fromJson lit la catégorie de comparaison', () {
      final product = OFFProduct.fromJson('123', {
        'product': {'product_name': 'Jus de pomme', 'compared_to_category': 'en:apple-juices'},
      });
      expect(product.categoryId, 'en:apple-juices');
    });
  });

  group('CategoryGroup', () {
    // Jus de pomme : A 1 L à 1.80 € (Carrefour) et 1.60 € (Leclerc), B 1.5 L à 1.95 € (1.30 €/L),
    // C sans contenance ; un jus d'orange dans une autre catégorie
    final sessions = [
      ScanSession(id: 's', date: _day, items: [
        _juice('1', 'a', 'Pur jus de pomme', 'Marque A', 1.80, 'Carrefour'),
        _juice('2', 'a', 'Pur jus de pomme', 'Marque A', 1.60, 'Leclerc'),
        _juice('3', 'b', 'Jus de pomme', 'Marque B', 1.95, 'Leclerc', liters: 1.5),
        _juice('4', 'c', 'Jus de pomme vrac', 'Marque C', 0.90, 'Monoprix', liters: null),
        _juice('5', 'o', 'Jus d\'orange', 'Marque O', 1.20, 'Carrefour'),
      ]),
    ];
    final categories = {
      'bc_a': _appleJuice,
      'bc_b': _appleJuice,
      'bc_c': _appleJuice,
      'bc_o': const ProductCategory(id: 'en:orange-juices', label: 'Jus d\'orange'),
    };

    test('toutes les marques et tous les magasins, du moins cher au plus cher au litre', () {
      final group = CategoryGroup.forCategory('en:apple-juices', sessions, categories)!;
      expect(group.unit, PriceUnit.liter);
      expect(group.productCount, 3);
      expect(group.storeCount, 3);
      // B 1.30 €/L, A Leclerc 1.60 €/L, A Carrefour 1.80 €/L, puis C (contenance inconnue)
      expect(group.offers.map((o) => '${o.productKey}@${o.storeName}'),
          ['bc_b@Leclerc', 'bc_a@Leclerc', 'bc_a@Carrefour', 'bc_c@Monoprix']);
      expect(group.cheapest!.productKey, 'bc_b');
      expect(group.isComparable(group.offers.last), isFalse);
    });

    test('équivalent moins cher au litre (un autre produit)', () {
      final group = CategoryGroup.forCategory('en:apple-juices', sessions, categories)!;
      final equivalent = group.cheaperEquivalentThan('bc_a', const UnitPrice(1.60, PriceUnit.liter));
      expect(equivalent!.productKey, 'bc_b');
      // Le moins cher au litre n'a pas d'équivalent moins cher
      expect(group.cheaperEquivalentThan('bc_b', const UnitPrice(1.30, PriceUnit.liter)), isNull);
    });

    test('un groupe par catégorie, par libellé', () {
      expect(CategoryGroup.calculate(sessions, categories).map((g) => g.category.label),
          ['Jus d\'orange', 'Jus de pomme']);
    });
  });

  group('PriceAdvice', () {
    final sessions = [
      ScanSession(id: 's1', date: _day, items: [
        _juice('1', 'a', 'Pur jus de pomme', 'Marque A', 1.80, 'Carrefour'),
        _juice('2', 'a', 'Pur jus de pomme', 'Marque A', 1.60, 'Leclerc'),
        _juice('3', 'b', 'Jus de pomme', 'Marque B', 1.95, 'Leclerc', liters: 1.5),
      ]),
    ];
    final categories = {'bc_a': _appleJuice, 'bc_b': _appleJuice};

    PriceAdvice advise(String store, {double? price, String key = 'bc_a'}) => PriceAdvice.calculate(
          sessions: sessions,
          categories: categories,
          productKey: key,
          store: store,
          price: price,
          quantity: 1,
          unit: 'L',
        );

    test('déconseillé dès qu\'un autre magasin est moins cher, même d\'un centime', () {
      final advice = advise('Carrefour', price: 1.61);
      expect(advice.verdict, AdviceVerdict.discouraged);
      expect(advice.cheaperElsewhere!.storeName, 'Leclerc');
      expect(advice.savingElsewhere, closeTo(0.01, 0.0001));
    });

    test('recommandé quand aucun autre magasin n\'est moins cher', () {
      expect(advise('Carrefour', price: 1.60).verdict, AdviceVerdict.recommended);
      expect(advise('Leclerc').verdict, AdviceVerdict.recommended);
    });

    test('sans prix saisi, le dernier prix relevé dans ce magasin sert de base', () {
      final advice = advise('Carrefour');
      expect(advice.price, 1.80);
      expect(advice.priceIsLastKnown, isTrue);
      expect(advice.verdict, AdviceVerdict.discouraged);
    });

    test('magasin jamais vu et pas de prix : pas encore de comparaison', () {
      final advice = advise('Monoprix');
      expect(advice.verdict, AdviceVerdict.unknown);
      expect(advice.bestElsewhere!.storeName, 'Leclerc');
    });

    test('produit jamais vu ailleurs : pas encore de comparaison', () {
      final advice = PriceAdvice.calculate(
        sessions: sessions,
        categories: categories,
        productKey: 'bc_nouveau',
        store: 'Carrefour',
        price: 2.00,
      );
      expect(advice.verdict, AdviceVerdict.unknown);
      expect(advice.otherStoreCount, 0);
    });

    test('propose l\'équivalent moins cher au litre de la catégorie', () {
      final advice = advise('Leclerc', price: 1.60);
      expect(advice.category, _appleJuice);
      expect(advice.cheaperEquivalent!.productKey, 'bc_b');
      expect(advice.unitPrice!.value, closeTo(1.60, 0.001));
    });

    test('catégorie fournie pour un produit en cours de scan', () {
      final advice = PriceAdvice.calculate(
        sessions: sessions,
        categories: const {},
        productKey: 'bc_nouveau',
        store: 'Carrefour',
        price: 2.10,
        quantity: 1,
        unit: 'L',
        category: _appleJuice,
      );
      expect(advice.category, _appleJuice);
      expect(advice.cheaperEquivalent, isNull, reason: 'les autres produits n\'ont pas encore de catégorie');
    });
  });
}
