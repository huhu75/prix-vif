# Prix Vif - Scanner de Prix Moderne 2026

<img src="https://img.shields.io/badge/Flutter-3.19+-02569B?style=for-the-badge&logo=flutter" alt="Flutter">
<img src="https://img.shields.io/badge/Dart-3.0+-0175C2?style=for-the-badge&logo=dart" alt="Dart">
<img src="https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web-333333?style=for-the-badge" alt="Platforms">

---

## 📱 Apercu

**Prix Vif** est une application Flutter moderne (design 2026) conçue pour scanner des codes-barres et des tickets de caisse afin de récupérer et organiser les informations de prix des produits. L'application fonctionne désormais avec un **scanner réel** et une **capture photo de tickets** avec compression d'image.

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

### 🕒 Historique
- Liste des sessions de scan précédentes
- Filtres par : récents, montant, nombre d'articles
- Affichage compact avec aperçu des produits
- Détails complets d'une session
- Suppression individuelle ou totale

---

## 🎨 Design Moderne 2026

### Palette de Couleurs
| Couleur | Code | Utilisation |
|---------|------|-------------|
| **Background** | `#0A0A0A` | Fond principal |
| **Primary** | `#00F5FF` | Boutons, accents |
| **Secondary** | `#8B5CF6` | Détails secondaires |
| **Accent** | `#10B981` | Éléments positifs |
| **Error** | `#FF4757` | Messages d'erreur |

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
│   ├── main.dart                 # Point d'entrée + navigation
│   ├── models.dart              # Modèles de données (ScannedItem, ScanSession)
│   ├── theme.dart               # Thème moderne 2026
│   │
│   ├── services/
│   │   └── camera_service.dart   # Service de gestion de la caméra
│   │
│   ├── screens/
│   │   ├── scan_screen.dart      # Écran scanner (bi-mode: code-barres/ticket)
│   │   ├── results_screen.dart   # Écran résultats
│   │   ├── history_screen.dart   # Écran historique
│   │   └── session_detail_screen.dart # Détails session
│   │
│   └── widgets/
│       ├── price_card.dart       # Cartes produits
│       └── scanner_overlay.dart  # Overlay scanner
│
├── pubspec.yaml                # Dépendances (mobile_scanner, image_picker, image)
├── README.md                   # Documentation
└── ...                         # Fichiers Flutter natifs
```

---

## 🛠️ Architecture

### Gestion d'État
- État local avec `setState`
- Passage de callbacks entre widgets

### Navigation
- `BottomNavigationBar` pour la navigation principale
- `MaterialPageRoute` pour les détails
- `IndexedStack` pour conserver l'état

### Modèles
- **`ScannedItem`** : Article avec prix, nom, marque
- **`ScanSession`** : Session de scan avec liste d'articles

---

## 🎯 Utilisation

### Scanner un code-barres
1. Lancez l'application sur votre appareil Android/iOS
2. Autorisez l'accès à la caméra
3. Sélectionnez le mode **CODE-BARRES** (bascule en haut de l'écran)
4. Pointez la caméra vers un code-barres
5. Le code est scanné automatiquement
6. Un dialogue s'ouvre : entrez le **prix réel** du produit
7. L'article est ajouté à votre liste avec le prix saisi

### Capturer un ticket de caisse
1. Sélectionnez le mode **TICKET** (bascule en haut de l'écran)
2. Appuyez sur le bouton "Photographier un ticket"
3. Prenez une photo du ticket avec la caméra ou choisissez depuis la galerie
4. L'image s'affiche avec sa taille originale
5. Appuyez sur "Compresser" pour réduire la taille (max 1024px, JPEG 80%)
6. Les gains de compression s'affichent (ex: 5 Mo → 500 Ko)
7. Les articles du ticket sont simulés et ajoutés à votre liste

### Consulter les résultats
- Icône de reçu → affiche la liste des articles scannés
- Sélection multiple → suppression groupée
- Bouton "Enregistrer" → sauvegarde la session dans l'historique
- Affichage du total en grand avec statistiques (moyenne, nombre d'articles)

### Consulter l'historique
- Icône historique → liste des sessions de scan précédentes
- Appuyez sur une session → affiche les détails complets
- Menu → supprimer une session ou tout l'historique

---

## 🔧 Développement Futur

Pour améliorer l'app :
- [ ] API produits (OpenFoodFacts) pour récupérer les infos réelles à partir des codes-barres
- [ ] Base de données (Hive, SQLite) pour persister les données localement
- [ ] Synchronisation cloud pour sauvegarder l'historique
- [ ] Export CSV/PDF des sessions de scan
- [ ] Comparaison de prix entre magasins
- [ ] Reconnaissance OCR des tickets de caisse (remplace la simulation actuelle)

---

## 🤝 Contribution

Les contributions sont bienvenues ! Ouvrez un Issue ou Pull Request.

---

## 📄 Licence

**MIT License** - Libre d'utiliser, modifier, distribuer.

---

*© 2026 - Prix Vif Scanner*

*Generated by Mistral Vibe*
*Co-Authored-By: Mistral Vibe <vibe@mistral.ai>*
