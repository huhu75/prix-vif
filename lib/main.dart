import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'theme.dart';
import 'models.dart';
import 'screens/home_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/results_screen.dart';
import 'screens/history_screen.dart';
import 'screens/session_detail_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/product_selection_screen.dart';
import 'screens/product_detail_screen.dart';
import 'services/scan_repository.dart';
import 'services/mistral_service.dart';
import 'widgets/nav_buttons.dart';

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

// Ecran principal avec navigation
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // Onglets de la barre de navigation (dans l'ordre d'affichage)
  static const int _homeTab = 0;
  static const int _scanTab = 1;
  static const int _resultsTab = 2;
  static const int _dashboardTab = 3;
  static const int _historyTab = 4;

  int _currentIndex = _homeTab;

  // Onglets visités avant l'onglet courant, pour le bouton Retour
  // (vidé à chaque passage par l'accueil, qui est la racine)
  final List<int> _tabHistory = [];
  static const int _maxTabHistory = 20;

  // Etat de l'application
  final List<ScannedItem> _currentScannedItems = [];
  List<ScanSession> _sessions = [];  // Non-final pour permettre le remplacement complet
  String _currentScanType = 'barcode'; // 'barcode' ou 'ticket'

  // Mode de scan demandé depuis l'accueil, transmis au Scanner à chaque demande
  bool? _requestedBarcodeMode;
  int _modeRequestId = 0;

  // Repository pour la persistance
  final ScanRepository _repository = ScanRepository();

  @override
  void initState() {
    super.initState();

    // Bouton « Accueil » des écrans ouverts par-dessus les onglets
    AppNavigation.homeRequests.addListener(_showHome);

    // Étape 3a — Initialisation du repository et chargement des données persistées
    _initRepository();
  }

  @override
  void dispose() {
    AppNavigation.homeRequests.removeListener(_showHome);
    super.dispose();
  }

  /// Met à jour le type de scan actuel
  void _handleScanTypeChanged(String type) {
    setState(() {
      _currentScanType = type;
    });
  }

  /// Accueil → onglet Scanner, directement en mode code-barres ou ticket
  void _openScanner({required bool barcode}) {
    setState(() {
      _requestedBarcodeMode = barcode;
      _modeRequestId++;
      _currentScanType = barcode ? 'barcode' : 'ticket';
      _recordTabChange(_scanTab);
      _currentIndex = _scanTab;
    });
  }

  /// Note l'onglet quitté dans l'historique (l'accueil, racine, le vide)
  void _recordTabChange(int index) {
    if (index == _currentIndex) return;
    if (index == _homeTab) {
      _tabHistory.clear();
      return;
    }
    _tabHistory.add(_currentIndex);
    if (_tabHistory.length > _maxTabHistory) _tabHistory.removeAt(0);
  }

  /// Change d'onglet tout de suite ; le Dashboard et l'Historique rechargent
  /// ensuite les sessions. Un tap juste après le lancement (base Hive pas
  /// encore ouverte) change quand même d'onglet.
  Future<void> _goToTab(int index) async {
    setState(() {
      _recordTabChange(index);
      _currentIndex = index;
    });
    await _reloadForTab(index);
  }

  /// Bouton Retour des onglets (et bouton retour d'Android) : onglet
  /// précédent, sinon l'accueil
  Future<void> _goBack() async {
    final target = _tabHistory.isNotEmpty ? _tabHistory.removeLast() : _homeTab;
    if (target == _homeTab) _tabHistory.clear();
    setState(() => _currentIndex = target);
    await _reloadForTab(target);
  }

  /// Bouton Accueil des écrans ouverts par-dessus les onglets
  void _showHome() {
    if (!mounted) return;
    setState(() {
      _tabHistory.clear();
      _currentIndex = _homeTab;
    });
  }

  Future<void> _reloadForTab(int index) async {
    if (index != _dashboardTab && index != _historyTab) return;
    try {
      await _reloadSessions();
    } catch (e) {
      debugPrint('MainScreen: rechargement des sessions impossible ($e)');
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
        print('DEBUG MainScreen: Clé API Mistral chargée depuis Hive');
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

      final savedSessions = await _repository.getAllScans();
      setState(() {
        _sessions = List<ScanSession>.from(savedSessions);
      });
    } catch (e) {
      print('Erreur initialisation repository: $e');
      setState(() {
        // Fallback : charger les données de démo
        print('DEBUG MainScreen: Fallback vers demoSessions suite à erreur');
        _sessions = List<ScanSession>.from(ScanSession.demoSessions);
      });
    }
  }

  // Gestion des articles scannes
  void _handleItemScanned(ScannedItem item) {
    setState(() {
      _currentScannedItems.add(item);
    });
  }

  // Les articles sont sauvegardés dès le scan : les retirer de la liste
  // courante les supprime aussi de la base (historique, Dashboard).
  Future<void> _handleItemRemoved(ScannedItem item) async {
    setState(() {
      _currentScannedItems.removeWhere((i) => i.id == item.id);
    });
    await _repository.deleteArticle(item.id);
    await _reloadSessions();
  }

  Future<void> _handleItemUpdated(ScannedItem updated) async {
    setState(() {
      final index = _currentScannedItems.indexWhere((i) => i.id == updated.id);
      if (index >= 0) {
        _currentScannedItems[index] = updated;
      }
    });
    await _repository.updateArticle(updated);
    await _reloadSessions();
  }

  Future<void> _clearAllItems() async {
    final ids = _currentScannedItems.map((i) => i.id).toList();
    setState(() {
      _currentScannedItems.clear();
    });
    for (final id in ids) {
      await _repository.deleteArticle(id);
    }
    await _reloadSessions();
  }

  Future<void> _removeDemoData() async {
    final removed = await _repository.removeDemoData();
    await _reloadSessions();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$removed session${removed > 1 ? 's' : ''} de démo retirée${removed > 1 ? 's' : ''}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ==================== SYNCHRONISATION HIVE ====================
  // Méthode centralisée pour recharger les sessions depuis Hive
  // On crée une NOUVELLE liste pour forcer le rebuild des widgets enfants
  Future<void> _reloadSessions() async {
    final allSessions = await _repository.getAllScans();
    // Articles modifiés ou supprimés ailleurs (détail d'une session) :
    // garder la liste courante de l'onglet Résultats alignée sur la base
    final storedById = {
      for (final session in allSessions)
        for (final item in session.items) item.id: item,
    };
    if (!mounted) return;
    setState(() {
      _sessions = List<ScanSession>.from(allSessions);
      final current = _currentScannedItems
          .where((i) => storedById.containsKey(i.id))
          .map((i) => storedById[i.id]!)
          .toList();
      _currentScannedItems
        ..clear()
        ..addAll(current);
    });
  }

  // Gestion des sessions — Étape 3c : persistance via ScanRepository
  // Solution robuste : recharger depuis Hive après sauvegarde pour synchronisation
  Future<void> _saveSession() async {
    if (_currentScannedItems.isEmpty) return;

    final storeName = _currentScannedItems.isNotEmpty
        ? _currentScannedItems.first.storeName
        : null;

    final session = ScanSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      items: List<ScannedItem>.from(_currentScannedItems),
      date: DateTime.now(),
      endDate: DateTime.now(),
      storeName: storeName,
      type: _currentScanType,
    );

    // Persister la session en base Hive
    await _repository.saveScan(session);
    
    // Recharger toutes les sessions et vider les items courants
    await _reloadSessions();
    setState(() {
      _currentScannedItems.clear();
    });
  }

  void _handleSessionSelected(ScanSession session) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SessionDetailScreen(
          session: session,
          onBack: () => Navigator.of(context).maybePop(),
          repository: _repository,
          onChanged: _reloadSessions,
        ),
      ),
    );
  }

  void _openProductSelection() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProductSelectionScreen(
          repository: _repository,
          onChanged: _reloadSessions,
        ),
      ),
    );
  }

  void _openProductDetail(String productId, String productName, {int initialTabIndex = 0}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProductDetailScreen(
          repository: _repository,
          productId: productId,
          productName: productName,
          initialTabIndex: initialTabIndex,
          onChanged: _reloadSessions,
        ),
      ),
    );
  }

  Future<void> _handleSessionDeleted(ScanSession session) async {
    // Supprimer de la base Hive
    await _repository.deleteScan(session.id);
    
    // Recharger les sessions pour synchronisation
    await _reloadSessions();

    // Vérifier que le widget est toujours mounted avant d'afficher le SnackBar
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            'Session supprimée',
            style: TextStyle(color: Colors.white),
          ),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _clearAllSessions() async {
    // Supprimer tout de la base Hive
    await _repository.clearAllScans();
    
    // Recharger pour synchronisation (sera vide)
    await _reloadSessions();
  }

  @override
  Widget build(BuildContext context) {
    // Les pages sont construites dynamiquement pour toujours refléter
    // l'état courant de _sessions et _currentScannedItems.
    final pages = [
      // Page d'accueil : les 3 actions principales
      HomeScreen(
        key: const ValueKey('home_screen'),
        onScanBarcode: () => _openScanner(barcode: true),
        onScanTicket: () => _openScanner(barcode: false),
        onOpenAnalysis: () => _goToTab(_dashboardTab),
      ),
      // Page Scanner
      ScanScreen(
        key: const ValueKey('scan_screen'),
        scannedItems: _currentScannedItems,
        onItemScanned: _handleItemScanned,
        onViewResults: () => _goToTab(_resultsTab),
        onViewHistory: () => _goToTab(_historyTab),
        onBack: _goBack,
        repository: _repository,
        onScanTypeChanged: _handleScanTypeChanged,
        onScanSaved: _reloadSessions,
        isActive: _currentIndex == _scanTab,
        requestedBarcodeMode: _requestedBarcodeMode,
        modeRequestId: _modeRequestId,
      ),
      // Page Resultats
      ResultsScreen(
        key: const ValueKey('results_screen'),
        scannedItems: _currentScannedItems,
        onBack: _goBack,
        onScan: () => _goToTab(_scanTab),
        onItemRemoved: _handleItemRemoved,
        onClearAll: _clearAllItems,
        onSaveSession: _saveSession,
        onItemUpdated: _handleItemUpdated,
      ),
      // Page Tableau de bord (Étape 5b)
      DashboardScreen(
        key: const ValueKey('dashboard_screen'),
        sessions: _sessions,
        repository: _repository,
        onSessionSelected: _handleSessionSelected,
        onProductAnalysisRequested: _openProductSelection,
        onProductSelected: _openProductDetail,
        onBack: _goBack,
      ),
      // Page Historique
      HistoryScreen(
        key: const ValueKey('history_screen'),
        sessions: _sessions,
        onSessionSelected: _handleSessionSelected,
        onSessionDeleted: _handleSessionDeleted,
        onClearAll: _clearAllSessions,
        onRemoveDemoData: _removeDemoData,
        onBack: _goBack,
      ),
    ];

    // Bouton retour d'Android : onglet précédent ; l'app ne se ferme que
    // depuis l'accueil
    return PopScope(
      canPop: _currentIndex == _homeTab,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: pages,
        ),
        bottomNavigationBar: _buildBottomNavigationBar(),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: _goToTab,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Accueil',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.qr_code_scanner),
          label: 'Scanner',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.receipt_long),
          label: 'Résultats',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.analytics),
          label: 'Dashboard',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.history),
          label: 'Historique',
        ),
      ],
    );
  }
}
