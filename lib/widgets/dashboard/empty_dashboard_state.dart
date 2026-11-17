// Tableau de bord sans aucun scan
import 'package:flutter/material.dart';
import '../../theme.dart';

class EmptyDashboardState extends StatelessWidget {
  const EmptyDashboardState({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.analytics,
              color: AppTheme.primary,
              size: 40,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Aucune donnée',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Scannez vos premiers produits pour voir vos statistiques',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
