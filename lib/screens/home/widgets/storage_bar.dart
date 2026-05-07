import 'package:flutter/material.dart';

/// Barre horizontale "X utilisés sur Y" du stockage interne. Couleur
/// adaptative selon le ratio (vert/orange/rouge).
class StorageBar extends StatelessWidget {
  final int freeBytes;
  final int totalBytes;
  final String Function(int) formatBytes;

  const StorageBar({
    super.key,
    required this.freeBytes,
    required this.totalBytes,
    required this.formatBytes,
  });

  @override
  Widget build(BuildContext context) {
    final usedBytes = totalBytes - freeBytes;
    final ratio = totalBytes > 0 ? usedBytes / totalBytes : 0.0;
    final color = ratio > 0.9
        ? Colors.red
        : ratio > 0.75
        ? Colors.orange
        : Theme.of(context).colorScheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  formatBytes(usedBytes),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: color,
                    fontSize: 15,
                  ),
                ),
                Text(
                  ' utilisés sur ${formatBytes(totalBytes)}',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const Spacer(),
                Text(
                  '${formatBytes(freeBytes)} libres',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio.toDouble(),
                minHeight: 7,
                backgroundColor: color.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
