// Briques communes aux onglets du tableau de bord
import 'package:flutter/material.dart';

import '../../theme.dart';

/// Montant en euros (« 22.76 € »), comme dans le reste de l'app
String formatEuros(double value) => '${value.toStringAsFixed(2)} €';

/// Écart signé en euros (« +0.30 € », « −0.14 € »)
String formatSignedEuros(double value) => '${value >= 0 ? '+' : '−'}${value.abs().toStringAsFixed(2)} €';

/// Pourcentage signé arrondi (« +10 % », « −5 % »)
String formatSignedPercent(double value) => '${value >= 0 ? '+' : '−'}${value.abs().round()} %';

/// Carte d'un onglet du tableau de bord (fond translucide de l'app)
class DashboardCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const DashboardCard({super.key, required this.child, this.padding = const EdgeInsets.all(14)});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: AppTheme.glassmorphism(),
      padding: padding,
      child: child,
    );
  }
}

/// Message d'une carte vide (icône info + texte)
class DashboardEmptyMessage extends StatelessWidget {
  final String text;

  const DashboardEmptyMessage(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.info_outline, color: AppTheme.textMuted, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
          ),
        ),
      ],
    );
  }
}

/// Liste qui n'affiche que les [visibleCount] premiers éléments, avec un
/// bouton pour voir les autres (sans quitter l'onglet)
class ExpandableList extends StatefulWidget {
  final List<Widget> children;
  final int visibleCount;
  final String moreLabel;

  const ExpandableList({
    super.key,
    required this.children,
    this.visibleCount = 5,
    this.moreLabel = 'autres',
  });

  @override
  State<ExpandableList> createState() => _ExpandableListState();
}

class _ExpandableListState extends State<ExpandableList> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final hidden = widget.children.length - widget.visibleCount;
    final shown = _expanded || hidden <= 0 ? widget.children : widget.children.take(widget.visibleCount).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...shown,
        if (hidden > 0)
          TextButton.icon(
            key: const ValueKey('expandable_list_toggle'),
            onPressed: () => setState(() => _expanded = !_expanded),
            icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 18),
            label: Text(_expanded ? 'Réduire' : 'Voir les $hidden ${widget.moreLabel}'),
          ),
      ],
    );
  }
}
