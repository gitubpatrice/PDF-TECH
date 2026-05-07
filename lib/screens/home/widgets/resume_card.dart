import 'package:files_tech_core/files_tech_core.dart';
import 'package:flutter/material.dart';

/// Carte "Reprendre" en haut de l'écran d'accueil — accès rapide au dernier
/// PDF ouvert.
class ResumeCard extends StatelessWidget {
  final RecentFile file;
  final String Function(DateTime) formatDate;
  final VoidCallback onTap;

  const ResumeCard({
    super.key,
    required this.file,
    required this.formatDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFC62828); // Material Red 700 — identité PDF
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.picture_as_pdf, color: color, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${formatDate(file.lastOpened)} · ${file.formattedSize}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.play_circle_fill,
                color: color.withValues(alpha: 0.8),
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
