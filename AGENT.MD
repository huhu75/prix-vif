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

### Étape 3 — Flux ticket → Mistral AI → Open Food Facts

> ⚠️ Partie la plus coûteuse en crédits — à optimiser avant de tester en production.

#### 3a. Préparation de l'image (côté Flutter, avant envoi)

- [x] Redimensionner à **1024px de large maximum** (package `image`)
- [x] Compresser en **JPEG à 80%**
- [x] Encoder en base64 pour l'envoi à l'API
- [x] Objectif : réduire la taille de 60 à 80% pour limiter les tokens vision

#### 3b. Appel Mistral AI

- [x] Modèle recommandé : `mistral-small-latest` (vision) ou `pixtral-12b-2409`
- [x] Prompt à forcer en sortie JSON structurée :

```
Extrais les articles de ce ticket de caisse.
Réponds UNIQUEMENT avec un JSON valide, sans markdown, sans explication.
Format attendu :
{"articles": [{"nom": "...", "prix": 0.00, "quantite": 1}]}
```

- [x] Parser la réponse JSON directement — évite tout parsing de texte libre

#### 3c. Matching Open Food Facts par nom

- [x] Endpoint : `GET https://world.openfoodfacts.org/cgi/search.pl?search_terms={nom}&json=1`
- [x] Stratégie en deux passes :
  1. Recherche avec le nom complet → prendre le premier résultat si pertinent
  2. Si échec : retirer les mots génériques (kg, g, %, bio, x2…) et réessayer
- [x] Toujours afficher les candidats dans une UI de confirmation — le matching par nom n'est pas parfait

**Critère de validation :** photo ticket → liste JSON Mistral → produits OFF avec confirmation utilisateur.

---

### Étape 4 — Stockage local et UI de résultats

- **Base de données locale :** SQLite (`sqflite`) ou Hive (plus simple, NoSQL)
- Tables / collections à prévoir :
  - `scans` : date, type (ticket | barcode), montant total
  - `articles` : nom brut (ticket), produit OFF associé, prix, quantité
  - `produits` : cache des fiches OFF déjà récupérées (évite les doublons API)
- UI résultats : Nutri-Score, catégories, analyse du panier dans le temps

---

## Dépendances Flutter

| Package | Usage |
|---|---|
| `mobile_scanner` | Scan code barre temps réel |
| `camera` ou `image_picker` | Photo ticket de caisse |
| `image` | Redimensionnement + compression avant envoi |
| `http` ou `dio` | Appels API REST |
| `sqflite` ou `hive` | Stockage local |

---

## Règles pour limiter les coûts Mistral

1. **Toujours compresser l'image avant envoi** — ne jamais envoyer le fichier original
2. **Mettre en cache les résultats** — si un EAN ou un libellé a déjà été matché, ne pas re-appeler l'API
3. **Utiliser des réponses mockées en développement** — tester le parsing JSON sans consommer de crédits
4. **`mistral-small` en dev, `mistral-medium` en prod** — passer à un modèle supérieur seulement si la qualité d'extraction est insuffisante

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