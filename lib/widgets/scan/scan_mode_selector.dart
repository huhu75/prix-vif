// Bascule entre le scan de code-barres et la photo de ticket
import 'package:flutter/material.dart';
import '../../theme.dart';

/// Bascule CODE-BARRES / TICKET ; [onChanged] reçoit `true` pour le mode code-barres.
class ScanModeSelector extends StatelessWidget {
  final bool isBarcodeMode;
  final ValueChanged<bool> onChanged;

  const ScanModeSelector({super.key, required this.isBarcodeMode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2), width: 1),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(true),
                child: Container(
                  decoration: BoxDecoration(
                    color: isBarcodeMode ? AppTheme.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'CODE-BARRES',
                    style: TextStyle(
                      color: isBarcodeMode ? AppTheme.backgroundDark : AppTheme.textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(false),
                child: Container(
                  decoration: BoxDecoration(
                    color: !isBarcodeMode ? AppTheme.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'TICKET',
                    style: TextStyle(
                      color: !isBarcodeMode ? AppTheme.backgroundDark : AppTheme.textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
