import 'package:flutter/material.dart';

import '../../analytics/analytics.dart';
import '../../models.dart';
import '../../services/scan_repository.dart';
import '../../theme.dart';
import 'section_header.dart';

/// Section « Alertes prix » : hausses récentes au-delà d'un seuil réglable
class PriceAlertsSection extends StatefulWidget {
  static const int maxDisplayed = 5;

  final List<ScanSession> sessions;

  /// Pour mémoriser le seuil choisi (facultatif)
  final ScanRepository? repository;
  final void Function(String productId, String productName) onProductTap;

  const PriceAlertsSection({
    super.key,
    required this.sessions,
    required this.onProductTap,
    this.repository,
  });

  @override
  State<PriceAlertsSection> createState() => _PriceAlertsSectionState();
}

class _PriceAlertsSectionState extends State<PriceAlertsSection> {
  int _threshold = PriceAlert.defaultThreshold;

  @override
  void initState() {
    super.initState();
    final repository = widget.repository;
    if (repository != null) {
      repository.ready.then((_) {
        if (mounted) setState(() => _threshold = repository.getPriceAlertThreshold(fallback: _threshold));
      });
    }
  }

  void _setThreshold(int value) {
    setState(() => _threshold = value);
    widget.repository?.savePriceAlertThreshold(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alerts = PriceAlert.calculate(widget.sessions, thresholdPercent: _threshold);
    final displayed = alerts.take(PriceAlertsSection.maxDisplayed).toList();

    return Column(
      key: const ValueKey('price_alerts_section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DashboardSectionHeader(
          icon: Icons.notifications_active_outlined,
          title: 'Alertes prix',
          subtitle: 'Hausses d\'au moins $_threshold % depuis ton scan précédent dans le même magasin',
        ),
        Wrap(
          spacing: 8,
          children: PriceAlert.thresholdChoices.map((value) {
            return ChoiceChip(
              key: ValueKey('alert_threshold_$value'),
              label: Text('$value %'),
              selected: _threshold == value,
              onSelected: (_) => _setThreshold(value),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: AppTheme.glassmorphism(),
          padding: const EdgeInsets.all(14),
          child: alerts.isEmpty
              ? Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: AppTheme.success, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Aucune hausse de $_threshold % ou plus sur tes produits.',
                        style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...displayed.map((alert) => _PriceAlertTile(
                          alert: alert,
                          onTap: () => widget.onProductTap(alert.productId, alert.name),
                        )),
                    if (alerts.length > displayed.length)
                      Text(
                        '+ ${alerts.length - displayed.length} autre${alerts.length - displayed.length > 1 ? 's' : ''} hausse${alerts.length - displayed.length > 1 ? 's' : ''}',
                        style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _PriceAlertTile extends StatelessWidget {
  final PriceAlert alert;
  final VoidCallback onTap;

  const _PriceAlertTile({required this.alert, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '+${alert.increasePercent.toStringAsFixed(0)} %',
                style: const TextStyle(color: AppTheme.error, fontWeight: FontWeight.w800, fontSize: 12),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${alert.storeName} : ${alert.previousPrice.toStringAsFixed(2)} → ${alert.latestPrice.toStringAsFixed(2)} €',
                    style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary, fontSize: 11),
                  ),
                  if (alert.cheaperStore != null)
                    Text(
                      'Moins cher chez ${alert.cheaperStore} : ${alert.cheaperPrice!.toStringAsFixed(2)} €',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.success,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}
