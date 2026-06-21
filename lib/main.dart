import 'package:flutter/material.dart';
import 'theme.dart';
import 'models.dart';
import 'screens/scan_screen.dart';
import 'screens/results_screen.dart';
import 'screens/history_screen.dart';
import 'screens/session_detail_screen.dart';

// Point d'entree de l'application
void main() {
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

  // Pages
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    // Initialiser avec des sessions de demo
    _sessions.addAll(ScanSession.demoSessions);

    _pages = [
      // Page Scanner
      ScanScreen(
        scannedItems: _currentScannedItems,
        onItemScanned: _handleItemScanned,
        onViewResults: () => setState(() => _currentIndex = 1),
        onViewHistory: () => setState(() => _currentIndex = 2),
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

  // Gestion des sessions
  void _saveSession() {
    if (_currentScannedItems.isEmpty) return;

    final session = ScanSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      items: List<ScannedItem>.from(_currentScannedItems),
      date: DateTime.now(),
      endDate: DateTime.now(),
    );

    setState(() {
      _sessions.insert(0, session);
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

  void _handleSessionDeleted(ScanSession session) {
    setState(() {
      _sessions.removeWhere((s) => s.id == session.id);
    });

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
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black.withOpacity(0.8),
            Colors.black.withOpacity(0.9),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
          width: 1,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 30,
            spreadRadius: 0,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          backgroundColor: Colors.transparent,
          selectedItemColor: const Color(0xFF00F5FF),
          unselectedItemColor: const Color(0xFFB0B0B0),
          selectedLabelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w400,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.qr_code_scanner, size: 22),
              label: 'Scanner',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long, size: 22),
              label: 'Resultats',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history, size: 22),
              label: 'Historique',
            ),
          ],
        ),
      ),
    );
  }
}
