// Barre du bas de l'app : quatre onglets et le bouton Scanner au centre
import 'package:flutter/material.dart';

import '../../theme.dart';

/// Un onglet de la barre du bas
class AppNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const AppNavItem(this.icon, this.activeIcon, this.label);
}

/// Barre du bas : deux onglets, le bouton Scanner lumineux au centre (sous le
/// pouce, accessible depuis n'importe quel écran), deux onglets.
class AppNavBar extends StatelessWidget {
  final List<AppNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onScan;

  const AppNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    required this.onScan,
  }) : assert(items.length == 4);

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return SizedBox(
      height: 76 + bottom,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // Fond de la barre
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 24, offset: const Offset(0, -6)),
                ],
              ),
              padding: EdgeInsets.only(bottom: bottom),
              child: Row(
                children: [
                  for (var i = 0; i < 2; i++) Expanded(child: _item(i)),
                  const SizedBox(width: 84),
                  for (var i = 2; i < 4; i++) Expanded(child: _item(i)),
                ],
              ),
            ),
          ),
          // Bouton Scanner, surélevé et lumineux
          Positioned(
            top: -26,
            child: _ScanFab(onPressed: onScan),
          ),
        ],
      ),
    );
  }

  Widget _item(int index) {
    final item = items[index];
    final active = index == currentIndex;
    final color = active ? AppTheme.primary : AppTheme.textMuted;
    return InkWell(
      key: ValueKey('nav_tab_$index'),
      onTap: () => onTap(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Trait lumineux au-dessus de l'onglet actif
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: active ? 22 : 0,
            height: 3,
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(2),
              boxShadow: active
                  ? [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.8), blurRadius: 10)]
                  : null,
            ),
          ),
          Icon(active ? item.activeIcon : item.icon, color: color, size: 24),
          const SizedBox(height: 3),
          Text(
            item.label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanFab extends StatelessWidget {
  final VoidCallback onPressed;

  const _ScanFab({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Scanner',
      child: GestureDetector(
        key: const ValueKey('nav_scan'),
        onTap: onPressed,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppTheme.accent, AppTheme.primary, Color(0xFF0066FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: AppTheme.backgroundDark, width: 4),
                boxShadow: [
                  BoxShadow(color: AppTheme.primary.withValues(alpha: 0.6), blurRadius: 22, spreadRadius: 1),
                  BoxShadow(color: AppTheme.accent.withValues(alpha: 0.25), blurRadius: 40, spreadRadius: 4),
                ],
              ),
              child: const Icon(Icons.qr_code_scanner, color: AppTheme.backgroundDark, size: 32),
            ),
            const SizedBox(height: 2),
            const Text(
              'Scanner',
              style: TextStyle(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
