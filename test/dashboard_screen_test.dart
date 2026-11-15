import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prix_vif/screens/dashboard_screen.dart';
import 'package:prix_vif/models.dart';
import 'package:prix_vif/models/product_analysis_models.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR', null);
  });

  testWidgets('DashboardScreen renders without crashing', (WidgetTester tester) async {
    final sessions = ScanSession.demoSessions;
    await tester.pumpWidget(MaterialApp(
      home: DashboardScreen(
        sessions: sessions,
        onSessionSelected: (_) {},
      ),
    ));
    expect(find.byKey(const ValueKey('dashboard_scaffold')), findsOneWidget);
  });

  testWidgets('Dashboard affiche la comparaison par type de produit', (WidgetTester tester) async {
    final now = DateTime.now();
    final sessions = [
      ScanSession(
        id: 'type_test_1',
        date: now,
        type: 'barcode',
        items: [
          ScannedItem(
            id: 'a1',
            name: 'Lait Demi-Ecreme',
            brand: 'Candia',
            price: 1.50,
            scanDate: now,
            categories: ['Foods', 'Beverages', 'Milks'],
          ),
          ScannedItem(
            id: 'a2',
            name: 'Lait Entier',
            brand: 'Candia',
            price: 1.70,
            scanDate: now,
            categories: ['Foods', 'Beverages', 'Milks'],
          ),
          ScannedItem(
            id: 'a3',
            name: 'Pain de Mie',
            brand: 'Brioche Dore',
            price: 2.99,
            scanDate: now,
            categories: ['Foods', 'Breads'],
          ),
        ],
      ),
    ];

    await tester.pumpWidget(MaterialApp(
      home: DashboardScreen(
        sessions: sessions,
        onSessionSelected: (_) {},
      ),
    ));

    // La section est présente avec les types issus d'Open Food Facts
    expect(find.text('Comparaison par type de produit'), findsOneWidget);
    expect(find.text('Milks'), findsOneWidget);
    expect(find.text('Breads'), findsOneWidget);
    // Prix moyen du type Milks = (1.50 + 1.70) / 2 = 1.60
    expect(find.text('1.60 €/article'), findsOneWidget);
    expect(find.text('2.99 €/article'), findsOneWidget);
  });

  testWidgets('Dashboard affiche les articles non catégorisés à part', (WidgetTester tester) async {
    final now = DateTime.now();
    final sessions = [
      ScanSession(
        id: 'type_test_2',
        date: now,
        type: 'barcode',
        items: [
          ScannedItem(
            id: 'b1',
            name: 'Produit sans catégorie',
            price: 3.0,
            scanDate: now,
          ),
        ],
      ),
    ];

    await tester.pumpWidget(MaterialApp(
      home: DashboardScreen(
        sessions: sessions,
        onSessionSelected: (_) {},
      ),
    ));

    expect(find.text('Comparaison par type de produit'), findsOneWidget);
    expect(find.text('1 article non catégorisé'), findsOneWidget);
  });

  test('ProductPriceEvolutionItem.calculate calcule hausses, baisses et stabilités', () {
    final t0 = DateTime(2026, 11, 1, 10);
    final t1 = DateTime(2026, 11, 5, 10);
    final sessions = [
      ScanSession(
        id: 's1',
        date: t0,
        type: 'barcode',
        items: [
          ScannedItem(
            id: 'p1_0',
            name: 'Café Moulu',
            brand: 'Carte Noire',
            barcode: '300000000001',
            price: 3.50,
            scanDate: t0,
          ),
          ScannedItem(
            id: 'p2_0',
            name: 'Lait Bio',
            brand: 'Lactel',
            barcode: '300000000002',
            price: 1.80,
            scanDate: t0,
          ),
          ScannedItem(
            id: 'p3_0',
            name: 'Biscuits',
            barcode: '300000000003',
            price: 2.00,
            scanDate: t0,
          ),
        ],
      ),
      ScanSession(
        id: 's2',
        date: t1,
        type: 'barcode',
        items: [
          // Café en hausse (+0.50€)
          ScannedItem(
            id: 'p1_1',
            name: 'Café Moulu',
            brand: 'Carte Noire',
            barcode: '300000000001',
            price: 4.00,
            scanDate: t1,
          ),
          // Lait en baisse (-0.20€)
          ScannedItem(
            id: 'p2_1',
            name: 'Lait Bio',
            brand: 'Lactel',
            barcode: '300000000002',
            price: 1.60,
            scanDate: t1,
          ),
          // Biscuits stables
          ScannedItem(
            id: 'p3_1',
            name: 'Biscuits',
            barcode: '300000000003',
            price: 2.00,
            scanDate: t1,
          ),
        ],
      ),
    ];

    final evolutions = ProductPriceEvolutionItem.calculate(sessions);
    expect(evolutions.length, 3);

    final cafe = evolutions.firstWhere((e) => e.name == 'Café Moulu');
    expect(cafe.latestPrice, 4.00);
    expect(cafe.firstPrice, 3.50);
    expect(cafe.priceDiff, closeTo(0.50, 0.001));
    expect(cafe.trend, PriceTrend.up);
    expect(cafe.trend.label, 'Hausse');

    final lait = evolutions.firstWhere((e) => e.name == 'Lait Bio');
    expect(lait.latestPrice, 1.60);
    expect(lait.priceDiff, closeTo(-0.20, 0.001));
    expect(lait.trend, PriceTrend.down);
    expect(lait.trend.label, 'Baisse');

    final biscuits = evolutions.firstWhere((e) => e.name == 'Biscuits');
    expect(biscuits.latestPrice, 2.00);
    expect(biscuits.priceDiff, closeTo(0.0, 0.001));
    expect(biscuits.trend, PriceTrend.stable);
    expect(biscuits.trend.label, 'Stable');
  });

  testWidgets('Dashboard affiche la section Évolution des prix des produits et navigue au clic',
      (WidgetTester tester) async {
    final t0 = DateTime(2026, 11, 1);
    final t1 = DateTime(2026, 11, 8);
    final sessions = [
      ScanSession(
        id: 's_evo_1',
        date: t0,
        type: 'barcode',
        items: [
          ScannedItem(
            id: 'c1',
            name: 'Chocolat Noir',
            brand: 'Lindt',
            barcode: '300000999999',
            price: 2.50,
            scanDate: t0,
          ),
        ],
      ),
      ScanSession(
        id: 's_evo_2',
        date: t1,
        type: 'barcode',
        items: [
          ScannedItem(
            id: 'c2',
            name: 'Chocolat Noir',
            brand: 'Lindt',
            barcode: '300000999999',
            price: 2.90,
            scanDate: t1,
          ),
        ],
      ),
    ];

    String? selectedProductId;
    String? selectedProductName;
    int? selectedTab;

    await tester.pumpWidget(MaterialApp(
      home: DashboardScreen(
        sessions: sessions,
        onSessionSelected: (_) {},
        onProductSelected: (id, name, {int initialTabIndex = 0}) {
          selectedProductId = id;
          selectedProductName = name;
          selectedTab = initialTabIndex;
        },
      ),
    ));

    // Vérifier la présence de la section
    expect(find.text('Évolution des prix des produits'), findsOneWidget);
    expect(find.text('Chocolat Noir'), findsOneWidget);
    expect(find.text('2.90 €'), findsOneWidget);
    expect(find.textContaining('+0.40 €'), findsOneWidget);

    // Cliquer sur la carte produit
    await tester.tap(find.text('Chocolat Noir'));
    await tester.pump();

    expect(selectedProductId, '300000999999');
    expect(selectedProductName, 'Chocolat Noir');
    expect(selectedTab, 1); // Onglet 1 = Évolution
  });

  test('ProductStoreComparisonItem.calculate identifie magasin le moins cher et écart', () {
    final t0 = DateTime(2026, 11, 2);
    final sessions = [
      ScanSession(
        id: 'sess_leclerc',
        date: t0,
        type: 'barcode',
        storeName: 'Leclerc',
        items: [
          ScannedItem(
            id: 'm1',
            name: 'Pâte à Tartiner',
            brand: 'Nocciolata',
            barcode: '8001234567890',
            price: 3.20,
            scanDate: t0,
            storeName: 'Leclerc',
          ),
        ],
      ),
      ScanSession(
        id: 'sess_monoprix',
        date: t0,
        type: 'barcode',
        storeName: 'Monoprix',
        items: [
          ScannedItem(
            id: 'm2',
            name: 'Pâte à Tartiner',
            brand: 'Nocciolata',
            barcode: '8001234567890',
            price: 4.10,
            scanDate: t0,
            storeName: 'Monoprix',
          ),
        ],
      ),
    ];

    final comparisons = ProductStoreComparisonItem.calculate(sessions);
    expect(comparisons.length, 1);

    final item = comparisons.first;
    expect(item.name, 'Pâte à Tartiner');
    expect(item.cheapestStore, 'Leclerc');
    expect(item.cheapestPrice, 3.20);
    expect(item.mostExpensiveStore, 'Monoprix');
    expect(item.mostExpensivePrice, 4.10);
    expect(item.priceDiff, closeTo(0.90, 0.001));
    expect(item.savingPercent, closeTo(21.95, 0.1));
    expect(item.hasPriceDifference, isTrue);
  });

  testWidgets('Dashboard affiche le Comparateur multi-magasins et navigue vers l\'onglet Magasins',
      (WidgetTester tester) async {
    final t0 = DateTime(2026, 11, 2);
    final sessions = [
      ScanSession(
        id: 's_comp_1',
        date: t0,
        type: 'barcode',
        items: [
          ScannedItem(
            id: 'n1',
            name: 'Jus d\'Orange',
            brand: 'Tropicana',
            barcode: '300000777777',
            price: 2.10,
            scanDate: t0,
            storeName: 'Lidl',
          ),
        ],
      ),
      ScanSession(
        id: 's_comp_2',
        date: t0,
        type: 'barcode',
        items: [
          ScannedItem(
            id: 'n2',
            name: 'Jus d\'Orange',
            brand: 'Tropicana',
            barcode: '300000777777',
            price: 2.70,
            scanDate: t0,
            storeName: 'Carrefour',
          ),
        ],
      ),
    ];

    String? tappedId;
    String? tappedName;
    int? tappedTab;

    await tester.pumpWidget(MaterialApp(
      home: DashboardScreen(
        sessions: sessions,
        onSessionSelected: (_) {},
        onProductSelected: (id, name, {int initialTabIndex = 0}) {
          tappedId = id;
          tappedName = name;
          tappedTab = initialTabIndex;
        },
      ),
    ));

    expect(find.text('Comparateur multi-magasins'), findsOneWidget);
    expect(find.text('Jus d\'Orange'), findsWidgets);
    expect(find.text('Lidl'), findsWidgets);
    expect(find.text('2.10 €'), findsWidgets);
    expect(find.text('Carrefour'), findsWidgets);
    expect(find.text('2.70 €'), findsWidgets);
    expect(find.textContaining('-0.60 €'), findsOneWidget);

    // Tap sur la carte comparative
    final storeTarget = find.text('Lidl').first;
    await tester.ensureVisible(storeTarget);
    await tester.tap(storeTarget);
    await tester.pump();

    expect(tappedId, '300000777777');
    expect(tappedName, 'Jus d\'Orange');
    expect(tappedTab, 2); // Onglet 2 = Magasins
  });

  test('ProductRecommendationItem.calculate suggère une alternative moins chère dans un autre magasin', () {
    final t0 = DateTime(2026, 11, 3);
    final sessions = [
      ScanSession(
        id: 'sess_ref',
        date: t0,
        type: 'barcode',
        storeName: 'Carrefour',
        items: [
          ScannedItem(
            id: 'ref_lait',
            name: 'Lait Candia Demi-Écrémé',
            brand: 'Candia',
            barcode: '300000111111',
            price: 1.49,
            scanDate: t0,
            storeName: 'Carrefour',
            categories: ['Foods', 'Beverages', 'Milks'],
          ),
        ],
      ),
      ScanSession(
        id: 'sess_alt',
        date: t0,
        type: 'barcode',
        storeName: 'Leclerc',
        items: [
          ScannedItem(
            id: 'alt_lait',
            name: 'Lait Marque Repère Demi-Écrémé',
            brand: 'Marque Repère',
            barcode: '300000222222',
            price: 1.09,
            scanDate: t0,
            storeName: 'Leclerc',
            categories: ['Foods', 'Beverages', 'Milks'],
          ),
        ],
      ),
    ];

    final recommendations = ProductRecommendationItem.calculate(sessions);
    expect(recommendations.length, 1);

    final rec = recommendations.first;
    expect(rec.referenceProductName, 'Lait Candia Demi-Écrémé');
    expect(rec.referenceStore, 'Carrefour');
    expect(rec.referencePrice, 1.49);
    expect(rec.alternativeProductName, 'Lait Marque Repère Demi-Écrémé');
    expect(rec.alternativeStore, 'Leclerc');
    expect(rec.alternativePrice, 1.09);
    expect(rec.category, 'Milks');
    expect(rec.savingAmount, closeTo(0.40, 0.001));
    expect(rec.savingPercent, closeTo(26.84, 0.1));
    expect(rec.hasSaving, isTrue);
  });

  test('ProductRecommendationItem.calculate détecte les équivalences par mot-clé sans catégories', () {
    final t0 = DateTime(2026, 11, 3);
    final sessions = [
      ScanSession(
        id: 'sess_carrefour_pain',
        date: t0,
        type: 'barcode',
        storeName: 'Carrefour',
        items: [
          ScannedItem(
            id: 'pain_cher',
            name: 'Pain de Mie Brioché',
            brand: 'Brioche Dorée',
            barcode: '300000333333',
            price: 2.99,
            scanDate: t0,
            storeName: 'Carrefour',
          ),
        ],
      ),
      ScanSession(
        id: 'sess_aldi_pain',
        date: t0,
        type: 'barcode',
        storeName: 'Aldi',
        items: [
          ScannedItem(
            id: 'pain_eco',
            name: 'Pain de Mie Nature',
            brand: 'Aldi',
            barcode: '300000444444',
            price: 1.69,
            scanDate: t0,
            storeName: 'Aldi',
          ),
        ],
      ),
    ];

    final recommendations = ProductRecommendationItem.calculate(sessions);
    expect(recommendations.length, 1);
    final rec = recommendations.first;
    expect(rec.referenceProductName, 'Pain de Mie Brioché');
    expect(rec.alternativeProductName, 'Pain de Mie Nature');
    expect(rec.category, 'Pain');
    expect(rec.savingAmount, closeTo(1.30, 0.001));
  });

  testWidgets('Dashboard affiche les Alternatives moins chères et navigue vers l\'onglet Similaires',
      (WidgetTester tester) async {
    final t0 = DateTime(2026, 11, 4);
    final sessions = [
      ScanSession(
        id: 'sess_sim_1',
        date: t0,
        type: 'barcode',
        items: [
          ScannedItem(
            id: 'c1',
            name: 'Café Moulu Premium',
            brand: 'Carte Noire',
            barcode: '300000555555',
            price: 3.80,
            scanDate: t0,
            storeName: 'Monoprix',
            categories: ['Foods', 'Beverages', 'Coffees'],
          ),
        ],
      ),
      ScanSession(
        id: 'sess_sim_2',
        date: t0,
        type: 'barcode',
        items: [
          ScannedItem(
            id: 'c2',
            name: 'Café Moulu Classique',
            brand: 'Grand Mère',
            barcode: '300000666666',
            price: 2.60,
            scanDate: t0,
            storeName: 'Leclerc',
            categories: ['Foods', 'Beverages', 'Coffees'],
          ),
        ],
      ),
    ];

    String? tappedId;
    String? tappedName;
    int? tappedTab;

    await tester.pumpWidget(MaterialApp(
      home: DashboardScreen(
        sessions: sessions,
        onSessionSelected: (_) {},
        onProductSelected: (id, name, {int initialTabIndex = 0}) {
          tappedId = id;
          tappedName = name;
          tappedTab = initialTabIndex;
        },
      ),
    ));

    expect(find.text('Alternatives moins chères'), findsOneWidget);
    expect(find.text('Prenez '), findsOneWidget);
    expect(find.text('Café Moulu Classique'), findsWidgets);
    expect(find.text('2.60 €'), findsWidgets);
    expect(find.textContaining('Au lieu de Café Moulu Premium'), findsOneWidget);
    expect(find.textContaining('-1.20 €'), findsOneWidget);

    // Tap sur la carte de recommandation
    final target = find.text('Prenez ').first;
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pump();

    expect(tappedId, '300000555555');
    expect(tappedName, 'Café Moulu Premium');
    expect(tappedTab, 3); // Onglet 3 = Similaires
  });

  testWidgets('Dashboard compare les enseignes par type de produit et permet la bascule par enseigne',
      (WidgetTester tester) async {
    final t0 = DateTime(2026, 11, 5);
    final sessions = [
      ScanSession(
        id: 'sess_mat_leclerc',
        date: t0,
        type: 'barcode',
        storeName: 'Leclerc',
        items: [
          ScannedItem(
            id: 'm_lait',
            name: 'Lait Écrémé',
            price: 1.15,
            scanDate: t0,
            storeName: 'Leclerc',
            categories: ['Foods', 'Beverages', 'Milks'],
          ),
        ],
      ),
      ScanSession(
        id: 'sess_mat_carrefour',
        date: t0,
        type: 'barcode',
        storeName: 'Carrefour',
        items: [
          ScannedItem(
            id: 'c_lait',
            name: 'Lait Entier',
            price: 1.55,
            scanDate: t0,
            storeName: 'Carrefour',
            categories: ['Foods', 'Beverages', 'Milks'],
          ),
        ],
      ),
    ];

    await tester.pumpWidget(MaterialApp(
      home: DashboardScreen(
        sessions: sessions,
        onSessionSelected: (_) {},
      ),
    ));

    // Section présente avec comparatif enseignes
    expect(find.text('Comparaison par type de produit'), findsOneWidget);
    expect(find.text('Par type de produit'), findsOneWidget);
    expect(find.text('Par enseigne'), findsOneWidget);

    // Comparatif enseignes visible pour Milks
    final compEnseignes = find.textContaining('Comparatif enseignes (2)');
    await tester.ensureVisible(compEnseignes);
    expect(compEnseignes, findsOneWidget);
    expect(find.textContaining('Écart : 0.40 €/art'), findsOneWidget);

    // Basculer vers la vue "Par enseigne"
    final byStoreChip = find.text('Par enseigne');
    await tester.ensureVisible(byStoreChip);
    await tester.tap(byStoreChip);
    await tester.pump();

    // Vérifier les cartes par magasin avec distinctions
    expect(find.text('Leclerc'), findsWidgets);
    expect(find.text('Carrefour'), findsWidgets);
    expect(find.textContaining('Moins cher sur : Milks'), findsOneWidget);
  });
}
