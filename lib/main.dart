import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'theme.dart';
import 'models.dart';
import 'screens/home_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/history_screen.dart';
import 'screens/my_list_screen.dart';
import 'screens/products_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/session_detail_screen.dart';
import 'screens/product_selection_screen.dart';
import 'screens/product_detail_screen.dart';
import 'services/scan_repository.dart';
import 'services/mistral_service.dart';
import 'services/category_service.dart';
import 'models/product_category.dart';
import 'widgets/app_nav_bar.dart';

// Point d'entree de l'application
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Étape 3a — Initialisation de Hive
  await Hive.initFlutter();

  // Initialisation de la locale fr_FR pour Intl
  await initializeDateFormatting('fr_FR', null);

  runApp(const PrixVifApp());
}

// Application Prix Vif
class PrixVifApp extends StatelessWidget {
  const PrixVifApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Prix Vif - Scanner de prix',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const MainScreen(),
    );
  }
}

/// Écran principal : quatre onglets (Accueil, Produits, Ma liste, Profil) et
/// le bouton Scanner au centre de la barre du bas, qui ouvre le scanner en
/// plein écran depuis n'importe quel onglet.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // Onglets de la barre du bas : Accueil (0), Produits (1), Ma liste (2), Profil (3)
  static const int homeTab = 0;
  static const int productsTab = 1;
  static const int listTab = 2;

  static const _navItems = [
    AppNavItem(Icons.home_outlined, Icons.home, 'Accueil'),
    AppNavItem(Icons.local_offer_outlined, Icons.local_offer, 'Produits'),
    AppNavItem(Icons.shopping_cart_outlined, Icons.shopping_cart, 'Ma liste'),
    AppNavItem(Icons.person_outline, Icons.person, 'Profil'),
  ];

  int _currentIndex = homeTab;

  List<ScanSession> _sessions = [];

  // Sessions pour les écrans ouverts par-dessus les onglets (historique), qui
  // ne sont pas reconstruits avec MainScreen
  final ValueNotifier<List<ScanSession>> _sessionsListenable = ValueNotifier(const []);

  // Onglet Produits : chaque demande (recherche, « Tout voir ») le rouvre sur une vue
  int _productsRequest = 0;
  ProductsView _productsView = ProductsView.whereToBuy;
  bool _productsFocusSearch = false;
  String _productsQuery = '';

  // Repository pour la persistance
  final ScanRepository _repository = ScanRepository();

  // Catégorie de chaque produit (clé produit → catégorie), complétée depuis
  // Open Food Facts au lancement et après chaque scan
  late final CategoryService _categoryService = CategoryService(_repository);
  Map<String, ProductCategory> _categories = {};

  @override
  void initState() {
    super.initState();
    _initRepository();
  }

  @override
  void dispose() {
    _sessionsListenable.dispose();
    super.dispose();
  }

  /// Cherche sur Open Food Facts la catégorie des produits qui n'en ont pas
  /// encore (en arrière-plan), puis rafraîchit les écrans s'il en a trouvé
  Future<void> _fillCategories() async {
    try {
      final found = await _categoryService.fillMissing();
      if (found > 0 && mounted) await _reloadSessions();
    } catch (e) {
      debugPrint('MainScreen: catégories non complétées ($e)');
    }
  }

  /// Initialise le repository et charge les sessions persistées
  Future<void> _initRepository() async {
    try {
      await _repository.init();

      // Charger la clé API Mistral depuis Hive (fallback) — la clé de build
      // (--dart-define=MISTRAL_API_KEY=...) a priorité et n'est pas écrasée
      final apiKey = _repository.getMistralApiKey();
      if (apiKey != null && apiKey.isNotEmpty && MistralService.apiKey == null) {
        MistralService.apiKey = apiKey;
      }

      if (!_repository.isDemoSeeded) {
        // Tout premier lancement : injecter les sessions de démo une seule fois.
        // Une base déjà remplie (installation antérieure) est laissée telle quelle.
        // Le drapeau empêche la démo de revenir après « Tout supprimer ».
        if ((await _repository.getAllScans()).isEmpty) {
          for (final session in ScanSession.demoSessions) {
            await _repository.saveScan(session);
          }
        }
        await _repository.markDemoSeeded();
      }

      await _reloadSessions();
      _fillCategories();
    } catch (e) {
      debugPrint('Erreur initialisation repository: $e');
      if (!mounted) return;
      setState(() => _sessions = List<ScanSession>.from(ScanSession.demoSessions));
    }
  }

  /// Recharge les sessions depuis Hive (nouvelle liste : les écrans se
  /// reconstruisent). Base pas encore ouverte (tap juste au lancement) : rien
  /// à recharger, l'ouverture s'en chargera.
  Future<void> _reloadSessions() async {
    final List<ScanSession> allSessions;
    try {
      allSessions = await _repository.getAllScans();
    } catch (e) {
      debugPrint('MainScreen: rechargement des sessions impossible ($e)');
      return;
    }
    if (!mounted) return;
    setState(() {
      _sessions = List<ScanSession>.from(allSessions);
      _categories = _repository.getAllProductCategories();
    });
    _sessionsListenable.value = _sessions;
  }

  // ==================== NAVIGATION ====================

  void _goToTab(int index) => setState(() => _currentIndex = index);

  /// Onglet Produits sur une vue donnée, éventuellement curseur dans la
  /// recherche ou recherche déjà remplie
  void _openProducts({ProductsView view = ProductsView.whereToBuy, bool focusSearch = false, String query = ''}) {
    setState(() {
      _productsRequest++;
      _productsView = view;
      _productsFocusSearch = focusSearch;
      _productsQuery = query;
      _currentIndex = productsTab;
    });
  }

  /// Bouton Scanner (et tuiles de l'accueil) : le scanner en plein écran,
  /// une nouvelle séance à chaque ouverture
  Future<void> _openScanner({bool barcode = true}) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (routeContext) => ScanScreen(
        repository: _repository,
        requestedBarcodeMode: barcode,
        onBack: () => Navigator.of(routeContext).maybePop(),
        onScanSaved: () async {
          await _reloadSessions();
          _fillCategories();
        },
      ),
    ));
    if (mounted) await _reloadSessions();
  }

  void _openProductDetail(String productId, String productName, {int initialTabIndex = 0}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProductDetailScreen(
        repository: _repository,
        productId: productId,
        productName: productName,
        initialTabIndex: initialTabIndex,
        onChanged: _reloadSessions,
      ),
    ));
  }

  void _openProductSelection() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProductSelectionScreen(repository: _repository, onChanged: _reloadSessions),
    ));
  }

  /// Profil › Historique des scans
  void _openHistory() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (routeContext) => ValueListenableBuilder<List<ScanSession>>(
        valueListenable: _sessionsListenable,
        builder: (_, sessions, _) => HistoryScreen(
          sessions: sessions,
          onBack: () => Navigator.of(routeContext).maybePop(),
          onSessionSelected: _handleSessionSelected,
          onSessionDeleted: _handleSessionDeleted,
          onClearAll: _clearAllSessions,
          onRemoveDemoData: _removeDemoData,
        ),
      ),
    ));
  }

  void _handleSessionSelected(ScanSession session) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (routeContext) => SessionDetailScreen(
        session: session,
        onBack: () => Navigator.of(routeContext).maybePop(),
        repository: _repository,
        onChanged: _reloadSessions,
      ),
    ));
  }

  // ==================== HISTORIQUE ====================

  Future<void> _handleSessionDeleted(ScanSession session) async {
    final messenger = ScaffoldMessenger.of(context);
    await _repository.deleteScan(session.id);
    await _reloadSessions();
    messenger.showSnackBar(const SnackBar(
      backgroundColor: Colors.red,
      content: Text('Session supprimée', style: TextStyle(color: Colors.white)),
      duration: Duration(seconds: 2),
    ));
  }

  Future<void> _clearAllSessions() async {
    await _repository.clearAllScans();
    await _reloadSessions();
  }

  Future<void> _removeDemoData() async {
    final messenger = ScaffoldMessenger.of(context);
    final removed = await _repository.removeDemoData();
    await _reloadSessions();
    messenger.showSnackBar(SnackBar(
      content: Text('$removed session${removed > 1 ? 's' : ''} de démo retirée${removed > 1 ? 's' : ''}'),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        key: const ValueKey('home_screen'),
        sessions: _sessions,
        onScanBarcode: () => _openScanner(barcode: true),
        onScanTicket: () => _openScanner(barcode: false),
        onSearch: () => _openProducts(focusSearch: true),
        onSeeProducts: _openProducts,
        onSeeIncreases: () => _openProducts(view: ProductsView.evolution),
        onProductTap: _openProductDetail,
        categories: _categories,
        onCategoryTap: (label) => _openProducts(query: label),
        onOpenBasket: () => _goToTab(listTab),
      ),
      ProductsScreen(
        key: const ValueKey('products_screen'),
        sessions: _sessions,
        categories: _categories,
        requestId: _productsRequest,
        initialView: _productsView,
        focusSearch: _productsFocusSearch,
        initialQuery: _productsQuery,
        onProductTap: _openProductDetail,
        onAllProducts: _openProductSelection,
      ),
      MyListScreen(
        key: const ValueKey('my_list_screen'),
        sessions: _sessions,
        onProductTap: _openProductDetail,
      ),
      ProfileScreen(
        key: const ValueKey('profile_screen'),
        sessions: _sessions,
        repository: _repository,
        onOpenHistory: _openHistory,
        onChanged: _reloadSessions,
      ),
    ];

    // Bouton retour d'Android : depuis un onglet, l'accueil ; l'app ne se
    // ferme que depuis l'accueil
    return PopScope(
      canPop: _currentIndex == homeTab,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goToTab(homeTab);
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        body: IndexedStack(index: _currentIndex, children: pages),
        bottomNavigationBar: AppNavBar(
          items: _navItems,
          currentIndex: _currentIndex,
          onTap: _goToTab,
          onScan: _openScanner,
        ),
      ),
    );
  }
}
