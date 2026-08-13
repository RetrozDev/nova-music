import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/download_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';

/// Affiche tous les téléchargements en cours avec une vraie barre de
/// progression, le pourcentage et la vitesse instantanée.
class DownloadProgressPanel extends StatelessWidget {
  const DownloadProgressPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final download = context.watch<DownloadService>();
    final active = download.active.values.toList();
    if (active.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
          child: Row(
            children: [
              Icon(Icons.downloading_rounded,
                  size: 18, color: AppColors.secondary),
              const SizedBox(width: 6),
              Text(
                'Téléchargements en cours (${active.length})',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        for (final item in active)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: _ActiveDownloadTile(item: item),
          ),
        const SizedBox(height: 6),
      ],
    );
  }
}

class _ActiveDownloadTile extends StatelessWidget {
  final ActiveDownload item;

  const _ActiveDownloadTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final fraction = item.fraction;
    final percent = fraction == null
        ? null
        : (fraction * 100).clamp(0, 100).toStringAsFixed(0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 44,
              height: 44,
              child: CachedNetworkImage(
                imageUrl: item.track.thumbnailUrl,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => Container(
                  color: AppColors.surfaceAlt,
                  child: Icon(Icons.music_note,
                      color: AppColors.textSecondary),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 6,
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    valueColor:
                        AlwaysStoppedAnimation(AppColors.secondary),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      percent == null
                          ? 'Téléchargement…'
                          : '$percent%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.secondary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _details(),
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _details() {
    if (item.totalBytes <= 0) return '';
    final speed = item.speedBytesPerSec > 0
        ? ' • ${formatBytes(item.speedBytesPerSec)}/s'
        : '';
    return '${formatBytes(item.receivedBytes)} / ${formatBytes(item.totalBytes)}$speed';
  }
}
