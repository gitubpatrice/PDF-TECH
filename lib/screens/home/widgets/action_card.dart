import 'package:flutter/material.dart';

/// Carte d'action carrée affichée dans les grilles "Parcourir" et "Actions
/// rapides" de l'écran d'accueil. Icône colorée + label.
class ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const ActionCard({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // v1.12.5 (U1) — Semantics + Tooltip pour TalkBack et long-press hint :
    // les `ActionCard` étaient des `InkWell` purs, l'annonceur vocal ne
    // donnait que le label texte sans le rôle "bouton". `excludeSemantics`
    // évite que TalkBack lise séparément le texte enfant + le label parent.
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        button: true,
        excludeSemantics: true,
        onTapHint: 'Ouvrir',
        child: Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
