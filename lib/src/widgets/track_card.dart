import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/track.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';

class TrackCard extends StatelessWidget {
  final Track track;
  final bool isPlaying;
  final VoidCallback? onTap;
  final VoidCallback? onDownload;
  final bool downloading;
  final double? progress;
  final String? localThumbnailPath;

  const TrackCard({
    super.key,
    required this.track,
    this.isPlaying = false,
    this.onTap,
    this.onDownload,
    this.downloading = false,
    this.progress,
    this.localThumbnailPath,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: isPlaying
                ? AppColors.primary.withValues(alpha: 0.18)
                : AppColors.surface,
            border: isPlaying
                ? Border.all(color: AppColors.primary.withValues(alpha: 0.6))
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                _Thumb(track: track, path: localThumbnailPath),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        track.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatDuration(track.duration),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (downloading)
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          value: progress,
                          color: AppColors.secondary,
                        ),
                      )
                    else
                      IconButton(
                        onPressed: onDownload,
                        iconSize: 20,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Télécharger',
                        icon: const Icon(
                          Icons.download_outlined,
                          color: AppColors.secondary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final Track track;
  final String? path;

  const _Thumb({required this.track, this.path});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: AppColors.surfaceAlt,
      child: const Icon(Icons.music_note, color: AppColors.textSecondary),
    );

    final image = (path != null && path!.isNotEmpty)
        ? Image.file(
            File(path!),
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => placeholder,
          )
        : CachedNetworkImage(
            imageUrl: track.thumbnailUrl,
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            placeholder: (_, _) => placeholder,
            errorWidget: (_, _, _) => placeholder,
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(width: 56, height: 56, child: image),
    );
  }
}
