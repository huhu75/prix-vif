# Prix Vif - Scanner de Prix Moderne 2026

<img src="https://img.shields.io/badge/Flutter-3.38+-02569B?style=for-the-badge&logo=flutter" alt="Flutter">
<img src="https://img.shields.io/badge/Dart-3.10+-0175C2?style=for-the-badge&logo=dart" alt="Dart">
<img src="https://img.shields.io/badge/Platform-Android%20%7C%20iOS-333333?style=for-the-badge" alt="Platforms">

---

## 📋 Historique des versions

### v2.0.0 — 2026-11-23 — Nouvelle navigation : barre du bas et bouton Scanner central

- **Modifié** : la barre du bas passe de 5 onglets (Accueil, Scanner, Résultats, Dashboard, Historique) à 4 onglets autour d'un **bouton Scanner rond et lumineux au centre** (`AppNavBar`, `lib/widgets/app_nav_bar.dart`) : **Accueil · Produits · [Scanner] · Ma liste · Profil**. Le bouton Scanner est visible sur tous les onglets et ouvre le scanner en plein écran ; Retour le referme et ramène sur l'onglet quitté
- **Modifié** : nouvel **Accueil** (`lib/screens/home_screen.dart`), dans le style néon de l'app : recherche (ouvre l'onglet Produits, curseur dans la recherche), carte « Ton panier est moins cher chez … » avec l'économie, **Où économiser** (les 3 produits au plus gros écart entre magasins : « 0,99 € chez Leclerc au lieu de 1,20 € chez Carrefour »), **Tes derniers scans** (avec une pastille « Meilleur prix » ou « +0,14 € » face au magasin le moins cher) et **Ce qui a augmenté**. Toucher un produit ouvre sa fiche. Pas de tuiles de scan en double du bouton Scanner : seule une invitation « Scanne ton premier produit » s'affiche tant que rien n'a été scanné
- **Ajouté** : onglet **Produits** (`ProductsScreen`), provisoire jusqu'à la liste unique de l'étape suivante : **Où acheter** (où chaque produit est le moins cher, recherche, par catégorie) et **Évolution** (hausses et baisses), plus l'accès à **Tous mes produits**
- **Ajouté** : onglet **Ma liste** (`MyListScreen`), provisoire jusqu'à la vraie liste de courses : **Où faire mes courses ?** (ton panier habituel dans chaque magasin) et **Ce que chaque magasin a de moins cher**
- **Ajouté** : onglet **Profil** (`ProfileScreen`) : tes relevés (prix relevés, produits, magasins), **Historique des scans** (avec le détail d'une session pour corriger un ticket), **Mes magasins**, **Exporter mes relevés** (CSV), **Lecture des tickets (clé Mistral)** et **Retirer les données de démo**
- **Ajouté** : écran **Mes magasins** (`StoresScreen`) : ajouter, renommer partout (`renameStore`) ou retirer un magasin de la liste
- **Modifié** : le bouton retour d'Android ramène d'un onglet à l'Accueil ; l'app ne se ferme que depuis l'Accueil
- **Modifié** : une seule liste de magasins par défaut (`ScanRepository.defaultStores`) pour le scanner, Mes magasins et la correction d'un article (avant : deux listes différentes)
- **Supprimé** : l'onglet **Résultats** et son écran (les scans sont enregistrés automatiquement ; ils se retrouvent dans Profil › Historique), l'onglet **Dashboard** (son contenu est réparti entre Accueil, Produits et Ma liste), l'onglet **Historique** (déplacé dans le Profil), l'ancien accueil et sa recherche (`HomeProductSearch`), le bouton **Accueil** des écrans de détail (`AppHomeButton`, `AppNavigation`) et l'historique des onglets
- **Corrigé** : refermer le scanner juste au lancement, avant l'ouverture de la base, ne provoque plus d'erreur
- **Modifié** : tests réécrits pour la nouvelle navigation (`navigation_test.dart`, `home_screen_test.dart`, `scanner_flow_test.dart`) ; `tabs_test.dart` (Produits, Ma liste, Profil, Mes magasins) remplace `dashboard_screen_test.dart`

### v1.20.0 — 2026-11-23 — Retrouver un produit depuis l'accueil

- **Ajouté** : barre de recherche en haut de l'accueil (`HomeProductSearch`, `lib/widgets/home_product_search.dart`), dès qu'un produit a été scanné. Les résultats s'affichent pendant la frappe avec le magasin le moins cher et son prix ; toucher un produit ouvre directement sa fiche sur l'onglet Magasins. Avant, il fallait passer par Analyser → Tableau de bord → Tous mes produits → recherche → fiche
- **Ajouté** : champ vide et sélectionné, la recherche propose les 5 produits **Récemment scannés** ; rien trouvé, elle propose de scanner le produit ; **Comparer dans le tableau de bord** reprend le texte tapé dans l'onglet Produits
- **Ajouté** : recherche tolérante commune (`ProductSearchQuery`, `lib/utils/product_search.dart`) : sans accents ni majuscules (« pate » trouve « Pâtes »), mot par mot dans n'importe quel ordre et en début de mot (« lait demi »), une faute de frappe permise dans les mots de 5 lettres et plus (« yahourt »), et recherche dans la marque, la catégorie, les magasins et le code-barres. Les résultats les plus pertinents viennent en premier (le nom compte plus que la marque, qui compte plus que la catégorie ou le magasin)
- **Modifié** : l'onglet Produits du tableau de bord et **Tous mes produits** utilisent cette recherche (avant : texte exact, accents compris). Tous mes produits ouvre maintenant la fiche sur l'onglet **Magasins** (avant : onglet Fiche, sans prix)
- **Supprimé** : la carte « Où acheter un produit ? » de l'accueil, remplacée par la barre de recherche
- **Ajouté** : tests `test/utils/product_search_test.dart` (7 cas) et `test/widgets/home_product_search_test.dart` (5 cas)

### v1.19.0 — 2026-11-23 — Comparatif des magasins au scan d'un produit connu

- **Ajouté** : quand un code-barres scanné correspond à un produit déjà relevé, la feuille de saisie du prix affiche tout de suite la carte **Où l'acheter ?** (`StorePricesCard`, `lib/widgets/store_prices_card.dart`) : chaque magasin avec son dernier prix, le moins cher en vert (« Le moins cher · vas-y »), le plus cher en rouge (« À éviter · +0.40 € »), l'écart des autres, et le magasin où l'on se trouve repéré « ici »
- **Ajouté** : une phrase de conclusion pour le magasin courant (« Tu es au bon endroit », « 0.14 € de plus ici que chez Lidl », « Le plus cher ici : 0.40 € de moins chez Lidl »). Elle suit le prix tapé, chiffre par chiffre ; un magasin encore jamais vu pour ce produit s'ajoute au comparatif avec le prix saisi
- **Modifié** : avec ce comparatif, la carte de conseil d'achat n'apparaît plus que si elle propose un équivalent moins cher de la catégorie (le reste faisait doublon)
- **Ajouté** : `ProductStorePrices.forProduct` (prix d'un produit dans chaque magasin) et `buildStorePriceRows` (rôle de chaque magasin : moins cher, à éviter, autre, seul)
- **Ajouté** : tests `test/widgets/store_prices_card_test.dart` (9 cas, dont la feuille de saisie du prix)

### v1.18.0 — 2026-11-23 — Modifier un magasin depuis la fiche produit

- **Ajouté** : dans l'onglet **Magasins** de la fiche produit, toucher la carte d'un magasin ouvre sa feuille (`showStoreEditSheet`, `lib/widgets/product_detail/store_edit_sheet.dart`) : changer de magasin en un tap parmi les magasins connus (ou en tapant un nom), corriger le dernier prix, retirer le magasin
- **Ajouté** : choix **Ce produit** / **Partout** dans cette feuille. « Partout » renomme le magasin dans tous les produits, les sessions, la liste du scanner et le dernier magasin choisi (`ScanRepository.renameStore`) ; renommer vers un magasin existant les fusionne (ex. « Carefour » → « Carrefour »)
- **Ajouté** : bouton **Ajouter un prix dans un magasin** (onglet Magasins et menu ⋮) : enregistrer un prix vu en rayon sans scanner le produit (`ScanRepository.addPriceForProduct`, qui reprend la fiche du dernier scan)
- **Modifié** : le menu ⋮ « Changer de magasin » devient **Modifier un magasin** et ouvre la même feuille (après le choix du magasin si le produit en a plusieurs)
- **Corrigé** : la corbeille rouge des cartes magasin retirait le magasin de tous les scans du produit en un seul tap, sans confirmation. Retirer un magasin se fait maintenant depuis la feuille, avec confirmation
- **Corrigé** : changer le magasin d'un produit vu sur un ticket changeait le magasin de tout le ticket ; une session ne prend le nouveau magasin que si tous ses articles y sont
- **Corrigé** : les scans « Inconnu » (sans magasin) de la fiche produit ne pouvaient pas être rattachés à un magasin
- **Modifié** : un magasin ajouté ou renommé depuis une fiche apparaît dans le Scanner à la séance suivante
- **Ajouté** : `ScanRepository.countStoreArticles` et `ScanRepository.unknownStoreLabel` ; tests `test/screens/store_editing_test.dart` (9 cas : dépôt et fiche produit)

### v1.17.0 — 2026-11-22 — Tableau de bord centré sur le prix des produits

- **Ajouté** : onglet **Produits**, ouvert par défaut (`ProductsTab`, calcul `ProductStorePrices`) : pour chaque produit, le magasin le moins cher (en vert) et son prix dans les autres magasins avec l'écart (« Carrefour 1.49 € (+0.14 €) »). Les plus gros écarts viennent en premier, puis les produits « Vus dans un seul magasin ». Une recherche permet de retrouver un produit, et toucher un produit ouvre sa fiche sur l'onglet Magasins
- **Modifié** : onglet **Magasins** : « Où faire mes courses ? » puis **Ce que chaque magasin a de moins cher** (pour chaque magasin, les produits qui y sont le moins chers). « Moins cher ailleurs » est intégré à l'onglet Produits, et le détail dépliable du panier panaché est remplacé par une phrase
- **Modifié** : l'onglet **Prix** devient **Évolution** (hausses et baisses, contenu inchangé)
- **Supprimé** : onglet **Dépenses** et son calcul (`SpendingSummary`) : les dépenses n'étaient pas l'objectif
- **Modifié** : `ProductStoreComparisonItem` est remplacé par `ProductStorePrices`, qui couvre aussi les produits vus dans un seul magasin
- **Modifié** : tests mis à jour (`dashboard_screen_test.dart`, `analytics/dashboard_stats_test.dart`, `analytics/basket_and_price_changes_test.dart`)

### v1.16.0 — 2026-11-22 — Tableau de bord en trois onglets

- **Modifié** : le tableau de bord passe de 12 sections empilées (environ 15 écrans de défilement) à trois onglets, un par question : **Dépenses**, **Magasins**, **Prix**
- **Ajouté** : onglet **Dépenses** (`SpendingTab`, calcul `SpendingSummary`) : mois et semaine en cours (calendaires), comparés au mois et à la semaine précédents, et graphique des 6 dernières semaines en euros. Il remplace les tuiles « Statistiques globales », « Évolution dans le temps » et « Totaux par période »
- **Modifié** : onglet **Magasins** (`StoresTab`) : « Où faire mes courses ? » réécrit en clair (« Tes N produits habituels coûteraient… », « 4 prix relevés sur 10 », « En panachant les magasins… »), et **Moins cher ailleurs** (ex-« Comparateur multi-magasins ») : le même produit vu moins cher dans un autre magasin
- **Ajouté** : onglet **Prix** (`PricesTab`, calcul `PriceChange`) : **Ce qui a augmenté** et **Ce qui a baissé** depuis l'achat précédent du même produit dans le même magasin, avec le magasin où il est moins cher. Il remplace « Alertes prix » (le seuil 5/10/20 % disparaît) et « Évolution des prix des produits », qui comparait des prix de magasins différents
- **Modifié** : le gros bouton « Analyser un produit » et son icône en double sont remplacés par une seule icône **Tous mes produits** dans la barre du haut
- **Supprimé** : « Alternatives moins chères » (elle proposait des échanges absurdes, comme du pain de mie au lieu du jambon), « Comparaison par type de produit » (catégories en anglais, jargon), « Répartition Nutri-Score » (toujours visible sur chaque fiche produit), « Derniers scans » (déjà dans l'Historique), ainsi que les calculs devenus inutiles (`recommendations.dart`, `price_evolution.dart`, statistiques par type, seuil d'alerte enregistré dans `settings`)
- **Corrigé** : les tuiles du haut du tableau de bord débordaient à la largeur d'un téléphone (elles sont supprimées)
- **Modifié** : tests réécrits pour les trois onglets (`dashboard_screen_test.dart`, `analytics/dashboard_stats_test.dart`, `analytics/basket_and_price_changes_test.dart`)

### v1.15.0 — 2026-11-22 — Scanner : d'abord le magasin, puis SCANNER

- **Modifié** : la caméra ne démarre plus toute seule en arrivant sur le Scanner. Elle se lance seulement au tap sur **SCANNER** (et au retour au premier plan si elle tournait déjà)
- **Modifié** : le magasin est l'étape 1, obligatoire. Chaque séance de scan (arrivée sur le Scanner depuis l'accueil, ou lancement de l'app) démarre sans magasin : **SCANNER** est grisé en mode code-barres, et **Appareil photo** / **Galerie** en mode ticket, tant qu'aucun magasin n'est choisi. Le magasin reste choisi pendant la séance (par exemple après un passage par Résultats)
- **Ajouté** : raccourci **« Dernier : … »** sous la liste des magasins pour reprendre le dernier magasin d'un tap. Le dernier magasin est toujours mémorisé, mais il n'est plus présélectionné
- **Ajouté** : en mode code-barres, tant que la caméra ne tourne pas, la zone de scan rappelle l'étape en cours (`ScanIdlePanel`) : « Choisis d'abord ton magasin », puis « Prêt à scanner chez … — Appuie sur SCANNER ». Avant, elle affichait « Caméra non disponible » en rouge
- **Modifié** : `MagicButton` apparaît grisé quand il n'a pas d'action
- **Corrigé** : choisir ou ajouter un magasin juste au lancement, avant l'ouverture de la base Hive, ne provoque plus d'erreur (enregistrement différé)
- **Ajouté** : tests `test/screens/scanner_flow_test.dart` (5 cas : raccourci du dernier magasin, caméra éteinte sans magasin, caméra lancée seulement par SCANNER, magasin gardé pendant la séance et remis à zéro pour une nouvelle, mode ticket)

### v1.14.0 — 2026-11-22 — Boutons de navigation plus clairs (Retour, Accueil)

- **Ajouté** : bouton **Retour** commun (`AppBackButton`, `lib/widgets/nav_buttons.dart`) : flèche bleue dans un rond teinté, infobulle « Retour ». Il est présent sur tous les écrans sauf l'accueil, y compris les onglets Scanner, Dashboard et Historique qui n'en avaient pas
- **Ajouté** : vrai retour en arrière entre les onglets. Retour ramène à l'onglet précédent (ex. Résultats → Historique → Scanner → Accueil), et l'historique est remis à zéro à chaque passage par l'accueil. Avant, la flèche de Résultats renvoyait toujours au Scanner
- **Ajouté** : le bouton retour d'Android suit le même historique. L'app ne se ferme plus que depuis l'accueil (avant : depuis n'importe quel onglet)
- **Ajouté** : bouton **Accueil** (`AppHomeButton`) sur les écrans ouverts par-dessus les onglets (détails d'une session, sélection et fiche produit) : il ferme tous ces écrans et affiche l'accueil (`AppNavigation.goHome`)
- **Modifié** : la sélection produit s'intitule **PRODUITS** (« SÉLECTION PRODUIT » était coupé avec les nouveaux boutons)
- **Corrigé** : le titre de la fiche produit s'affichait en noir sur fond sombre (le style de titre du thème n'a pas de couleur)
- **Corrigé** : le bouton « SCANNER MAINTENANT » de l'écran Résultats vide débordait de 33 px. `MagicButton` réduit maintenant son texte au lieu de déborder
- **Ajouté** : tests `test/screens/navigation_test.dart` (7 cas : boutons Retour/Accueil, retour depuis le Scanner, remontée des onglets, bouton retour d'Android, Accueil depuis un écran ouvert par-dessus) et outils communs `test/helpers/app_test_helpers.dart`

### v1.13.0 — 2026-11-22 — Page d'accueil avec les 3 actions principales

- **Ajouté** : page d'accueil (`lib/screens/home_screen.dart`) affichée à l'ouverture de l'app, à la place du scanner. Elle propose 3 grandes cartes : **Scanner un code-barres**, **Scanner un ticket de caisse** et **Analyser les produits et magasins**, dans le style du tableau de bord (dégradé, bordure et icône teintés)
- **Ajouté** : onglet **Accueil** en tête de la barre de navigation (5 onglets : Accueil, Scanner, Résultats, Dashboard, Historique)
- **Modifié** : les cartes de scan ouvrent l'onglet Scanner directement dans le bon mode (code-barres ou ticket). La carte d'analyse ouvre le tableau de bord
- **Modifié** : la caméra ne tourne plus que quand l'onglet Scanner est affiché en mode code-barres. Avant, elle démarrait au lancement et restait allumée sur les autres onglets. Au retour au premier plan, elle ne redémarre plus en mode ticket
- **Corrigé** : un tap sur un onglet juste après le lancement, avant que la base Hive soit ouverte, change maintenant d'onglet au lieu d'échouer. L'onglet s'affiche tout de suite, puis les sessions se rechargent
- **Ajouté** : tests `test/screens/home_screen_test.dart` (3 actions de l'accueil, ouverture sur l'accueil, Scanner ouvert dans le bon mode, tableau de bord)

### v1.12.3 — 2026-11-21 — Recherche par nom fiable pour corriger un produit

- **Corrigé** : dans « Corriger le produit Open Food Facts » (fiche produit), relancer une recherche déjà faite (dont celle qui s'ouvre avec le nom du produit) n'affichait qu'**un seul** résultat, celui gardé en cache, souvent la fiche à corriger. La recherche tapée interroge maintenant le réseau d'abord et affiche tous les résultats (20 au lieu de 10). Le cache ne sert plus qu'hors-ligne
- **Corrigé** : la recherche d'Open Food Facts refuse souvent les appels en rafale (HTTP 503, ~10 recherches/min). L'app passait alors en silence à Open Products Facts / Open Beauty Facts, qui ne contiennent pas d'alimentaire, et gardait ce mauvais résultat en cache. Elle refait maintenant l'appel après 1,5 s puis 3 s, et ne met plus en cache un résultat obtenu alors qu'Open Food Facts était en erreur
- **Corrigé** : quand la recherche est impossible (pas de réseau, Open Food Facts saturé), les écrans de recherche affichent un message d'erreur au lieu de « Aucun produit trouvé »
- **Modifié** : le bouton « Associer un produit » de la confirmation du ticket utilise la même recherche que la fiche produit (réseau d'abord, code-barres accepté, nom nettoyé et abréviations développées)
- **Ajouté** : `OFFSearchUnavailableException`, paramètre `cacheFirst` de `searchByName` / `searchByNameWithTwoPasses`, `retryDelays` dans `OpenFoodFactsService` ; 5 tests dans `test/services/open_food_facts_service_test.dart`

### v1.12.2 — 2026-11-21 — Articles de ticket abrégés retrouvés (ex. lessive MIR)

- **Corrigé** : un article de ticket au libellé abrégé (ex. « LESS LIQ MIR COUL 1.35L ») n'était pas trouvé. La recherche Open Food Facts exige que tous les mots correspondent, et un seul mot abrégé faisait tout échouer
- **Ajouté** : `cleanProductName` développe les abréviations courantes des tickets (`less` → lessive, `liq` → liquide, `vaiss` → vaisselle, `choc` → chocolat…, liste `ticketAbbreviations`). Les abréviations ambiguës (`rav`, `conf`) sont laissées telles quelles
- **Ajouté** : 3ème passe de recherche par nom. Si le nom nettoyé ne donne rien, l'app réessaie avec un puis deux mots en moins à la fin (au moins 2 mots gardés, au plus 2 essais pour respecter la limite d'appels d'Open Food Facts)
- **Corrigé** : les contenances décimales (`1.35L`, `1,5 l`), les multipacks (`6x33cl`, `x2`) et les pourcentages sont retirés en entier, au lieu de laisser un « 1 » isolé dans la recherche
- **Modifié** : le prompt Mistral demande aussi les produits d'entretien, d'hygiène et de beauté (avant : « aliments, boissons, etc. »), et d'écrire les abréviations du ticket en toutes lettres en gardant la marque
- **Ajouté** : 4 tests dans `test/services/open_food_facts_service_test.dart` (nettoyage des libellés, abréviations, 3ème passe et sa limite)

### v1.12.1 — 2026-11-21 — Clé API Mistral via un fichier `.env` local

- **Ajouté** : fichier `.env` local (déjà ignoré par git) qui contient `MISTRAL_API_KEY`, chargé avec `flutter run --dart-define-from-file=.env`. Plus besoin de retaper la clé à chaque lancement
- **Modifié** : section « Configurer la clé API Mistral » du README : lancement sur Chrome, configuration PyCharm (« Additional run args ») et explication de la clé saisie dans l'app sur le web (profil Chrome temporaire)

### v1.12.0 — 2026-11-21 — Corriger un prix ou un magasin depuis la fiche produit

- **Ajouté** : depuis la fiche d'un produit (menu ⋮), bouton **Corriger un prix / scan** : ouvre la liste de tous les scans du produit ; toucher un scan ouvre la fenêtre de modification (prix, contenance, magasin)
- **Ajouté** : depuis la fiche d'un produit (menu ⋮), bouton **Changer de magasin** : dialogue pour remplacer un magasin (ou tous) par un nouveau nom, avec suggestions (`ActionChip`)
- **Ajouté** : dans l'onglet **Évolution des prix**, chaque ligne de l'historique est maintenant tappable avec une icône ✏️ pour corriger directement ce scan (prix, quantité, magasin)
- **Ajouté** : dans l'onglet **Magasins**, chaque carte magasin a un bouton ✏️ pour choisir « Changer le magasin » ou « Modifier le dernier prix »
- **Ajouté** : dans l'écran **Résultats** (session de scan en cours), bouton ✏️ sur chaque carte article pour corriger prix ou magasin avant d'enregistrer
- **Ajouté** : `ScanRepository.getScannedItem`, `getArticlesForProduct`, `changeStoreForProduct`, `getAllKnownStores` ; `updateArticle` synchronise aussi le montant total et le magasin de la session parente
- **Ajouté** : `showArticleEditDialog` accepte `knownStores` pour afficher des `ActionChip` de suggestion de magasins
- **Ajouté** : tests `test/screens/price_and_store_corrections_test.dart` (12 cas : repo unitaire, dialog édition, ResultsScreen)

### v1.11.0 — 2026-11-21 — Fallback automatique Open Products Facts et Open Beauty Facts

- **Ajouté** : support transparent des produits non alimentaires (papeterie, entretien, bricolage, hygiène, cosmétiques) via un fallback automatique multi-fournisseurs : si Open Food Facts ne détecte pas le produit (`status == 0`), l'application interroge automatiquement **Open Products Facts** (`world.openproductsfacts.org`), puis **Open Beauty Facts** (`world.openbeautyfacts.org`)
- **Ajouté** : architecture modulaire des fournisseurs `OFFProviderConfig` dans `OpenFoodFactsService`, supportant l'injection de client HTTP (`http.Client`) et de configuration de fournisseurs pour des tests 100% isolés et sans réseau
- **Ajouté** : fallback automatique à la fois sur la recherche par code-barres (`lookupBarcode`), la recherche textuelle (`searchByName` et `searchByNameWithTwoPasses`) et la recherche combinée (`searchProducts`)
- **Ajouté** : affichage de la source de données (badge `Open Products Facts` / `Open Beauty Facts`) dans la feuille de saisie du prix (`showPriceInputSheet`) et la feuille de correction de produit (`showOffMatchSheet`)
- **Ajouté** : mise en cache locale transparente dans Hive (`produits`) quelle que soit la source du produit (OFF, OPF ou OBF)
- **Ajouté** : suite de tests unitaires dédiée `test/services/open_food_facts_service_test.dart` (lookup barcode avec bascule OFF -> OPF -> OBF, mise en cache, recherche textuelle deux passes et détection barcode/texte)

### v1.10.0 — 2026-11-17 — Supprimer ou corriger un produit depuis sa fiche

- **Ajouté** : sur la fiche d'un produit (Dashboard > Analyser un produit > produit), bouton **Supprimer** (onglet Fiche et menu ⋮) : tous les scans du produit sont retirés après confirmation, les sessions vidées disparaissent, la liste des produits et le Dashboard se mettent à jour
- **Ajouté** : bouton **Pas le bon produit ?** (onglet Fiche et menu ⋮) : recherche Open Food Facts par nom ou code-barres (`lib/widgets/off_match_sheet.dart`, `OpenFoodFactsService.searchProducts`) ; le produit choisi remplace la fiche associée à tous les scans (nom, marque, code-barres, image, Nutri-Score, catégories, contenance), en gardant prix, dates et magasins ; une ligne de ticket de N articles reste un pack de N
- **Ajouté** : `ScanRepository.deleteProduct`, `rematchProduct`, `countProductArticles`, avec une seule règle d'appartenance d'un article à un produit (id, code-barres ou nom), partagée avec l'historique de la fiche et la suppression d'un magasin
- **Corrigé** : un produit ouvert depuis « Analyser un produit » (ou depuis l'onglet Similaires) n'affichait que son premier scan : la fiche reçoit maintenant le code-barres (sinon le nom) comme le Dashboard, et retrouve tous les scans
- **Ajouté** : tests `test/screens/product_corrections_test.dart` (suppression et nouvelle correspondance côté base et depuis la fiche, ouverture depuis la liste)

### v1.9.3 — 2026-11-17 — Dashboard découpé par section

- **Modifié** : `dashboard_screen.dart` découpé (2 579 → 193 lignes) : l'écran ne fait plus qu'assembler les sections ; chaque section a son fichier dans `lib/widgets/dashboard/` (`GlobalStatsSection`, `ProductPriceEvolutionSection`, `ProductStoreComparisonSection`, `ProductRecommendationSection`, `ProductTypeComparisonSection`, `NutriScoreDistributionSection`, `TimeTrendSection`, `PeriodTotalsSection`, `RecentScansSection`, `ProductAnalysisButton`, `EmptyDashboardState`)
- Plus aucun fichier de `lib/` ne dépasse 900 lignes (le plus gros : `scan_screen.dart`, 873)

### v1.9.2 — 2026-11-17 — Scanner découpé en composants

- **Modifié** : `scan_screen.dart` découpé (2 147 → 873 lignes) : l'écran garde l'état et les flux (caméra, code-barres, ticket, hors-ligne) ; l'interface est répartie dans `lib/widgets/scan/` : `ScanModeSelector` (bascule code-barres / ticket), `StoreSelector` (magasins), `TicketScanZone` (photo, compression, envoi à l'IA), `TicketConfirmationSheet` + `ExtractedTicketItem` (rapprochement Open Food Facts), `showPriceInputSheet` (saisie du prix), `showMistralSettingsDialog` (clé API)
- **Corrigé** : le scanner n'utilise plus son `BuildContext` après une attente si l'écran a été fermé (feuille de prix après la recherche Open Food Facts, message après l'import d'un ticket)
- **Ajouté** : tests `test/widgets/scan_widgets_test.dart` (saisie du prix, import d'un ticket avec lignes identiques et packs, bascule de mode, sélecteur de magasin)

### v1.9.1 — 2026-11-17 — Fiche produit découpée par onglet

- **Modifié** : `product_detail_screen.dart` découpé (2 363 → 301 lignes) : l'écran ne garde que le chargement et la barre d'onglets ; chaque onglet a son fichier dans `lib/widgets/product_detail/` (`ProductInfoTab`, `PriceEvolutionTab`, `StoreComparisonTab`, `SimilarProductsTab`)
- **Modifié** : le chargement des données de la fiche (historique par magasin, comparaison des magasins, produits similaires, fiche Open Food Facts avec repli hors-ligne) sort de l'écran vers `ProductAnalysisService` (`lib/services/product_analysis_service.dart`), testable sans réseau
- **Corrigé** : la fiche ne fait plus de `setState` si elle a été fermée pendant le chargement
- **Ajouté** : tests `test/services/product_analysis_service_test.dart` (analyse locale, repli hors-ligne, affichage des quatre onglets)

### v1.9.0 — 2026-11-17 — Export CSV

- **Ajouté** : export CSV de toutes les sessions depuis l'Historique (bouton partage) : une ligne par article avec date, session, type, magasin, produit, marque, code-barres, prix, contenance, prix au kg / L, Nutri-Score et catégories (`lib/services/csv_export.dart`)
- **Ajouté** : format pensé pour Excel en français (séparateur `;`, décimales avec virgule, UTF-8 avec BOM), envoyé via la feuille de partage du téléphone (Fichiers, e-mail, Drive…)
- **Ajouté** : dépendance `share_plus` (^13.3.1)
- **Modifié** : Android Gradle Plugin 8.11.1 → 8.12.1 (`android/settings.gradle.kts`), version minimale exigée par `share_plus`
- **Ajouté** : tests `test/services/csv_export_test.dart` (ordre, échappement des `;` et `"`, magasin de repli, BOM, nom de fichier)
- **Modifié** : prérequis du README alignés sur le projet réel (Flutter 3.38+, Dart 3.10+, iOS 13+)

### v1.8.0 — 2026-11-17 — Où faire mes courses ? et alertes prix

- **Ajouté** : section « Où faire mes courses ? » dans le Dashboard (`ShoppingBasketAnalysis`) — coût du panier habituel (produits achetés au moins 2 fois, un de chaque) dans chaque magasin, meilleur magasin et économie par rapport au plus cher ; un prix inconnu dans un magasin est estimé au prix moyen observé ailleurs, et la couverture (« prix connus : 6/8 ») est affichée
- **Ajouté** : panier optimal en combinant les magasins, avec le détail des produits à acheter dans chacun
- **Ajouté** : section « Alertes prix » (`PriceAlert`) — produits dont le prix a augmenté d'au moins 5, 10 ou 20 % (seuil réglable et mémorisé) depuis le scan précédent dans le même magasin, avec le magasin où il est moins cher ; accès direct à l'onglet « Évolution » de la fiche produit
- **Ajouté** : nouvelles sections dans `lib/widgets/dashboard/` (et non dans `dashboard_screen.dart`) avec un en-tête commun `DashboardSectionHeader` ; couleur `AppTheme.success` ajoutée au thème (déjà documentée dans la palette)
- **Ajouté** : tests `test/analytics/basket_and_alerts_test.dart` (calculs et widgets) ; tests du Dashboard ciblés par section pour ne plus dépendre de l'ordre d'affichage

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

### 🧭 Navigation
- **Barre du bas** : **Accueil · Produits · [Scanner] · Ma liste · Profil**. Le gros bouton **Scanner** au centre ouvre le scanner en plein écran depuis n'importe quel onglet
- Le bouton retour d'Android ramène d'un onglet à l'Accueil ; l'app ne se ferme que depuis l'Accueil

### 🏠 Accueil
- **Recherche** d'un produit ou d'un magasin (ouvre l'onglet Produits)
- **Ton panier est moins cher chez …** : le magasin le moins cher pour tes courses habituelles, et l'économie face au plus cher
- **Où économiser** : les produits pour lesquels changer de magasin rapporte le plus
- Tant que rien n'a été scanné : une invitation à scanner un premier produit (ou un ticket)
- **Tes derniers scans** : chaque produit avec son prix, son magasin et une pastille « Meilleur prix » ou « +0,14 € » s'il est moins cher ailleurs
- **Ce qui a augmenté** depuis ton achat précédent ; toucher un produit ouvre sa fiche

### 🎯 Scanner
- **En deux étapes** : 1. choisir le magasin (obligatoire à chaque ouverture du scanner, le dernier est proposé en raccourci), 2. appuyer sur **SCANNER** pour lancer la caméra. Elle ne démarre jamais avant
- **Caméra réelle** : Accès à la caméra du téléphone/tablette
- Scan de codes-barres en temps réel
- Contrôles de la caméra : flash
- Interface intuitive avec animation de ligne de détection
- **Mode bi-mode** : Bascule entre scan de code-barres et capture de ticket
- **Saisie de prix** : Après scan d'un code-barres, dialogue modal pour entrer le prix réel
- **Comparatif au scan** : si le produit a déjà été relevé, la feuille de saisie montre tout de suite chaque magasin avec son prix, le moins cher en vert (y aller) et le plus cher en rouge (à éviter), et dit si le magasin où tu es est le bon
- **Magasins mémorisés** : les magasins ajoutés et le dernier magasin choisi sont conservés entre deux lancements (le dernier est proposé, pas présélectionné)
- **Capture photo** : Photographier un ticket de caisse via la galerie ou la caméra
- **Compression d'image** : Réduction automatique des images à 1024px max, JPEG 80% avec affichage des gains de taille
- **Sauvegarde automatique après chaque scan**

### 🏷️ Produits
- **Où acheter** : pour chaque produit, le magasin le moins cher et son prix dans les autres magasins avec l'écart, les plus gros écarts en premier, puis les produits vus dans un seul magasin. Recherche tolérante (accents, début de mot, faute de frappe, marque, catégorie, magasin) et vue **Par catégorie** (au kg / L)
- **Évolution** : **Ce qui a augmenté** et **Ce qui a baissé** depuis ton achat précédent du même produit dans le même magasin, avec le magasin où il est moins cher
- **Tous mes produits** (icône de la barre du haut) : la liste complète des produits scannés, avec tri et filtres
- **Fiche produit** (en touchant un produit) : évolution, magasins, catégorie, fiche Open Food Facts, avec **Pas le bon produit ?** et **Supprimer**. Toucher un magasin permet de le changer (pour ce produit ou partout), de corriger son dernier prix ou de le retirer ; **Ajouter un prix dans un magasin** sans scanner
- **Prix au kg / L** : chaque article de contenance connue affiche son prix normalisé (ex. `1.49 €/L`)

### 🛒 Ma liste
- **Où faire mes courses ?** : le coût de ton panier habituel dans chaque magasin (avec le nombre de prix relevés et le total en achetant chaque produit là où il est le moins cher)
- **Ce que chaque magasin a de moins cher** : les produits qui sont le moins chers dans chaque magasin

### 👤 Profil
- **Tes relevés** : nombre de prix relevés, de produits et de magasins
- **Historique des scans** : les sessions de scan, filtrables par magasin ; le détail d'une session permet de **corriger un article** (prix, contenance, magasin) ou de le supprimer ; suppression d'une session ou de tout l'historique
- **Mes magasins** : ajouter un magasin, le renommer partout (produits, tickets, scanner) ou le retirer de la liste (les prix déjà relevés restent)
- **Exporter mes relevés** : un fichier CSV lisible dans Excel / Numbers, envoyé par e-mail, Drive ou enregistré dans Fichiers
- **Lecture des tickets (clé Mistral)** : saisir la clé API utilisée pour lire les tickets
- **Retirer les données de démo** (ne supprime que les sessions d'exemple, injectées au tout premier lancement)

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

- [Flutter SDK](https://flutter.dev/docs/get-started/install) **3.38+**
- [Dart SDK](https://dart.dev/get-dart) **3.10+**
- IDE recommandé : Android Studio, VS Code ou IntelliJ IDEA
- Un émulateur ou un appareil physique connecté
- **Android 6.0+** ou **iOS 13+** (pour la caméra)

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

L'analyse des tickets de caisse utilise l'API Mistral. La clé ne doit **jamais** être écrite dans le code du dépôt. Elle est passée à la compilation et se retrouve seulement dans l'app compilée.

**Méthode recommandée : le fichier `.env`**

Le fichier `.env` à la racine du projet est ignoré par git (voir `.gitignore`). Mets-y ta clé :

```
MISTRAL_API_KEY=ta_cle_ici
```

Puis lance l'app en chargeant ce fichier :

```bash
# Sur Chrome
flutter run -d chrome --dart-define-from-file=.env

# Sur un téléphone ou un émulateur
flutter run --dart-define-from-file=.env

# Build release
flutter build apk --release --dart-define-from-file=.env
```

Les lignes qui commencent par `#` sont des commentaires. Si `MISTRAL_API_KEY=` est vide, l'app reste en mode démo. Si tu clones le dépôt ailleurs, crée ce fichier à la main : il n'est pas versionné.

**Depuis PyCharm / Android Studio** : Run → Edit Configurations → `main.dart`, puis dans « Additional run args » : `-d chrome --dart-define-from-file=.env` (retire `-d chrome` pour lancer sur un autre appareil). Le dossier `.idea/` est ignoré par git.

**Sans fichier** : `flutter run --dart-define=MISTRAL_API_KEY=sk-...`

Sans clé, l'application reste en **mode démo** (articles factices). Autre solution : saisir la clé dans l'app (icône engrenage de l'onglet Scanner). Elle est alors stockée localement dans Hive, jamais dans le dépôt. La clé passée à la compilation reste prioritaire. ⚠️ Sur Chrome, `flutter run` ouvre un profil de navigateur temporaire : une clé saisie dans l'app peut disparaître d'un lancement à l'autre. Utilise plutôt le `.env`.

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
│   │   ├── recommendations.dart      # Alternatives moins chères
│   │   ├── shopping_basket.dart      # « Où faire mes courses ? » (panier par magasin)
│   │   └── price_alerts.dart         # Alertes de hausse de prix
│   │
│   ├── services/
│   │   ├── camera_service.dart      # Service de gestion de la caméra
│   │   ├── scan_repository.dart     # Repository Hive (CRUD scans, articles, cache)
│   │   ├── open_food_facts_service.dart # Service API Open Food Facts
│   │   ├── mistral_service.dart     # Service API Mistral AI (vision)
│   │   ├── connectivity_service.dart # Gestion réseau + mode hors-ligne
│   │   ├── csv_export.dart          # Export CSV + feuille de partage
│   │   └── product_analysis_service.dart # Données de la fiche produit (historique, magasins, similaires, OFF)
│   │
│   ├── utils/
│   │   ├── image_utils.dart          # Utilitaires compression d'image
│   │   ├── unit_price.dart           # Contenance → prix au kg / L / unité
│   │   ├── product_search.dart       # Recherche tolérante (accents, début de mot, faute de frappe)
│   │   └── product_type_utils.dart   # Type de produit issu des catégories Open Food Facts
│   │
│   ├── screens/
│   │   ├── home_screen.dart          # Accueil : recherche, deux scans, panier, derniers scans, hausses
│   │   ├── scan_screen.dart          # Scanner plein écran : état et flux (code-barres, ticket, hors-ligne)
│   │   ├── products_screen.dart      # Onglet Produits : où acheter, évolution des prix
│   │   ├── my_list_screen.dart       # Onglet Ma liste : où faire mes courses
│   │   ├── profile_screen.dart       # Onglet Profil : relevés, historique, magasins, export, réglages
│   │   ├── stores_screen.dart        # Mes magasins : ajouter, renommer, retirer
│   │   ├── history_screen.dart       # Historique des scans (depuis le Profil)
│   │   ├── session_detail_screen.dart # Détails d'une session
│   │   ├── product_selection_screen.dart # Liste des produits scannés (recherche, tri, filtres)
│   │   └── product_detail_screen.dart    # Fiche produit : chargement + onglets
│   │
│   └── widgets/
│       ├── price_card.dart           # Cartes produits (avec Nutri-Score et prix au kg / L)
│       ├── store_prices_card.dart    # Comparatif des magasins d'un produit connu (au scan)
│       ├── app_nav_bar.dart          # Barre du bas : 4 onglets et bouton Scanner central
│       ├── article_edit_dialog.dart  # Correction / suppression d'un article enregistré
│       ├── off_match_sheet.dart       # Choix d'une autre fiche Open Food Facts pour un produit
│       ├── scanner_overlay.dart      # Overlay scanner
│       ├── magic_button.dart         # Boutons animés
│       ├── nav_buttons.dart          # Bouton Retour et boutons ronds des barres d'app
│       ├── magic_title.dart          # Titres néon
│       ├── ai_scan_effect.dart       # Effet de scan IA
│       ├── logo.dart                  # Logo de l'application
│       ├── dashboard/                 # Contenus des onglets Produits et Ma liste (où acheter, évolution, magasins) et briques communes
│       ├── product_detail/            # Onglets de la fiche produit (fiche, évolution, magasins, catégorie) et feuille d'un magasin
│       └── scan/                      # Composants du scanner (magasin, mode, attente avant caméra, zone ticket, prix, confirmation, clé Mistral)
│
├── test/                           # Tests unitaires et widgets (modèles, dépôt Hive, écrans)
├── pubspec.yaml                    # Dépendances Flutter
├── AGENT.md                        # Documentation technique
└── README.md                       # Cette documentation
```

---

## 🛠️ Architecture

### Couche d'analyse
- Les calculs (prix par magasin, panier par magasin, changements de prix) vivent dans `lib/analytics/`, sans dépendance à Flutter UI : les écrans ne font qu'afficher leurs résultats

### Gestion d'État
- État local avec `setState`
- Passage de callbacks entre widgets

### Navigation
- `AppNavBar` pour la navigation principale : 4 onglets (Accueil, Produits, Ma liste, Profil) et le bouton Scanner central, ouverture sur l'Accueil
- Le scanner, la fiche produit, l'historique et Mes magasins s'ouvrent par-dessus les onglets (`MaterialPageRoute`), avec un bouton **Retour**
- Bouton retour d'Android : d'un onglet vers l'Accueil, puis fermeture de l'app
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
1. Lancez l'application sur votre appareil Android/iOS : elle s'ouvre sur l'**accueil**
2. Touchez le bouton **Scanner** au centre de la barre du bas
3. **Choisissez le magasin** dans la liste (ou touchez le raccourci « Dernier : … »)
4. Appuyez sur **SCANNER** : la caméra se lance (autorisez l'accès la première fois)
5. Pointez la caméra vers un code-barres
6. Le code est scanné automatiquement
7. **Intégration Open Food Facts** : L'application récupère automatiquement les informations du produit (nom, marque, Nutri-Score, catégories, image)
8. Un dialogue s'ouvre : entrez le **prix réel** du produit. Si le produit est déjà connu, le comparatif des magasins s'affiche au-dessus (où aller, où éviter)
9. **✅ Sauvegarde automatique** : L'article est immédiatement persisté en base et apparaît dans Produits, Ma liste et l'historique du Profil

### 📸 Capturer un ticket de caisse
1. Touchez le bouton **Scanner** au centre de la barre du bas, puis sélectionnez le mode **TICKET**
2. **Choisissez le magasin** : les boutons Appareil photo / Galerie restent grisés avant
3. Prenez une photo du ticket avec la caméra ou choisissez depuis la galerie
4. **Compression automatique** : L'image est réduite à max 1024px, JPEG 80%
5. Les gains de compression s'affichent (ex: 5 Mo → 500 Ko)
6. **Extraction Mistral AI** : Les articles sont extraits via l'API de vision
7. **Matching Open Food Facts** : Chaque article est associé à un produit OFF (avec confirmation utilisateur). La recherche se fait en 3 passes : nom complet, puis nom nettoyé avec les abréviations du ticket développées (LESS → lessive), puis avec un ou deux mots en moins
8. **Persistance automatique** : La session complète est sauvegardée en base

### 🏷️ Comparer les prix
- **Produits** (barre du bas) : où chaque produit est le moins cher et combien il coûte ailleurs ; la recherche retrouve un produit par son nom, sa marque, sa catégorie ou un magasin ; la vue **Évolution** montre ce qui a augmenté ou baissé
- **Ma liste** (barre du bas) : le magasin le moins cher pour ton panier habituel, et ce que chaque magasin a de moins cher
- Touche un produit pour ouvrir sa fiche ; sur la fiche, touche un magasin pour le modifier

### 👤 Profil
- **Historique des scans** : touche une session pour voir ses articles et en corriger un
- **Mes magasins** : touche un magasin pour le renommer ou le retirer ; **Ajouter un magasin** en bas
- **Exporter mes relevés** : partage un fichier CSV

---

## 🔧 Fonctionnalités Implémentées

Toutes les fonctionnalités principales sont désormais opérationnelles :

✅ **API produits (OpenFoodFacts)** - Récupération automatique des infos produits (nom, marque, Nutri-Score, catégories, image)
✅ **Base de données (Hive NoSQL)** - Persistance locale complète avec 6 boxes
✅ **Synchronisation automatique** - Rechargement des données après chaque modification
✅ **Sauvegarde automatique** - Chaque article scanné est immédiatement persisté
✅ **Extraction Mistral AI** - Analyse des tickets via API vision (`mistral-small-latest`, Mistral Small 4) — clé fournie via le fichier `.env` local (`--dart-define-from-file=.env`), `--dart-define=MISTRAL_API_KEY=...` ou dans les réglages de l'app
✅ **Mode hors-ligne** - Stockage des scans quand pas de réseau + traitement automatique au retour
✅ **Compression d'image** - Réduction à max 1024px, JPEG 80% avec affichage des gains
✅ **Tableau de bord** - Trois onglets : produits (où chacun est le moins cher), magasins (où faire ses courses, ce que chaque magasin a de moins cher), évolution (hausses et baisses)
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
- [ ] Export PDF des sessions de scan
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
| `share_plus` | ^13.3.1 | Partage du fichier CSV exporté |

---

## 📄 Licence

**MIT License** - Libre d'utiliser, modifier, distribuer.

---

*© 2026 - Prix Vif Scanner - Application complète de scan alimentaire*

*Dernière mise à jour : 23 Novembre 2026 (v2.0.0 — voir Historique des versions)*
*Documentation technique : Voir AGENT.MD pour les détails d'implémentation*
*Règles IA : Voir CLAUDE.md (le README est versionné à chaque étape)*
*Statut : ✅ Nouvelle navigation (Accueil, Produits, Ma liste, Profil et bouton Scanner central), recherche de produit tolérante aux accents et fautes de frappe, comparatif des magasins au scan d'un produit connu (où aller, où éviter), magasin modifiable depuis la fiche produit (ce produit ou partout) et ajout d'un prix sans scanner, tableau de bord centré sur le prix des produits (Produits, Magasins, Évolution), scanner en deux étapes (magasin puis SCANNER), page d'accueil (3 actions) et boutons Retour / Accueil, recherche par nom fiable (OFF saturé géré), articles de ticket abrégés retrouvés, clé Mistral via `.env` local, fallback OPF/OBF, correction prix/magasin, comparaisons au kg / L, données corrigeables et export CSV*
