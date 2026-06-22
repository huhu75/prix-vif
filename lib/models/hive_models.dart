// ===================================================

// ===================================================
// Modèles Hive pour la persistance locale
// ===================================================

// Étape 3b — Schéma de données
// Table `produits` : cache des fiches OFF (clé = EAN)
class CachedProduct {
  final String ean;
  final String productName;
  final String? brands;
  final String? nutriscoreGrade;
  final String? imageUrl;
  final List<String>? categories;
  final DateTime cachedAt;

  CachedProduct({
    required this.ean,
    required this.productName,
    this.brands,
    this.nutriscoreGrade,
    this.imageUrl,
    this.categories,
    required this.cachedAt,
  });

  Map<String, dynamic> toMap() => {
    'ean': ean,
    'productName': productName,
    'brands': brands,
    'nutriscoreGrade': nutriscoreGrade,
    'imageUrl': imageUrl,
    'categories': categories,
    'cachedAt': cachedAt.toIso8601String(),
  };

  factory CachedProduct.fromMap(Map<dynamic, dynamic> map) => CachedProduct(
    ean: map['ean'] as String,
    productName: map['productName'] as String,
    brands: map['brands'] as String?,
    nutriscoreGrade: map['nutriscoreGrade'] as String?,
    imageUrl: map['imageUrl'] as String?,
    categories: (map['categories'] as List?)?.cast<String>(),
    cachedAt: DateTime.parse(map['cachedAt'] as String),
  );
}

// Table `articles` : article scanné persisté
class StoredArticle {
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
  final String? storeName;
  final String? nutriscore;
  final List<String>? categories;
  final String scanId; // référence au scan parent

  StoredArticle({
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
    this.storeName,
    this.nutriscore,
    this.categories,
    required this.scanId,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'brand': brand,
    'price': price,
    'currency': currency,
    'quantity': quantity,
    'unit': unit,
    'scanDate': scanDate.toIso8601String(),
    'imageUrl': imageUrl,
    'barcode': barcode,
    'storeName': storeName,
    'nutriscore': nutriscore,
    'categories': categories,
    'scanId': scanId,
  };

  factory StoredArticle.fromMap(Map<dynamic, dynamic> map) => StoredArticle(
    id: map['id'] as String,
    name: map['name'] as String,
    brand: map['brand'] as String?,
    price: (map['price'] as num).toDouble(),
    currency: map['currency'] as String? ?? '€',
    quantity: (map['quantity'] as num?)?.toDouble(),
    unit: map['unit'] as String?,
    scanDate: DateTime.parse(map['scanDate'] as String),
    imageUrl: map['imageUrl'] as String?,
    barcode: map['barcode'] as String?,
    storeName: map['storeName'] as String?,
    nutriscore: map['nutriscore'] as String?,
    categories: (map['categories'] as List?)?.cast<String>(),
    scanId: map['scanId'] as String,
  );
}

// Table `scans` : session de scan persistée
class StoredScan {
  final String id;
  final DateTime date;
  final DateTime? endDate;
  final String type; // 'ticket' | 'barcode'
  final String? storeName;
  final double totalAmount;

  StoredScan({
    required this.id,
    required this.date,
    this.endDate,
    required this.type,
    this.storeName,
    required this.totalAmount,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'date': date.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'type': type,
    'storeName': storeName,
    'totalAmount': totalAmount,
  };

  factory StoredScan.fromMap(Map<dynamic, dynamic> map) => StoredScan(
    id: map['id'] as String,
    date: DateTime.parse(map['date'] as String),
    endDate: map['endDate'] != null ? DateTime.parse(map['endDate'] as String) : null,
    type: map['type'] as String,
    storeName: map['storeName'] as String?,
    totalAmount: (map['totalAmount'] as num).toDouble(),
  );
}
