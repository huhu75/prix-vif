import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'theme.dart';
import 'models.dart';
import 'screens/scan_screen.dart';
import 'screens/results_screen.dart';
import 'screens/history_screen.dart';
import 'screens/session_detail_screen.dart';
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
  final List<ScanSession> _sessions = [];
  String _currentScanType = 'barcode'; // 'barcode' ou 'ticket'

  // Repository pour la persistance
  final ScanRepository _repository = ScanRepository();

  // Pages
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();

    // Étape 3a — Initialisation du repository et chargement des données persistées
    _initRepository();

    _pages = [
      // Page Scanner
      ScanScreen(
        scannedItems: _currentScannedItems,
        onItemScanned: _handleItemScanned,
        onViewResults: () => setState(() => _currentIndex = 1),
        onViewHistory: () => setState(() => _currentIndex = 2),
        repository: _repository,
        onScanTypeChanged: _handleScanTypeChanged,
      ),
      // Page Resultats
      ResultsScreen(
        scannedItems: _currentScannedItems,
        onBack: () => setState(() => _currentIndex = 0),
        onItemRemoved: _handleItemRemoved,
        onClearAll: _clearAllItems,
        onSaveSession: _saveSession,
      ),
      // Page Historique
      HistoryScreen(
        sessions: _sessions,
        onSessionSelected: _handleSessionSelected,
        onSessionDeleted: _handleSessionDeleted,
        onClearAll: _clearAllSessions,
      ),
    ];
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

      setState(() {
        _sessions.clear();
        if (savedSessions.isEmpty) {
          // Première utilisation : charger les données de démo
          _sessions.addAll(ScanSession.demoSessions);
        } else {
          _sessions.addAll(savedSessions);
        }
      });
    } catch (e) {
      print('Erreur initialisation repository: $e');
      setState(() {
        // Fallback : charger les données de démo
        _sessions.addAll(ScanSession.demoSessions);
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

  // Gestion des sessions — Étape 3c : persistance via ScanRepository
  void _saveSession() {
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

    setState(() {
      _sessions.insert(0, session);
      _currentScannedItems.clear();
    });

    // Persister la session en base Hive
    _repository.saveScan(session);
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

  void _handleSessionDeleted(ScanSession session) {
    setState(() {
      _sessions.removeWhere((s) => s.id == session.id);
    });

    // Supprimer de la base Hive
    _repository.deleteScan(session.id);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Colors.red,
        content: Text(
          'Session supprimee',
          style: TextStyle(color: Colors.white),
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _clearAllSessions() {
    setState(() {
      _sessions.clear();
    });

    // Supprimer tout de la base Hive
    _repository.clearAllScans();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) => setState(() => _currentIndex = index),
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
          icon: Icon(Icons.history),
          label: 'Historique',
        ),
      ],
    );
  }
}
