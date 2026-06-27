# Prix Vif - Scanner de Prix Moderne 2026

<img src="https://img.shields.io/badge/Flutter-3.19+-02569B?style=for-the-badge&logo=flutter" alt="Flutter">
<img src="https://img.shields.io/badge/Dart-3.0+-0175C2?style=for-the-badge&logo=dart" alt="Dart">
<img src="https://img.shields.io/badge/Platform-Android%20%7C%20iOS-333333?style=for-the-badge" alt="Platforms">

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
- **Capture photo** : Photographier un ticket de caisse via la galerie ou la caméra
- **Compression d'image** : Réduction automatique des images à 1024px max, JPEG 80% avec affichage des gains de taille

### 📊 Résultats
- Liste des articles scannés avec cartes modernes
- Statistiques en temps réel : nombre d'articles, total, moyenne
- Sélection multiple pour suppression groupée
- Sauvegarde des sessions dans l'historique
- Affichage du total en grand
- **Sauvegarde automatique après chaque scan**

### 📈 Tableau de Bord (Dashboard)
- **Statistiques globales** : nombre total de scans, articles, montant total, moyenne par article
- **Répartition Nutri-Score** : graphique à barres horizontales avec pourcentages A/B/C/D/E
- **Évolution temporelle** : graphiques hebdomadaires et mensuels
- **Totaux par période** : cumul semaine et mois en cours
- **Derniers scans** : aperçu rapide avec navigation vers le détail

### 🕒 Historique
- Liste des sessions de scan précédentes
- Filtres par : récents, montant, nombre d'articles
- Affichage compact avec aperçu des produits
- Détails complets d'une session
- Suppression individuelle ou totale

### 📱 Mode Hors-Ligne
- Détection automatique de la connectivité réseau
- **Stockage des scans** quand pas de réseau (image compressée + JSON Mistral)
- **Traitement automatique** au retour du réseau
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

---

## 📁 Structure du Projet

```
prix_vif/
├── lib/
│   ├── main.dart                     # Point d'entrée + navigation
│   ├── models.dart                  # Modèles de données (ScannedItem, ScanSession)
│   ├── models/hive_models.dart      # Modèles Hive pour persistance
│   ├── theme.dart                   # Thème moderne 2026
│   │
│   ├── services/
│   │   ├── camera_service.dart      # Service de gestion de la caméra
│   │   ├── scan_repository.dart     # Repository Hive (CRUD scans, articles, cache)
│   │   ├── open_food_facts_service.dart # Service API Open Food Facts
│   │   ├── mistral_service.dart     # Service API Mistral AI (vision)
│   │   └── connectivity_service.dart # Gestion réseau + mode hors-ligne
│   │
│   ├── utils/
│   │   └── image_utils.dart          # Utilitaires compression d'image
│   │
│   ├── screens/
│   │   ├── scan_screen.dart          # Écran scanner (bi-mode: code-barres/ticket)
│   │   ├── results_screen.dart       # Écran résultats
│   │   ├── history_screen.dart       # Écran historique
│   │   ├── session_detail_screen.dart # Détails d'une session
│   │   └── dashboard_screen.dart     # Tableau de bord avec analyse
│   │
│   └── widgets/
│       ├── price_card.dart           # Cartes produits (avec Nutri-Score)
│       ├── scanner_overlay.dart      # Overlay scanner
│       ├── magic_button.dart         # Boutons animés
│       ├── magic_title.dart          # Titres néon
│       ├── ai_scan_effect.dart       # Effet de scan IA
│       └── logo.dart                  # Logo de l'application
│
├── pubspec.yaml                    # Dépendances Flutter
├── AGENT.md                        # Documentation technique
└── README.md                       # Cette documentation
```

---

## 🛠️ Architecture

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
- **5 boxes** : scans, articles, cache_produits, mistral_extractions, pending_offline_scans
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
- Bouton "Enregistrer" → sauvegarde la session courante (si non déjà sauvegardée)
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
✅ **Base de données (Hive NoSQL)** - Persistance locale complète avec 5 boxes
✅ **Synchronisation automatique** - Rechargement des données après chaque modification
✅ **Sauvegarde automatique** - Chaque article scanné est immédiatement persisté
✅ **Extraction Mistral AI** - Analyse des tickets via API vision (pixtral-12b-2409)
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
- [ ] Comparaison de prix entre magasins
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
| `mobile_scanner` | ^5.2.3 | Scan de codes-barres en temps réel |
| `image_picker` | ^1.0.4 | Capture photo de tickets |
| `image` | ^4.8.0 | Compression et redimensionnement d'images |
| `hive` | ^2.2.3 | Stockage local NoSQL |
| `hive_flutter` | ^1.1.0 | Intégration Hive pour Flutter |
| `path_provider` | ^2.1.1 | Accès aux chemins de stockage |
| `http` | ^1.1.0 | Appels API REST (OFF, Mistral) |
| `connectivity_plus` | ^6.1.5 | Détection de connectivité réseau |
| `intl` | ^0.18.1 | Formatage des dates |

---

## 📄 Licence

**MIT License** - Libre d'utiliser, modifier, distribuer.

---

*© 2026 - Prix Vif Scanner - Application complète de scan alimentaire*

*Dernière mise à jour : 27 Juin 2026*
*Documentation technique : Voir AGENT.MD pour les détails d'implémentation*
*Statut : ✅ Dashboard fiable - Synchronisation temps réel fonctionnelle*
