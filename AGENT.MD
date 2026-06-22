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

- [ ] Intégration caméra :
  - `camera` ou `image_picker` pour la photo de ticket (haute résolution)
  - `mobile_scanner` pour la détection de code barre en temps réel dans le viewfinder
- [ ] Deux modes bien séparés dans l'UI :
  - bouton "Scanner un code barre"
  - bouton "Photographier un ticket"
- [ ] Saisie du prix pour le flux code barre (`TextField` clavier numérique)
- [ ] Navigation entre les écrans (résultat, historique)

**Critère de validation :** photo prise, EAN scanné, prix saisi — tout en local, zéro appel réseau.

---

### Étape 2 — Flux code barre → Open Food Facts

**Objectif :** valider la plomberie réseau avec l'API la plus simple (gratuite, matching exact).

- Endpoint : `GET https://world.openfoodfacts.org/api/v2/product/{ean}`
- Pas de clé API requise
- Champs utiles : `product_name`, `nutriscore_grade`, `categories`, `image_url`, `brands`
- Stocker localement : nom, Nutri-Score, catégories, prix saisi, date du scan

**Critère de validation :** scan EAN → fiche produit → sauvegarde locale.

---

### Étape 3 — Flux ticket → Mistral AI → Open Food Facts

> ⚠️ Partie la plus coûteuse en crédits — à optimiser avant de tester en production.

#### 3a. Préparation de l'image (côté Flutter, avant envoi)

- Redimensionner à **1024px de large maximum** (package `image`)
- Compresser en **JPEG à 80%**
- Encoder en base64 pour l'envoi à l'API
- Objectif : réduire la taille de 60 à 80% pour limiter les tokens vision

#### 3b. Appel Mistral AI

- Modèle recommandé : `mistral-small-latest` (vision) — ne pas utiliser `large` en dev
- Prompt à forcer en sortie JSON structurée :

```
Extrais les articles de ce ticket de caisse.
Réponds UNIQUEMENT avec un JSON valide, sans markdown, sans explication.
Format attendu :
{"articles": [{"nom": "...", "prix": 0.00, "quantite": 1}]}
```

- Parser la réponse JSON directement — évite tout parsing de texte libre

#### 3c. Matching Open Food Facts par nom

- Endpoint : `GET https://world.openfoodfacts.org/cgi/search.pl?search_terms={nom}&json=1`
- Stratégie en deux passes :
  1. Recherche avec le nom complet → prendre le premier résultat si pertinent
  2. Si échec : retirer les mots génériques (kg, g, %, bio, x2…) et réessayer
- Toujours afficher les candidats dans une UI de confirmation — le matching par nom n'est pas parfait

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