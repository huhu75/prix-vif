# Architecture — Application de scan alimentaire (Flutter)

## Vue d'ensemble

Application mobile Flutter permettant de scanner des tickets de caisse ou des codes barres de produits alimentaires, enrichis via Open Food Facts.

---

## Deux flux principaux

```
Appareil photo Flutter
        │
        ├──── [ticket de caisse] ──► Photo HD → compression → Mistral AI (vision)
        │                                            │
        │                                    Extraction JSON des articles
        │                                            │
        │                                    Open Food Facts (recherche par nom)
        │                                            │
        │                              Confirmation utilisateur (UI de matching)
        │                                            │
        └──── [code barre] ──────► mobile_scanner (détection temps réel)
                                             │
                                     Saisie du prix (Flutter UI)
                                             │
                                  Open Food Facts (lookup par EAN exact)
                                             │
                                  ───────────┴───────────
                                             │
                                   Stockage local (SQLite / Hive)
```

---

## Étapes d'implémentation

### Étape 1 — Fondations Flutter (sans API)

**Objectif :** faire tourner le squelette complet avant de brancher quoi que ce soit.

- [x] **Étape 1a — Dépendances & Configuration** :
  - [x] Ajouter `image_picker` (capture du ticket) et `image` (compression d'image) dans `pubspec.yaml`
  - [x] Configurer les permissions caméra et galerie sur iOS (`Info.plist`) et Android (`AndroidManifest.xml`)
- [x] **Étape 1b — Flux Saisie de Prix (Code-barres)** :
  - [x] Mettre le scanner en pause lors du scan d'un EAN
  - [x] Afficher un dialogue / bottom sheet demandant la saisie du prix (clavier numérique)
  - [x] Ajouter l'article à la liste avec le prix réel saisi, puis relancer le scanner
- [x] **Étape 1c — Interface bi-mode & Capture du Ticket** :
  - [x] Créer une bascule dans `scan_screen.dart` entre le mode "Code-barres" et le mode "Ticket"
  - [x] En mode Ticket, ajouter un bouton de capture avec `image_picker`
  - [x] Afficher l'aperçu du ticket pris en photo dans l'UI
- [x] **Étape 1d — Compression locale de l'image** :
  - [x] Intégrer une fonction utilitaire pour compresser l'image du ticket (max 1024px, JPEG 80%)
  - [x] Afficher à l'écran les gains de taille (Ko originaux vs Ko compressés)

**Critère de validation :** photo prise et compressée, EAN scanné avec demande de saisie du prix, le tout en local (sans appel réseau).

---

### Étape 2 — Flux code barre → Open Food Facts

**Objectif :** valider la plomberie réseau avec l'API la plus simple (gratuite, matching exact).

- [x] **Étape 2a — Service Client API Open Food Facts** :
  - [x] Créer `OpenFoodFactsService` pour appeler le endpoint de lookup EAN (`GET https://world.openfoodfacts.org/api/v2/product/{ean}`)
  - [x] Extraire les champs utiles : `product_name`, `brands`, `nutriscore_grade`, `categories`, `image_url`
  - [x] Gérer le parsing du JSON et les erreurs réseau (retourner un objet ou `null`)
- [x] **Étape 2b — Intégration du lookup EAN dans le flux de scan** :
  - [x] Lors du scan, afficher un loader de chargement API ("Recherche du produit...")
  - [x] Appeler le service `OpenFoodFactsService` avec l'EAN scanné
  - [x] En cas de succès, afficher la boîte de dialogue de saisie du prix enrichie avec les données réelles du produit (nom, marque, image)
  - [x] En cas d'échec (produit non trouvé ou pas de réseau), utiliser un fallback propre (nom générique, marque inconnue) tout en conservant l'EAN
- [x] **Étape 2c — Interface de Résultats enrichie** :
  - [x] S'assurer que le modèle `ScannedItem` et l'affichage des listes de résultats (ex: sur la fiche produit) prennent bien en compte et affichent les images réelles d'Open Food Facts et les grades Nutri-Score correspondants.

**Critère de validation :** scan EAN → affichage loader → fiche produit OFF résolue → saisie du prix → sauvegarde locale avec métadonnées réelles.

---

### Étape 3 — Stockage local (socle minimal) ⬅️ TERMINÉE

> ⚠️ Cette étape a été implémentée avant l'étape 4 (Mistral) afin que le flux ticket ait un endroit fiable où persister ses données dès le départ. L'étape 4 s'intégrera directement dans ce pipeline sans refactoring.

**Objectif :** mettre en place le schéma de base et la couche de persistance, avec UI d'analyse complète.

- [x] **Étape 3a — Choix et initialisation de la base** :
  - [x] Choix : **Hive** (NoSQL, simplicité, pas de code generation nécessaire)
  - [x] Ajouté `hive: ^2.2.3`, `hive_flutter: ^1.1.0`, `path_provider: ^2.1.1` dans `pubspec.yaml`
  - [x] Initialisation Hive dans `main()` via `Hive.initFlutter()` + `WidgetsFlutterBinding.ensureInitialized()`
- [x] **Étape 3b — Schéma de données** :
  - [x] `StoredScan` (box `scans`) : id, date, endDate, type (`ticket` | `barcode`), storeName, totalAmount
  - [x] `StoredArticle` (box `articles`) : toutes les propriétés de ScannedItem + `scanId` (clé étrangère vers le scan parent)
  - [x] `CachedProduct` (box `products_cache`) : cache des fiches OFF (clé = EAN, champs : productName, brands, nutriscoreGrade, imageUrl, categories, cachedAt)
  - [x] Modèles définis dans `lib/models/hive_models.dart` avec sérialisation Map (pas de TypeAdapter/build_runner)
  - [x] Ajout du champ `type` dans `ScanSession` pour distinguer code-barres et ticket
- [x] **Étape 3c — Couche Repository** :
  - [x] `ScanRepository` créé dans `lib/services/scan_repository.dart`
  - [x] Méthodes : `saveScan()`, `getAllScans()`, `deleteScan()`, `clearAllScans()`, `saveArticle()`, `getArticlesForScan()`
  - [x] Méthodes cache : `getCachedProduct()`, `cacheProduct()`, `hasProductInCache()`
  - [x] Sauvegarde branchée sur le flux code-barre : chaque session sauvegardée est persistée via `_repository.saveScan()`
  - [x] Suppression et vidage de l'historique persistés via `_repository.deleteScan()` / `clearAllScans()`
  - [x] Cache OFF intégré dans `OpenFoodFactsService` : lookup cache-first, mise en cache automatique après chaque appel API réussi
  - [x] Chargement automatique des sessions persistées au démarrage de l'app (fallback données démo si première utilisation)
  - [x] Transmission du type de scan (barcode/ticket) depuis ScanScreen via callback `onScanTypeChanged`
- [x] **Étape 3d — UI de liste basique** :
  - [x] Afficher la liste des scans passés (date, type, nombre d'articles) avec badge de type
  - [x] Afficher le détail d'un scan (articles, prix, Nutri-Score si disponible) avec badge de type
  - [x] Mise à jour de `history_screen.dart` et `session_detail_screen.dart` avec affichage du type

**Critère de validation :** ✅ un article scanné via code-barre est persisté et visible dans la liste après redémarrage de l'app.

---

### Étape 4 — Flux ticket → Mistral AI → Open Food Facts

> ⚠️ Partie la plus coûteuse en crédits — à optimiser avant de tester en production.
> Le stockage (étape 3) étant en place, chaque extraction Mistral est immédiatement persistée, ce qui permet de rejouer et déboguer sans re-consommer de crédits.

#### 4a. Préparation de l'image (côté Flutter, avant envoi) ✅ **TERMINÉE**

**Objectif :** réduire la taille de l'image de 60 à 80% pour limiter les tokens vision (et donc les coûts Mistral).

- [x] **4a.1 — Créer un utilitaire dédié** :
  - Nouveau fichier : `lib/utils/image_utils.dart`
  - Classe `ImagePreparationResult` + fonction `prepareImageForMistral(XFile)`
- [x] **4a.2 — Redimensionnement** :
  - Utiliser `image.decodeImage()` + `copyResize(width: 1024)` (conserver le ratio hauteur/largeur)
  - **Ne pas dépasser 1024px de large** (hauteur ajustée automatiquement)
- [x] **4a.3 — Compression JPEG** :
  - Formater en JPEG avec **qualité à 80%** (`format: Format.jpeg, quality: 80`)
  - Vérifier que la taille en octets est bien inférieure à l'original
- [x] **4a.4 — Encodage Base64** :
  - Encoder le résultat final en base64 pour l'envoi HTTP
- [x] **4a.5 — Validation et métriques** :
  - Afficher dans l'UI : "Image compressée de **X Ko → Y Ko** (réduction de Z%)"
  - Loguer en debug : taille avant/après + ratio de réduction
  - **Critère de validation :** réduction ≥ 60% (sinon, journaliser un warning)
- [x] **4a.6 — Gestion des erreurs** :
  - Cas à gérer : fichier corrompu, format non supporté, mémoire insuffisante
  - Retourner un message utilisateur clair (ex: "Échec de compression, veuillez réessayer")
- [x] **4a.7 — Intégration dans le flux** :
  - Appeler `prepareImageForMistral` **immédiatement après la capture** (dans `scan_screen.dart`)
  - **Ne pas autoriser l'envoi à Mistral** si `prepareImageForMistral` retourne un échec
- [x] **4a.8 — Tests unitaires** :
  - Fichier : `test/utils/image_utils_test.dart`
  - 9 tests couvrant : images > 1024px, < 1024px, corrompues, vérification réduction ≥ 60%

#### 4b. Appel Mistral AI ✅ **TERMINÉE**

- [x] **Modèle recommandé** : `pixtral-12b-2409` (déjà configuré dans `MistralService`)
- [x] **Prompt JSON structuré** :
  ```
  Extrais les articles de ce ticket de caisse.
  Réponds UNIQUEMENT avec un JSON valide, sans markdown, sans explication.
  Format attendu : {"articles": [{"nom": "...", "prix": 0.00, "quantite": 1}]}
  ```
- [x] **Parser JSON directement** via `jsonDecode` (évite le parsing de texte libre)
- [x] **Persister JSON brut** avant matching OFF :
  - Nouveau modèle : `StoredMistralExtraction` (dans `hive_models.dart`)
  - Nouvelle box Hive : `mistral_extractions`
  - Méthodes dans `ScanRepository` : `saveMistralExtraction`, `getMistralExtraction`, etc.
  - Intégration dans `scan_screen.dart` : persistance automatique avant le matching OFF
  - Modification de `MistralService.extractArticles` : retourne maintenant `MistralExtractionResult` (contenant `articles` + `rawJson`)

#### 4c. Matching Open Food Facts par nom

- [x] Endpoint : `GET https://world.openfoodfacts.org/cgi/search.pl?search_terms={nom}&json=1`
- [x] Vérifier d'abord le cache `produits` (étape 3b) avant tout appel réseau
- [x] Stratégie en deux passes :
  1. Recherche avec le nom complet → prendre le premier résultat si pertinent
  2. Si échec : retirer les mots génériques (kg, g, %, bio, x2…) et réessayer
- [x] Toujours afficher les candidats dans une UI de confirmation — le matching par nom n'est pas parfait
- [x] Persister les articles matchés via `ScanRepository.saveArticle()`

**Critère de validation :** photo ticket → liste JSON Mistral → produits OFF avec confirmation utilisateur → articles persistés en base.

---

### Étape 5 — UI de résultats complète et analyse

**Objectif :** enrichir l'UI de liste posée à l'étape 3 avec l'analyse nutritionnelle et les tendances.

- [x] **Étape 5a — Fiche produit enrichie** :
  - [x] Afficher Nutri-Score, catégories, image OFF sur la fiche article
- [x] **Étape 5b — Analyse du panier** :
  - [x] Répartition Nutri-Score du panier (A/B/C/D/E en %)
  - [x] Évolution dans le temps (graphique par semaine / mois)
  - [x] Montant total par scan et cumul mensuel
- [x] **Étape 5c — Mode hors-ligne** :
  - [x] Stocker le scan brut (image compressée + JSON Mistral) si pas de réseau
  - [x] Relancer le matching OFF automatiquement au retour de la connexion

**Critère de validation :** tableau de bord avec historique, répartition nutritionnelle et totaux par période.

---

## Dépendances Flutter

| Package | Usage |
|---|---|
| `mobile_scanner` | Scan code barre temps réel |
| `camera` ou `image_picker` | Photo ticket de caisse |
| `image` | Redimensionnement + compression (1d, **4a**) |
| `http` ou `dio` | Appels API REST |
| `sqflite` ou `hive` | Stockage local |

---

## Règles pour limiter les coûts Mistral

1. **Toujours compresser l'image avant envoi** — ne jamais envoyer le fichier original
2. **Mettre en cache les résultats** — si un EAN ou un libellé a déjà été matché, ne pas re-appeler l'API
3. **Persister le JSON brut Mistral** — permet de rejouer le matching OFF sans re-consommer de crédits vision
4. **Utiliser des réponses mockées en développement** — tester le parsing JSON sans consommer de crédits
5. **`mistral-small` en dev, `mistral-medium` en prod** — passer à un modèle supérieur seulement si la qualité d'extraction est insuffisante

---

## APIs externes

| Service | Type | Auth | Doc |
|---|---|---|---|
| Open Food Facts | REST, gratuite | Aucune | https://wiki.openfoodfacts.org/API |
| Mistral AI | REST, payante | Clé API | https://docs.mistral.ai |

---

## Points d'attention

- **Matching par nom (tickets)** : non déterministe — toujours laisser l'utilisateur valider ou corriger
- **Qualité de la photo** : un ticket froissé ou mal éclairé dégradera l'extraction Mistral — prévoir un feedback visuel avant envoi
- **Hors ligne** : prévoir un mode gracieux si pas de réseau (stocker le scan brut et matcher plus tard)
- **Rejouer sans coût** : grâce à la persistance du JSON Mistral brut, un bug de parsing ou de matching peut être corrigé et re-exécuté sans re-appeler l'API vision
- **Compression image (4a)** : toujours valider la réduction de taille avant envoi — une image mal compressée ou trop grande peut coûter cher en tokens vision. **Bloquer l'envoi si la compression échoue**.