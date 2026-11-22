import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Modèle pour un article extrait d'un ticket par Mistral AI
class ExtractedArticle {
  final String name;
  final double price;
  final double quantity;

  ExtractedArticle({
    required this.name,
    required this.price,
    required this.quantity,
  });

  factory ExtractedArticle.fromJson(Map<String, dynamic> json) {
    return ExtractedArticle(
      name: json['nom']?.toString() ?? 'Article inconnu',
      price: double.tryParse(json['prix']?.toString() ?? '0.0') ?? 0.0,
      quantity: double.tryParse(json['quantite']?.toString() ?? '1.0') ?? 1.0,
    );
  }
}

/// Résultat de l'extraction Mistral avec JSON brut pour persistance
class MistralExtractionResult {
  final List<ExtractedArticle> articles;
  final String rawJson;
  final bool isMock;

  MistralExtractionResult({
    required this.articles,
    required this.rawJson,
    this.isMock = false,
  });
}

/// Service d'interaction avec l'API Mistral Vision
class MistralService {
  // Clé API Mistral : fournie à la compilation via --dart-define=MISTRAL_API_KEY=... (hors dépôt git),
  // ou saisie dans l'UI (stockée localement dans Hive, utilisée en fallback).
  static String? apiKey = const String.fromEnvironment('MISTRAL_API_KEY').isNotEmpty
      ? const String.fromEnvironment('MISTRAL_API_KEY')
      : null;

  // Modèle vision : Mistral Small 4 (mars 2026), vision native via /v1/chat/completions.
  // pixtral-12b-2409 est retiré par Mistral depuis le 2025-12-31.
  static const String _model = 'mistral-small-latest';
  static const String _baseUrl = 'https://api.mistral.ai/v1/chat/completions';

  /// Analyse l'image du ticket (JPEG compressé en bytes) pour en extraire la liste des articles
  /// Retourne le résultat avec les articles parsés ET le JSON brut pour persistance
  Future<MistralExtractionResult> extractArticles(Uint8List imageBytes) async {
    final key = apiKey?.trim() ?? '';
    
    // Mode mock si pas de clé API (pour développement sans frais)
    if (key.isEmpty) {
      return _extractArticlesMock();
    }

    try {
      final base64Image = base64Encode(imageBytes);
      final dataUri = 'data:image/jpeg;base64,$base64Image';

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $key',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'text',
                  'text': '''Analyse cette image de ticket de caisse et extrais UNIQUEMENT la liste des articles/produits achetés de manière individuelle.

Directives STRICTES :
1. Extrais SEULEMENT les articles/produits achetés : aliments, boissons, mais aussi produits d'entretien (lessive, liquide vaisselle...), d'hygiène et de beauté.
2. Ignore COMPLETEMENT :
   - Le nom, adresse et métadonnées du magasin.
   - Les totaux, sous-totaux, nets à payer, cumuls.
   - La TVA et toutes les lignes de taxes.
   - Les modes de paiement (CARTE BANCAIRE, ESPECES, detail transaction CB, rendu monnaie).
   - Les remises globales, bons d'achat, coupons (ex: BON D'ACHAT, REMISE -10%).
   - Les points de fidélité et messages promotionnels.
3. Pour chaque article :
   - "nom" : Nettoie le libellé pour qu'il soit propre et lisible (retire les préfixes type étoiles (*), les codes internes du magasin, les codes-barres écrits). Écris les abréviations du ticket en toutes lettres quand le sens est sûr (ex : "LESS LIQ" → "Lessive liquide", "VAISS" → "Vaisselle", "CHOC" → "Chocolat") et garde la marque telle quelle (ex : "MIR", "Ariel", "Nutella").
   - "prix" : Le prix total payé de la ligne pour cet article (après réductions spécifiques à cet article, le cas échéant), sous forme de nombre décimal (ex: 1.49).
   - "quantite" : Le nombre d'unités achetées (par défaut 1.0).

Réponds UNIQUEMENT avec un JSON valide sous la forme suivante, sans bloc de code markdown (pas de ```json), sans explications :
{"articles": [{"nom": "...", "prix": 0.00, "quantite": 1}]}''',
                },
                {
                  'type': 'image_url',
                  'image_url': dataUri,
                }
              ]
            }
          ],
          'response_format': {
            'type': 'json_object',
          }
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        final String content = body['choices']?[0]?['message']?['content'] ?? '';
        
        if (content.isNotEmpty) {
          var cleaned = content.trim();
          // Retirer d'éventuelles fences markdown ```json ... ``` autour du JSON
          if (cleaned.startsWith('```')) {
            cleaned = cleaned
                .replaceFirst(RegExp(r'^```[a-zA-Z]*\s*'), '')
                .replaceFirst(RegExp(r'\s*```$'), '')
                .trim();
          }
          final Map<String, dynamic> parsedJson = jsonDecode(cleaned);
          final List<dynamic>? articlesJson = parsedJson['articles'];
          
          // Parsing des articles
          final articles = articlesJson != null
              ? articlesJson.map((a) => ExtractedArticle.fromJson(a)).toList().cast<ExtractedArticle>()
              : <ExtractedArticle>[];
          
          // Retourner le résultat avec le JSON brut pour persistance
          return MistralExtractionResult(
            articles: articles,
            rawJson: content,
            isMock: false,
          );
        }
      }
      
      throw Exception('Erreur Mistral API (${response.statusCode}): ${response.body}');
    } catch (e) {
      print('Erreur Mistral Service: $e');
      rethrow;
    }
  }

  /// Simulation d'extraction pour le développement local
  Future<MistralExtractionResult> _extractArticlesMock() async {
    // Simuler le délai réseau de l'IA (2 secondes)
    await Future.delayed(const Duration(milliseconds: 1800));

    // JSON brut simulé (format attendu par l'API)
    const rawJson = '''
    {
      "articles": [
        {"nom": "Lait Candia Demi Ecreme", "prix": 1.49, "quantite": 1},
        {"nom": "Nutella 400g", "prix": 3.89, "quantite": 1},
        {"nom": "Evian eau minerale", "prix": 0.89, "quantite": 6},
        {"nom": "Coca-Cola Canette 33cl", "prix": 0.79, "quantite": 4}
      ]
    }
    ''';

    final articles = [
      ExtractedArticle(name: 'Lait Candia Demi Ecreme', price: 1.49, quantity: 1),
      ExtractedArticle(name: 'Nutella 400g', price: 3.89, quantity: 1),
      ExtractedArticle(name: 'Evian eau minerale', price: 0.89, quantity: 6),
      ExtractedArticle(name: 'Coca-Cola Canette 33cl', price: 0.79, quantity: 4),
    ];

    return MistralExtractionResult(
      articles: articles,
      rawJson: rawJson,
      isMock: true,
    );
  }
}
