import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'theme.dart';
import 'models.dart';
import 'screens/scan_screen.dart';
import 'screens/results_screen.dart';
import 'screens/history_screen.dart';
import 'screens/session_detail_screen.dart';
import 'screens/dashboard_screen.dart';
import 'services/scan_repository.dart';

// Point d'entree de l'application
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Étape 3a — Initialisation de Hive
  await Hive.initFlutter();

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
  int _currentIndex = 0;

  // Etat de l'application
  final List<ScannedItem> _currentScannedItems = [];
  List<ScanSession> _sessions = [];  // Non-final pour permettre le remplacement complet
  String _currentScanType = 'barcode'; // 'barcode' ou 'ticket'

  // Repository pour la persistance
  final ScanRepository _repository = ScanRepository();

  @override
  void initState() {
    super.initState();

    // Étape 3a — Initialisation du repository et chargement des données persistées
    _initRepository();
  }

  /// Met à jour le type de scan actuel
  void _handleScanTypeChanged(String type) {
    setState(() {
      _currentScanType = type;
    });
  }

  /// Initialise le repository et charge les sessions persistées
  Future<void> _initRepository() async {
    try {
      await _repository.init();
      final savedSessions = await _repository.getAllScans();
      print('DEBUG MainScreen: savedSessions.length = ${savedSessions.length}');

      setState(() {
        if (savedSessions.isEmpty) {
          // Première utilisation : charger les données de démo
          print('DEBUG MainScreen: Chargement des demoSessions (Hive vide)');
          _sessions = List<ScanSession>.from(ScanSession.demoSessions);
        } else {
          print('DEBUG MainScreen: Chargement de ${savedSessions.length} sessions depuis Hive');
          _sessions = List<ScanSession>.from(savedSessions);
        }
        print('DEBUG MainScreen: _sessions.length final = ${_sessions.length}');
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

  void _handleItemRemoved(ScannedItem item) {
    setState(() {
      _currentScannedItems.removeWhere((i) => i.id == item.id);
    });
  }

  void _clearAllItems() {
    setState(() {
      _currentScannedItems.clear();
    });
  }

  // ==================== SYNCHRONISATION HIVE ====================
  // Méthode centralisée pour recharger les sessions depuis Hive
  // On crée une NOUVELLE liste pour forcer le rebuild des widgets enfants
  Future<void> _reloadSessions() async {
    final allSessions = await _repository.getAllScans();
    print('DEBUG MainScreen: _reloadSessions - allSessions.length = ${allSessions.length}');
    setState(() {
      _sessions = List<ScanSession>.from(allSessions);
      print('DEBUG MainScreen: _reloadSessions - _sessions.length = ${_sessions.length}');
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
          onBack: () => Navigator.of(context).pop(),
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
      // Page Scanner
      ScanScreen(
        key: const ValueKey('scan_screen'),
        scannedItems: _currentScannedItems,
        onItemScanned: _handleItemScanned,
        onViewResults: () => setState(() => _currentIndex = 1),
        onViewHistory: () async {
          await _reloadSessions();
          setState(() => _currentIndex = 3);
        },
        repository: _repository,
        onScanTypeChanged: _handleScanTypeChanged,
        onScanSaved: _reloadSessions,
      ),
      // Page Resultats
      ResultsScreen(
        key: const ValueKey('results_screen'),
        scannedItems: _currentScannedItems,
        onBack: () => setState(() => _currentIndex = 0),
        onItemRemoved: _handleItemRemoved,
        onClearAll: _clearAllItems,
        onSaveSession: _saveSession,
      ),
      // Page Tableau de bord (Étape 5b)
      DashboardScreen(
        key: const ValueKey('dashboard_screen'),
        sessions: _sessions,
        onSessionSelected: _handleSessionSelected,
      ),
      // Page Historique
      HistoryScreen(
        key: const ValueKey('history_screen'),
        sessions: _sessions,
        onSessionSelected: _handleSessionSelected,
        onSessionDeleted: _handleSessionDeleted,
        onClearAll: _clearAllSessions,
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) async {
        // Recharger les sessions si on va vers Dashboard (2) ou Historique (3)
        if (index == 2 || index == 3) {
          print('DEBUG MainScreen: Navigation vers onglet $index, rechargement des sessions...');
          await _reloadSessions();
        }
        setState(() => _currentIndex = index);
      },
      items: const [
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
