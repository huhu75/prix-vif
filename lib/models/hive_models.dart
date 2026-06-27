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

// Table `mistral_extractions` : JSON brut retourné par Mistral AI pour un ticket
// Permet de rejouer le matching OFF sans re-consommer de crédits
class StoredMistralExtraction {
  final String id; // ID unique de l'extraction
  final String scanId; // Référence au StoredScan parent
  final String rawJson; // JSON brut retourné par Mistral
  final DateTime extractedAt;
  final String? imageBase64; // Optionnel : image compressée utilisée pour l'extraction

  StoredMistralExtraction({
    required this.id,
    required this.scanId,
    required this.rawJson,
    required this.extractedAt,
    this.imageBase64,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'scanId': scanId,
    'rawJson': rawJson,
    'extractedAt': extractedAt.toIso8601String(),
    'imageBase64': imageBase64,
  };

  factory StoredMistralExtraction.fromMap(Map<dynamic, dynamic> map) => StoredMistralExtraction(
    id: map['id'] as String,
    scanId: map['scanId'] as String,
    rawJson: map['rawJson'] as String,
    extractedAt: DateTime.parse(map['extractedAt'] as String),
    imageBase64: map['imageBase64'] as String?,
  );
}

// Étape 5c — Table `pending_offline_scans` : scans en attente de matching OFF (hors-ligne)
class PendingOfflineScan {
  final String id; // ID unique
  final String? scanId; // Référence optionnelle à un StoredScan
  final String? imageBase64; // Image compressée du ticket
  final String? rawMistralJson; // JSON brut de Mistral si déjà extrait
  final DateTime createdAt;
  final bool isMistralExtracted; // Si l'extraction Mistral a été faite
  
  PendingOfflineScan({
    required this.id,
    this.scanId,
    this.imageBase64,
    this.rawMistralJson,
    required this.createdAt,
    this.isMistralExtracted = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'scanId': scanId,
    'imageBase64': imageBase64,
    'rawMistralJson': rawMistralJson,
    'createdAt': createdAt.toIso8601String(),
    'isMistralExtracted': isMistralExtracted,
  };

  factory PendingOfflineScan.fromMap(Map<dynamic, dynamic> map) => PendingOfflineScan(
    id: map['id'] as String,
    scanId: map['scanId'] as String?,
    imageBase64: map['imageBase64'] as String?,
    rawMistralJson: map['rawMistralJson'] as String?,
    createdAt: DateTime.parse(map['createdAt'] as String),
    isMistralExtracted: map['isMistralExtracted'] as bool? ?? false,
  );
}
