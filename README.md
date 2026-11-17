# Prix Vif - Scanner de Prix Moderne 2026

<img src="https://img.shields.io/badge/Flutter-3.19+-02569B?style=for-the-badge&logo=flutter" alt="Flutter">
<img src="https://img.shields.io/badge/Dart-3.0+-0175C2?style=for-the-badge&logo=dart" alt="Dart">
<img src="https://img.shields.io/badge/Platform-Android%20%7C%20iOS-333333?style=for-the-badge" alt="Platforms">

---

## 📋 Historique des versions

### v1.7.0 — 2026-11-17 — Données corrigeables

- **Ajouté** : modification d'un article enregistré depuis le détail d'une session (nom, prix, quantité, unité, magasin, avec aperçu du prix au kg / L) et suppression avec confirmation (`lib/widgets/article_edit_dialog.dart`) ; une session vidée de son dernier article disparaît
- **Corrigé** : supprimer un article (ou « Tout supprimer ») dans l'onglet Résultats ne le retirait que de l'écran ; il est maintenant supprimé de la base, donc de l'historique et du Dashboard
- **Ajouté** : les magasins ajoutés dans le scanner et le dernier magasin choisi sont conservés après un redémarrage (box `settings`)
- **Ajouté** : bouton « Retirer les données de démo » dans l'Historique, qui ne supprime que les sessions d'exemple
- **Modifié** : la liste de l'onglet Résultats reste alignée sur la base quand un article est modifié ou supprimé ailleurs
- **Ajouté** : tests du dépôt (modification, suppression, magasins, retrait de la démo) et de la fenêtre d'édition (`test/widgets/article_edit_dialog_test.dart`)

### v1.6.0 — 2026-11-17 — Comparaisons au prix au kg / L

- **Ajouté** : prix au kg, au litre ou à l'unité (`lib/utils/unit_price.dart`) calculé depuis la contenance de l'article (`1 L`, `500 g`, packs `6 x 1,5 L`, chaînes Open Food Facts brutes comme `℮ 500 g`)
- **Modifié** : comparatif par type de produit — les enseignes sont classées au kg / L / unité dès que la contenance est connue (leader 🥇, écart et « moins cher sur » inclus) ; la moyenne normalisée du type est affichée avec le nombre d'articles de contenance connue
- **Modifié** : alternatives moins chères comparées à quantité égale quand les deux contenances sont connues (économie calculée sur la quantité du produit de référence) ; plus de recommandation entre un produit de contenance connue et un produit sans contenance, ou entre kg et litre
- **Modifié** : onglet « Similaires » de la fiche produit trié au kg / L, prix normalisé affiché sur chaque produit et sur le moins cher ; prix normalisé affiché sur les cartes d'articles
- **Corrigé** : une ligne de ticket de N articles gardait la contenance d'un seul article (6 bouteilles de 1,5 L comptées comme 1,5 L) ; elle devient un pack `6 x 1.5 L`, aussi lors du rejeu hors-ligne
- **Ajouté** : tests `test/utils/unit_price_test.dart` (lecture des contenances, packs, lignes de ticket, classement des enseignes, recommandations, produits similaires)

### v1.5.5 — 2026-11-17 — Calculs du Dashboard sortis de l'écran

- **Modifié** : calculs du tableau de bord sortis de `dashboard_screen.dart` (3 334 → 2 542 lignes) vers une couche d'analyse indépendante de l'interface `lib/analytics/` : `DashboardStats.fromSessions`, `ProductPriceEvolutionItem`, `ProductStoreComparisonItem`, `ProductRecommendationItem`, statistiques par type et par période
- **Ajouté** : `ProductObservation` (article + identité produit + magasin résolus) et les utilitaires `productKeyOf`, `productIdOf`, `latestByStore`, qui remplacent trois copies de la même logique d'identification
- **Ajouté** : tests `test/analytics/dashboard_stats_test.dart` (identité produit, magasin de repli, totaux par période avec date de référence fixe, statistiques par type)
- **Modifié** : les alternatives moins chères ouvrent la fiche produit avec le même identifiant que les autres sections (EAN, sinon nom)

### v1.5.4 — 2026-11-17 — Suppression des API dépréciées

- **Modifié** : les 105 appels `Color.withOpacity(x)` remplacés par `Color.withValues(alpha: x)` (API dépréciée depuis Flutter 3.27)
- **Modifié** : `ColorScheme` sans `background`/`onBackground` dépréciés (`surface` et `scaffoldBackgroundColor` déjà définis) ; `Matrix4.scale` remplacé par `scaleByDouble` dans le logo animé
- `flutter analyze` : plus aucune dépréciation (137 → 29 infos de style)

### v1.5.3 — 2026-11-17 — Nettoyage du dépôt

- **Supprimé** : `dashboard_fix_report.md`, rapport ponctuel de juillet sur l'écran Dashboard gris (correctif en place depuis, rapport conservé dans l'historique git)
- **Supprimé** : `package-lock.json`, fichier npm vide sans objet dans un projet Flutter
- **Supprimé** : branches obsolètes déjà fusionnées dans `main` (`ai_main_…`, `maj-mag`, `vibe/fix-dashboard-contrast-…` sur `origin`, `vibe/cleanup-dead-code` et `vibe/ticket-mistral-fixes` en local)

### v1.5.2 — 2026-11-17 — Corrections issues de l'état des lieux (Android release, sessions, hors-ligne)

- **Corrigé** : permission `INTERNET` absente du manifeste Android principal → un APK release ne pouvait joindre ni Open Food Facts ni Mistral (seuls les builds debug/profile l'avaient)
- **Corrigé** : le bouton « Enregistrer » laissait dans l'historique des sessions vides (0 article, 0 €) ; `ScanRepository.saveScan` regroupe désormais les articles déjà sauvegardés et supprime les sessions d'origine devenues vides, et les sessions vides existantes sont nettoyées au démarrage
- **Corrigé** : les données de démo revenaient au lancement suivant après « Tout supprimer » ; elles ne sont plus injectées qu'une seule fois (drapeau `demo_seeded` dans la box `settings`)
- **Corrigé** : un ticket scanné hors-ligne était mis en attente une fois par article (N sessions en double au retour du réseau) ; il est maintenant mis en attente une seule fois, sans feuille de confirmation, avec le magasin sélectionné
- **Corrigé** : traitement des scans en attente protégé contre les exécutions simultanées, et un scan en attente sans extraction Mistral n'est plus supprimé sans avoir été traité
- **Corrigé** : deux lignes identiques d'un même ticket recevaient le même `id` et l'une écrasait l'autre en base
- **Corrigé** : le magasin du premier scan n'apparaissait pas dans la liste des produits (`getUniqueProducts`)
- **Ajouté** : tests du dépôt Hive (`test/services/scan_repository_test.dart`)
- **Modifié** : `version` du `pubspec.yaml` alignée sur ce changelog ; sections Structure, Dépendances et Évolution possible du README remises à jour ; règle d'alignement de version ajoutée à `CLAUDE.md`

### v1.5.1 — 2026-11-15 — Données de démo complètes et initialisation Hive

- **Ajouté** : enrichissement complet de `ScanSession.demoSessions` avec catégories Open Food Facts réelles (`Milks`, `Breads`, `Waters`, `Butters`, `Cheeses`, etc.), Nutri-Score, historique de prix et scans croisés multi-enseignes (Carrefour, Leclerc, Monoprix)
- **Corrigé** : persistance automatique des données de démo dans Hive lors du tout premier démarrage (`_loadSessions`), permettant à l'analyse de produit, aux fiches détaillées et aux graphiques de fonctionner immédiatement sans aucun scan préalable
- **Modifié** : nettoyage des logs de débogage obsolètes dans `main.dart`

### v1.5.0 — 2026-11-15 — Comparatif enseignes × types de produits dans le Dashboard (Étape 4/4)

- **Ajouté** : matrice et comparatif inter-magasins directement intégrés dans la section « Comparaison par type de produit »
- **Ajouté** : affichage pour chaque catégorie du classement des enseignes du moins cher au plus cher, mise en avant du magasin leader (🥇) et calcul de l'écart de prix au sein de la catégorie
- **Ajouté** : bascule interactive par vue : « Par type de produit » (avec comparatif enseignes par rayon) et « Par enseigne » (avec identification des catégories où chaque magasin est le plus compétitif)
- **Ajouté** : modèle d'agrégation `_ProductTypeStoreStats` dans `_ProductTypeStats` et suite de tests d'interaction dans `dashboard_screen_test.dart`

### v1.4.0 — 2026-11-15 — Recommandations d'alternatives moins chères dans le Dashboard (Étape 3/4)

- **Ajouté** : section « Alternatives moins chères » directement intégrée sur le Dashboard identifiant proactivement les produits équivalents (même type ou catégorie OFF, ou famille de produit) moins chers repérés dans d'autres enseignes
- **Ajouté** : calcul automatique des gains en euros et en pourcentage d'économie (« Prenez [Produit B] chez [Magasin B] au lieu de [Produit A] chez [Magasin A] : économisez X € »)
- **Ajouté** : navigation directe en 1 clic vers l'onglet « Similaires » de la fiche produit (`ProductDetailScreen` avec `initialTabIndex: 3`)
- **Ajouté** : modèle d'agrégation `ProductRecommendationItem` avec détection d'équivalence intelligente (catégories OFF et mot-clé de produit) et suite de tests unitaires / widgets dans `dashboard_screen_test.dart`

### v1.3.0 — 2026-11-15 — Comparateur multi-magasins dans le Dashboard (Étape 2/4)

- **Ajouté** : section « Comparateur multi-magasins » directement intégrée sur le Dashboard identifiant pour chaque produit scanné dans plusieurs enseignes le magasin le moins cher vs le plus cher
- **Ajouté** : calcul automatique des gains réalisables (écart en euros et en pourcentage d'économie) avec mise en avant du magasin le plus compétitif
- **Ajouté** : navigation directe en 1 clic vers l'onglet « Magasins » de la fiche produit (`ProductDetailScreen` avec `initialTabIndex: 2`)
- **Ajouté** : modèle d'agrégation `ProductStoreComparisonItem` et tests unitaires / widgets associés dans `dashboard_screen_test.dart`

### v1.2.0 — 2026-11-15 — Section Évolution des prix des produits dans le Dashboard (Étape 1/4)

- **Ajouté** : section « Évolution des prix des produits » directement intégrée sur le Dashboard avec calcul automatique des hausses, baisses et stabilités de prix
- **Ajouté** : cartes interactives avec badge de tendance (+X% / -X% / stable), dernier prix, enseigne et nombre de scans
- **Ajouté** : navigation directe en 1 clic depuis le Dashboard vers l'onglet « Évolution » de la fiche produit (`ProductDetailScreen` avec `initialTabIndex: 1`)
- **Ajouté** : modèle d'agrégation `ProductPriceEvolutionItem` et tests unitaires / widgets associés dans `dashboard_screen_test.dart`

### v1.1.0 — 2026-11-15 — Comparaison et filtrage par type de produit (Open Food Facts)

- **Ajouté** : utilitaire `product_type_utils.dart` extrayant le type de produit le plus précis issu de la hiérarchie `categories` Open Food Facts (`Milks`, `Breads`, etc.)
- **Ajouté** : section « Comparaison par type de produit » dans le tableau de bord avec prix moyen par type, fourchette min/max et barre de ratio comparative
- **Ajouté** : barre de filtres horizontaux par type de produit (`ChoiceChip`) dans l'écran de sélection de produits avec recherche étendue aux catégories
- **Ajouté** : suite de tests unitaires et widgets dédiée (`product_type_utils_test.dart`, `product_selection_screen_test.dart`, extension de `dashboard_screen_test.dart`)

### v1.0.3 — 2026-11-14 — Nettoyage du code mort

- **Supprimé** : 16 méthodes/getters jamais appelés dans `ScanRepository` (`getPriceHistory`, `getStorePriceComparison`, `getStoresForProduct`, `getArticlesByStore/ByBarcode/ByProductName`, `deleteMistralExtractionsForScan`, `getMistralExtraction(s)`, `getPendingOfflineScan`, `clearAllPendingOfflineScans`, `hasProductInCache`, `cachedProductCount`, `articleCount`, `mistralExtractionCount`)
- **Supprimé** : champs et animations jamais lus (`_isOnline`, `_buttonScale`, `_scaleAnimation`, `_shimmerAnimation`), variables locales `theme` inutilisées (dashboard, résultats), `_formatDate` dans `price_card.dart`, `ConnectivityService.hasPendingScans()`, `CameraService.hasError`
- **Corrigé** : `@override` injustifié sur `dispose()` de `ConnectivityService`
- `flutter analyze` : 0 warning `unused`/`dead_code` (151 → 143 issues, le reste = dépréciations `withOpacity` préexistantes)

### v1.0.2 — 2026-11-14 — Fix feedback du mode ticket (bouton Analyser bloqué)

- **Corrigé** : en mode ticket, les erreurs (capture, compression, analyse IA) n'étaient affichées nulle part (le bandeau d'erreur n'existait qu'en mode code-barres) → erreur désormais visible en rouge dans la zone ticket
- **Corrigé** : aucun indicateur pendant l'analyse IA du ticket (appel API jusqu'à 60 s) → loader « Analyse du ticket par l'IA... » en overlay
- **Modifié** : le bouton OPTIMISER / ANALYSER (IA) affiche un spinner et est désactivé pendant la compression ou l'analyse, avec guards anti double-clic

### v1.0.1 — 2026-11-14 — Fix modèle Mistral + clé API hors dépôt

- **Corrigé** : `pixtral-12b-2409` est retiré par Mistral depuis le 2025-12-31 (l'appel API échouait même avec une clé valide) → remplacé par `mistral-small-latest` (Mistral Small 4, vision native)
- **Ajouté** : clé API Mistral configurable à la compilation via `--dart-define=MISTRAL_API_KEY=...` — la clé n'est jamais écrite dans le dépôt git (saisie UI/Hive conservée en fallback)
- **Modifié** : timeout de l'appel vision 15 s → 60 s ; parsing JSON rendu robuste aux blocs ```json

### v1.0.0 — 2026-11-14 — Mise en place du versionnage du README

- **Ajouté** : fichier `CLAUDE.md` définissant la règle obligatoire de versionner le README à chaque étape (SemVer + changelog)
- **Ajouté** : cette section `Historique des versions` dans le README (entrée la plus récente en premier)
- **Modifié** : pied de page `Dernière mise à jour` désormais synchronisé avec la dernière entrée de l'historique

---

## 📱 Aperçu

**Prix Vif** est une application Flutter moderne (design 2026) conçue pour scanner des codes-barres et des tickets de caisse afin de récupérer et organiser les informations de prix des produits. 

**✅ Fonctionnalités complètes implémentées :**
- Scanner de codes-barres en temps réel
- Capture et traitement de tickets de caisse
- Intégration Open Food Facts pour les données produits
- Analyse nutritionnelle avec Nutri-Score
- Stockage local persistant avec Hive
- Tableau de bord avec statistiques avancées
- Mode hors-ligne intelligent
- Sauvegarde automatique après chaque scan

---

## ✨ Fonctionnalités

### 🎯 Scanner
- **Caméra réelle** : Accès à la caméra du téléphone/tablette
- Scan de codes-barres en temps réel
- Contrôles de la caméra : flash
- Aperçu des derniers articles scannés
- Interface intuitive avec animation de ligne de détection
- **Mode bi-mode** : Bascule entre scan de code-barres et capture de ticket
- **Saisie de prix** : Après scan d'un code-barres, dialogue modal pour entrer le prix réel
- **Magasins mémorisés** : les magasins ajoutés et le dernier magasin choisi sont conservés entre deux lancements
- **Capture photo** : Photographier un ticket de caisse via la galerie ou la caméra
- **Compression d'image** : Réduction automatique des images à 1024px max, JPEG 80% avec affichage des gains de taille

### 📊 Résultats
- Liste des articles scannés avec cartes modernes
- Statistiques en temps réel : nombre d'articles, total, moyenne
- Sélection multiple pour suppression groupée (les articles supprimés sont aussi retirés de l'historique et du Dashboard)
- « Enregistrer » regroupe les articles de la session courante en une seule session dans l'historique (les scans déjà sauvegardés automatiquement y sont fusionnés, sans laisser de session vide)
- Affichage du total en grand
- **Sauvegarde automatique après chaque scan**

### 📈 Tableau de Bord (Dashboard)
- **Statistiques globales** : nombre total de scans, articles, montant total, moyenne par article
- **Évolution des prix des produits** : suivi des variations (hausses, baisses, stabilités) avec accès direct à la courbe détaillée
- **Comparateur multi-magasins** : identification des écarts de prix inter-enseignes et calcul des économies potentielles par produit
- **Alternatives moins chères** : suggestions proactives de produits équivalents plus économiques repérés dans d'autres enseignes, avec calcul des gains à quantité égale (au kg / L) quand les contenances sont connues
- **Comparaison par type de produit & enseignes** : prix moyen par catégorie OFF, classement des magasins par rayon au kg / L / unité et vue par enseigne mettant en valeur les forces de chaque magasin
- **Prix au kg / L** : chaque article de contenance connue affiche son prix normalisé (ex. `1.49 €/L`), utilisé pour toutes les comparaisons entre produits différents
- **Répartition Nutri-Score** : graphique à barres horizontales avec pourcentages A/B/C/D/E
- **Évolution temporelle** : graphiques hebdomadaires et mensuels des dépenses
- **Totaux par période** : cumul semaine et mois en cours
- **Derniers scans** : aperçu rapide avec navigation vers le détail

### 🕒 Historique
- Liste des sessions de scan précédentes
- Filtres par : récents, montant, nombre d'articles
- Affichage compact avec aperçu des produits
- Détails complets d'une session, avec **correction d'un article** (prix, contenance, magasin) ou suppression en le touchant
- Bouton « Retirer les données de démo » (ne supprime que les sessions d'exemple)
- Suppression individuelle ou totale (les données de démo ne sont injectées qu'au tout premier lancement et ne reviennent pas après « Tout supprimer »)

### 📱 Mode Hors-Ligne
- Détection automatique de la connectivité réseau
- **Stockage des scans** quand pas de réseau (image compressée + JSON Mistral + magasin sélectionné), une seule fois par ticket
- **Traitement automatique** au retour du réseau : matching Open Food Facts et import du ticket sans feuille de confirmation
- Notifications utilisateur pour les scans en attente

---

## 🎨 Design Moderne 2026

### Palette de Couleurs
| Couleur | Code | Utilisation |
|---------|------|-------------|
| **Background Dark** | `#0F172A` | Fond principal |
| **Surface Dark** | `#1E293B` | Surfaces |
| **Primary** | `#00AAFF` | Boutons, accents (Bleu électrique) |
| **Secondary** | `#7C3AED` | Détails secondaires (Violet profond) |
| **Accent** | `#00F5FF` | Accents (Cyan clair) |
| **Error** | `#EF4444` | Messages d'erreur |
| **Warning** | `#F59E0B` | Avertissements |
| **Success** | `#10B981` | Éléments positifs |

### Effets Visuels
- **Glassmorphism** : Cartes avec effet de verre dépoli
- **Gradients** : Dégradés sur les boutons et cartes
- **Animations** : Transitions fluides, ligne de scan animée
- **Ombres** : Ombres lumineuses pour effet futuriste
- **Bordures** : Coins arrondis (20px)

---

## 📦 Prérequis

- [Flutter SDK](https://flutter.dev/docs/get-started/install) **3.19+**
- [Dart SDK](https://dart.dev/get-dart) **3.0+**
- IDE recommandé : Android Studio, VS Code ou IntelliJ IDEA
- Un émulateur ou un appareil physique connecté
- **Android 6.0+** ou **iOS 12+** (pour la caméra)

---

## 🚀 Installation

### 1. Cloner le dépôt

```bash
git clone https://github.com/huhu75/prix-vif.git
cd prix-vif
```

### 2. Installer les dépendances

```bash
flutter pub get
```

### 3. Exécuter l'application

```bash
# Sur un émulateur ou appareil connecté
flutter run

# Sur iOS
flutter run -d iPhone

# Sur Android
flutter run -d emulator-5554

# Build APK pour Android
flutter build apk --release

# Build App Bundle pour Android
flutter build appbundle --release
```

> ⚠️ **Note** : Le web n'est pas supporté avec la caméra réelle. Utilisez `flutter run -d chrome` uniquement pour le design, mais pas pour tester la fonctionnalité caméra.

### 4. Configurer la clé API Mistral (hors dépôt)

L'analyse des tickets de caisse utilise l'API Mistral. La clé ne doit **jamais** être écrite dans le code du dépôt : passe-la à la compilation avec `--dart-define` (elle est alors embarquée dans le binaire uniquement) :

```bash
# Développement
flutter run --dart-define=MISTRAL_API_KEY=sk-...

# Build release
flutter build apk --release --dart-define=MISTRAL_API_KEY=sk-...
```

Sans clé, l'application reste en **mode démo** (articles factices). Alternative : saisir la clé dans l'app (icône engrenage de l'onglet Scanner) — elle est alors stockée localement dans Hive, jamais dans le dépôt.

---

## 📁 Structure du Projet

```
prix_vif/
├── lib/
│   ├── main.dart                     # Point d'entrée + navigation
│   ├── models.dart                  # Modèles de données (ScannedItem, ScanSession)
│   ├── models/hive_models.dart      # Modèles Hive pour persistance
│   ├── models/product_analysis_models.dart # Modèles d'analyse par produit (prix, magasins, similaires)
│   ├── theme.dart                   # Thème moderne 2026
│   │
│   ├── analytics/                   # Calculs d'analyse des prix, sans UI (testables seuls)
│   │   ├── analytics.dart            # Point d'entrée (exports)
│   │   ├── product_observation.dart  # Identité produit, magasin résolu, dernier prix par magasin
│   │   ├── dashboard_stats.dart      # Statistiques globales, par type et par période
│   │   ├── price_evolution.dart      # Évolution des prix par produit
│   │   ├── store_comparison.dart     # Comparateur multi-magasins
│   │   └── recommendations.dart      # Alternatives moins chères
│   │
│   ├── services/
│   │   ├── camera_service.dart      # Service de gestion de la caméra
│   │   ├── scan_repository.dart     # Repository Hive (CRUD scans, articles, cache)
│   │   ├── open_food_facts_service.dart # Service API Open Food Facts
│   │   ├── mistral_service.dart     # Service API Mistral AI (vision)
│   │   └── connectivity_service.dart # Gestion réseau + mode hors-ligne
│   │
│   ├── utils/
│   │   ├── image_utils.dart          # Utilitaires compression d'image
│   │   ├── unit_price.dart           # Contenance → prix au kg / L / unité
│   │   └── product_type_utils.dart   # Type de produit issu des catégories Open Food Facts
│   │
│   ├── screens/
│   │   ├── scan_screen.dart          # Écran scanner (bi-mode: code-barres/ticket)
│   │   ├── results_screen.dart       # Écran résultats
│   │   ├── history_screen.dart       # Écran historique
│   │   ├── session_detail_screen.dart # Détails d'une session
│   │   ├── dashboard_screen.dart     # Tableau de bord avec analyse
│   │   ├── product_selection_screen.dart # Liste des produits scannés (recherche, tri, filtres)
│   │   └── product_detail_screen.dart    # Fiche produit (évolution, magasins, similaires)
│   │
│   └── widgets/
│       ├── price_card.dart           # Cartes produits (avec Nutri-Score et prix au kg / L)
│       ├── article_edit_dialog.dart  # Correction / suppression d'un article enregistré
│       ├── scanner_overlay.dart      # Overlay scanner
│       ├── magic_button.dart         # Boutons animés
│       ├── magic_title.dart          # Titres néon
│       ├── ai_scan_effect.dart       # Effet de scan IA
│       └── logo.dart                  # Logo de l'application
│
├── test/                           # Tests unitaires et widgets (modèles, dépôt Hive, écrans)
├── pubspec.yaml                    # Dépendances Flutter
├── AGENT.md                        # Documentation technique
└── README.md                       # Cette documentation
```

---

## 🛠️ Architecture

### Couche d'analyse
- Les calculs (statistiques, comparaisons, recommandations) vivent dans `lib/analytics/`, sans dépendance à Flutter UI : les écrans ne font qu'afficher leurs résultats

### Gestion d'État
- État local avec `setState`
- Passage de callbacks entre widgets

### Navigation
- `BottomNavigationBar` pour la navigation principale (4 onglets)
- `MaterialPageRoute` pour les détails
- `IndexedStack` pour conserver l'état
- **Synchronisation automatique** entre onglets

### Modèles
- **`ScannedItem`** : Article avec prix, nom, marque, Nutri-Score, catégories, image
- **`ScanSession`** : Session de scan avec liste d'articles, type (barcode/ticket)
- **`StoredScan`** : Modèle Hive pour persistance des sessions
- **`StoredArticle`** : Modèle Hive pour persistance des articles
- **`CachedProduct`** : Cache des produits Open Food Facts
- **`StoredMistralExtraction`** : JSON brut des extractions Mistral
- **`PendingOfflineScan`** : Scans en attente de traitement hors-ligne

### Persistance
- **Hive NoSQL** : Stockage local rapide et efficace
- **6 boxes** : scans, articles, products_cache, mistral_extractions, pending_offline_scans, settings (clé API Mistral, drapeau des données de démo, magasins ajoutés, magasin sélectionné)
- **Synchronisation temps réel** : Rechargement automatique après chaque modification

---

## 🎯 Utilisation

### 📱 Scanner un code-barres
1. Lancez l'application sur votre appareil Android/iOS
2. Autorisez l'accès à la caméra
3. Sélectionnez le mode **CODE-BARRES** (bascule en haut de l'écran)
4. Pointez la caméra vers un code-barres
5. Le code est scanné automatiquement
6. **Intégration Open Food Facts** : L'application récupère automatiquement les informations du produit (nom, marque, Nutri-Score, catégories, image)
7. Un dialogue s'ouvre : entrez le **prix réel** du produit
8. **✅ Sauvegarde automatique** : L'article est immédiatement persisté en base et apparaît dans le Dashboard

### 📸 Capturer un ticket de caisse
1. Sélectionnez le mode **TICKET** (bascule en haut de l'écran)
2. Appuyez sur le bouton "Photographier un ticket"
3. Prenez une photo du ticket avec la caméra ou choisissez depuis la galerie
4. **Compression automatique** : L'image est réduite à max 1024px, JPEG 80%
5. Les gains de compression s'affichent (ex: 5 Mo → 500 Ko)
6. **Extraction Mistral AI** : Les articles sont extraits via l'API de vision
7. **Matching Open Food Facts** : Chaque article est associé à un produit OFF (avec confirmation utilisateur)
8. **Persistance automatique** : La session complète est sauvegardée en base

### 📊 Consulter le Tableau de Bord
- **Icône 📈 (3ème onglet)** : Accès au Dashboard
- **Statistiques globales** : Voir le nombre total de scans, articles, montant dépensé
- **Répartition Nutri-Score** : Visualiser la qualité nutritionnelle de vos achats
- **Évolution temporelle** : Analyser vos dépenses par semaine/mois
- **Totaux par période** : Suivre vos dépenses hebdomadaires et mensuelles
- **Derniers scans** : Accès rapide à vos sessions récentes

### 📜 Consulter les résultats
- **Icône 🧾 (2ème onglet)** : Affiche la liste des articles scannés dans la session courante
- Sélection multiple → suppression groupée
- Bouton "Enregistrer" → regroupe les articles courants en une seule session (les sessions automatiques correspondantes sont fusionnées)
- Affichage du total en grand avec statistiques (moyenne, nombre d'articles)

### 🕒 Consulter l'historique
- **Icône 🕰️ (4ème onglet)** : Liste des sessions de scan précédentes
- Appuyez sur une session → affiche les détails complets
- Filtres par magasin disponibles
- Menu → supprimer une session ou tout l'historique

---

## 🔧 Fonctionnalités Implémentées

Toutes les fonctionnalités principales sont désormais opérationnelles :

✅ **API produits (OpenFoodFacts)** - Récupération automatique des infos produits (nom, marque, Nutri-Score, catégories, image)
✅ **Base de données (Hive NoSQL)** - Persistance locale complète avec 6 boxes
✅ **Synchronisation automatique** - Rechargement des données après chaque modification
✅ **Sauvegarde automatique** - Chaque article scanné est immédiatement persisté
✅ **Extraction Mistral AI** - Analyse des tickets via API vision (`mistral-small-latest`, Mistral Small 4) — clé fournie via `--dart-define=MISTRAL_API_KEY=...` ou dans les réglages de l'app
✅ **Mode hors-ligne** - Stockage des scans quand pas de réseau + traitement automatique au retour
✅ **Compression d'image** - Réduction à max 1024px, JPEG 80% avec affichage des gains
✅ **Tableau de bord** - Statistiques globales, répartition Nutri-Score, tendances temporelles
✅ **Cache OFF** - Mise en cache des produits pour éviter les appels réseau répétés

## 🐛 Dernières Corrections

### Problèmes résolus
- ✅ **Synchronisation Dashboard** : Correction du bug où les scans n'apparaissaient pas dans le dashboard après sauvegarde
  - Problème : Les pages étaient pré-construites dans `initState()` avec une référence figée de `_sessions`
  - Solution : Construction dynamique des pages dans `build()` + clés explicites pour IndexedStack
  - Résultat : Le dashboard s'actualise automatiquement après chaque scan

- ✅ **Sauvegarde automatique** : Chaque article scanné est maintenant immédiatement persisté dans Hive
  - Callback `onScanSaved` intégré dans ScanScreen pour déclencher `_reloadSessions()`
  - Rechargement automatique lors de la navigation vers Dashboard/Historique

- ✅ **Préservation d'état** : Ajout de `ValueKey` sur toutes les pages et Scaffold pour éviter les rebuilds inutiles

## 🚀 Évolution Possible

Pour aller plus loin :
- [ ] Synchronisation cloud (Firebase/Back4App) pour sauvegarder l'historique
- [ ] Export CSV/PDF des sessions de scan
- [ ] Alertes sur produits peu sains (basé sur Nutri-Score)
- [ ] Intégration avec des listes de courses
- [ ] Partage de sessions entre utilisateurs

---

## 🤝 Contribution

Les contributions sont bienvenues ! Ouvrez un Issue ou Pull Request.

---

## 📦 Dépendances Principales

| Package | Version | Utilisation |
|---------|---------|-------------|
| `flutter` | SDK | Framework UI |
| `mobile_scanner` | ^5.0.0 | Scan de codes-barres en temps réel |
| `image_picker` | ^1.0.4 | Capture photo de tickets |
| `image` | ^4.1.3 | Compression et redimensionnement d'images |
| `hive` | ^2.2.3 | Stockage local NoSQL |
| `hive_flutter` | ^1.1.0 | Intégration Hive pour Flutter |
| `path_provider` | ^2.1.1 | Accès aux chemins de stockage |
| `http` | ^1.1.0 | Appels API REST (OFF, Mistral) |
| `connectivity_plus` | ^6.0.3 | Détection de connectivité réseau |
| `intl` | ^0.18.1 | Formatage des dates |
| `syncfusion_flutter_charts` | ^34.1.29 | Graphiques d'évolution des prix |
| `flutter_svg` | ^2.0.7 | Logo et icônes SVG |

---

## 📄 Licence

**MIT License** - Libre d'utiliser, modifier, distribuer.

---

*© 2026 - Prix Vif Scanner - Application complète de scan alimentaire*

*Dernière mise à jour : 17 Novembre 2026 (v1.7.0 — voir Historique des versions)*
*Documentation technique : Voir AGENT.MD pour les détails d'implémentation*
*Règles IA : Voir CLAUDE.md (le README est versionné à chaque étape)*
*Statut : ✅ Dashboard complet, historique fiable (plus de sessions vides ni de doublons hors-ligne), APK release Android avec accès réseau*
