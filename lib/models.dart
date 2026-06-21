// Modele pour un article scanne
class ScannedItem {
  final String id;
  final String name;
  final String? brand;
  final double price;
  final String? currency;
  final double? quantity;
  final String? unit;
  final DateTime scanDate;
  final String? imageUrl;
  final String? barcode;

  ScannedItem({
    required this.id,
    required this.name,
    this.brand,
    required this.price,
    this.currency = '€',
    this.quantity,
    this.unit,
    required this.scanDate,
    this.imageUrl,
    this.barcode,
  });

  // Donnees fake pour la demo
  static List<ScannedItem> get demoItems => [
    ScannedItem(
      id: '1',
      name: 'Lait Demi-Ecreme',
      brand: 'Candia',
      price: 1.49,
      quantity: 1,
      unit: 'L',
      scanDate: DateTime.now(),
      barcode: '3008360001234',
      imageUrl: 'https://via.placeholder.com/150x150/E6F3FF/000000?text=Lait',
    ),
    ScannedItem(
      id: '2',
      name: 'Pain de Mie',
      brand: 'Brioche Dore',
      price: 2.99,
      quantity: 500,
      unit: 'g',
      scanDate: DateTime.now().subtract(const Duration(hours: 1)),
      barcode: '3017620422003',
      imageUrl: 'https://via.placeholder.com/150x150/FFF8E1/000000?text=Pain',
    ),
    ScannedItem(
      id: '3',
      name: 'Eau Minerale',
      brand: 'Evian',
      price: 0.89,
      quantity: 1.5,
      unit: 'L',
      scanDate: DateTime.now().subtract(const Duration(days: 1)),
      barcode: '3029330014567',
      imageUrl: 'https://via.placeholder.com/150x150/E0F7FA/000000?text=Eau',
    ),
    ScannedItem(
      id: '4',
      name: 'Cafe Moulu',
      brand: 'Nescafe',
      price: 4.50,
      quantity: 250,
      unit: 'g',
      scanDate: DateTime.now().subtract(const Duration(days: 2)),
      barcode: '7613033597471',
      imageUrl: 'https://via.placeholder.com/150x150/8B4513/FFFFFF?text=Cafe',
    ),
  ];

  String get formattedPrice => '${price.toStringAsFixed(2)} ${currency ?? '€'}';
  String get formattedQuantity => quantity != null ? '$quantity $unit' : '';
}

// Modele de session de scan
class ScanSession {
  final String id;
  final List<ScannedItem> items;
  final DateTime date;
  final DateTime? endDate;

  String get name => 'Session du ${date.day}/${date.month}/${date.year}';

  double get totalAmount => items.fold(0, (sum, item) => sum + item.price);

  ScanSession({
    required this.id,
    required this.items,
    required this.date,
    this.endDate,
  });

  // Donnees fake pour la demo
  static List<ScanSession> get demoSessions => [
    ScanSession(
      id: '20260620_001',
      items: [
        ScannedItem(
          id: '1',
          name: 'Lait Demi-Ecreme UHT',
          brand: 'Candia',
          price: 1.49,
          quantity: 1,
          unit: 'L',
          scanDate: DateTime.now().subtract(const Duration(days: 2, hours: 10)),
          barcode: '3008360001234',
          imageUrl: 'https://via.placeholder.com/150x150/E6F3FF/000000?text=🥛',
        ),
        ScannedItem(
          id: '2',
          name: 'Pain de Mie Brioche',
          brand: 'Brioche Dore',
          price: 2.99,
          quantity: 500,
          unit: 'g',
          scanDate: DateTime.now().subtract(const Duration(days: 2, hours: 10, minutes: 5)),
          barcode: '3017620422003',
          imageUrl: 'https://via.placeholder.com/150x150/FFF8E1/000000?text=🍞',
        ),
        ScannedItem(
          id: '3',
          name: 'Beurre Doux',
          brand: 'President',
          price: 3.49,
          quantity: 250,
          unit: 'g',
          scanDate: DateTime.now().subtract(const Duration(days: 2, hours: 10, minutes: 10)),
          barcode: '3046920024657',
          imageUrl: 'https://via.placeholder.com/150x150/FFFBEB/000000?text=🧈',
        ),
      ],
      date: DateTime.now().subtract(const Duration(days: 2, hours: 10)),
      endDate: DateTime.now().subtract(const Duration(days: 2, hours: 9, minutes: 30)),
    ),
    ScanSession(
      id: '20260618_002',
      items: [
        ScannedItem(
          id: '4',
          name: 'Eau Minerale',
          brand: 'Evian',
          price: 0.89,
          quantity: 6,
          unit: 'x 1.5L',
          scanDate: DateTime.now().subtract(const Duration(days: 4, hours: 14)),
          barcode: '3029330014567',
          imageUrl: 'https://via.placeholder.com/150x150/E0F7FA/000000?text=💧',
        ),
        ScannedItem(
          id: '5',
          name: 'Coca-Cola',
          brand: 'Coca-Cola',
          price: 2.49,
          quantity: 2,
          unit: 'L',
          scanDate: DateTime.now().subtract(const Duration(days: 4, hours: 14, minutes: 5)),
          barcode: '3599990000000',
          imageUrl: 'https://via.placeholder.com/150x150/FF0000/FFFFFF?text=🥤',
        ),
      ],
      date: DateTime.now().subtract(const Duration(days: 4, hours: 14)),
      endDate: DateTime.now().subtract(const Duration(days: 4, hours: 13, minutes: 45)),
    ),
    ScanSession(
      id: '20260615_003',
      items: [
        ScannedItem(
          id: '6',
          name: 'Pates',
          brand: 'Barilla',
          price: 1.89,
          quantity: 500,
          unit: 'g',
          scanDate: DateTime.now().subtract(const Duration(days: 7, hours: 18)),
          barcode: '8008688003586',
          imageUrl: 'https://via.placeholder.com/150x150/FFF8E1/000000?text=🍝',
        ),
        ScannedItem(
          id: '7',
          name: 'Sauce Tomate',
          brand: 'Carrefour',
          price: 0.99,
          quantity: 500,
          unit: 'g',
          scanDate: DateTime.now().subtract(const Duration(days: 7, hours: 18, minutes: 3)),
          barcode: '3560070460303',
          imageUrl: 'https://via.placeholder.com/150x150/FF6B35/FFFFFF?text=🍅',
        ),
        ScannedItem(
          id: '8',
          name: 'Fromage Rape',
          brand: 'Emmental',
          price: 2.79,
          quantity: 200,
          unit: 'g',
          scanDate: DateTime.now().subtract(const Duration(days: 7, hours: 18, minutes: 6)),
          barcode: '3228857000000',
          imageUrl: 'https://via.placeholder.com/150x150/FFFF00/000000?text=🧀',
        ),
        ScannedItem(
          id: '9',
          name: 'Jambon Blanc',
          brand: 'Fleurie',
          price: 3.99,
          quantity: 100,
          unit: 'g',
          scanDate: DateTime.now().subtract(const Duration(days: 7, hours: 18, minutes: 9)),
          barcode: '3256220000000',
          imageUrl: 'https://via.placeholder.com/150x150/FFC0CB/000000?text=🍖',
        ),
      ],
      date: DateTime.now().subtract(const Duration(days: 7, hours: 18)),
      endDate: DateTime.now().subtract(const Duration(days: 7, hours: 17, minutes: 40)),
    ),
  ];
}
