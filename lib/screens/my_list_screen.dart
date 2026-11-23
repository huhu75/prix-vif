// Onglet Ma liste : où faire ses courses (version provisoire : le panier
// habituel ; la vraie liste de courses arrive à une étape suivante)
import 'package:flutter/material.dart';

import '../analytics/analytics.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/dashboard/empty_dashboard_state.dart';
import '../widgets/dashboard/stores_tab.dart';
import '../widgets/magic_title.dart';
import 'home_screen.dart' show ProductTap;

class MyListScreen extends StatelessWidget {
  final List<ScanSession> sessions;
  final ProductTap onProductTap;

  static const int _storesTab = 2;

  const MyListScreen({super.key, required this.sessions, required this.onProductTap});

  @override
  Widget build(BuildContext context) {
    final stats = sessions.isEmpty ? null : DashboardStats.fromSessions(sessions);
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(title: const NeonTitle(text: 'MA LISTE', fontSize: 20)),
      body: stats == null
          ? const EmptyDashboardState()
          : StoresTab(
              basket: stats.shoppingBasket,
              cheapestByStore: stats.cheapestByStore,
              onProductTap: (id, name) => onProductTap(id, name, initialTabIndex: _storesTab),
            ),
    );
  }
}
