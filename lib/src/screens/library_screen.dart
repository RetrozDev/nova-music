import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/library_track.dart';
import '../services/library_service.dart';
import '../services/player_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/download_progress_panel.dart';
import '../widgets/theme_sheet.dart';
import '../widgets/update_sheet.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryService>();
    final tracks = library.tracks;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Bibliothèque',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Outfit',
                ),
              ),
            ),
            IconButton(
              onPressed: () => showThemeSheet(context),
              tooltip: 'Thème',
              icon: Icon(Icons.palette_outlined,
                  color: AppColors.textSecondary, size: 26),
            ),
            IconButton(
              onPressed: () => showUpdateSheet(context),
              tooltip: 'Mise à jour',
              icon: Icon(Icons.update_rounded,
                  color: AppColors.textSecondary, size: 26),
            ),
            if (tracks.isNotEmpty)
              IconButton(
                onPressed: () => _playAll(context, tracks),
                tooltip: 'Tout lire',
                icon: Icon(Icons.play_circle_fill_rounded,
                    color: AppColors.secondary, size: 34),
              ),
          ],
        ),
        Text(
          tracks.isEmpty
              ? 'Aucun téléchargement'
              : '${tracks.length} titre${tracks.length > 1 ? 's' : ''} disponible${tracks.length > 1 ? 's' : ''} hors-ligne',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),

        const DownloadProgressPanel(),

        if (tracks.isNotEmpty) ...[
          const _SectionTitle(title: 'Mes sons'),
          for (var i = 0; i < tracks.length; i++)
            _LibraryTile(
              track: tracks[i],
              index: i,
              isPlaying:
                  context.read<PlayerService>().current?.id == tracks[i].id,
              onPlay: () => _play(context, tracks, i),
              onDelete: () => _delete(context, tracks[i]),
            ),
        ] else
          const _EmptyLibrary(),
      ],
    );
  }

  Future<void> _playAll(BuildContext context, List<LibraryTrack> tracks) async {
    final player = context.read<PlayerService>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await player.playLibrary(tracks, index: 0);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Lecture impossible : $e')));
    }
  }

  Future<void> _play(
      BuildContext context, List<LibraryTrack> tracks, int index) async {
    final player = context.read<PlayerService>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await player.playLibrary(tracks, index: index);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Lecture impossible : $e')));
    }
  }

  Future<void> _delete(BuildContext context, LibraryTrack track) async {
    final library = context.read<LibraryService>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Supprimer ce titre ?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          '« ${track.title} » sera retiré de ton appareil.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await library.remove(track.id);
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _LibraryTile extends StatelessWidget {
  final LibraryTrack track;
  final int index;
  final bool isPlaying;
  final VoidCallback onPlay;
  final VoidCallback onDelete;

  const _LibraryTile({
    required this.track,
    required this.index,
    required this.isPlaying,
    required this.onPlay,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final thumbPath = File(track.thumbnailPath);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onPlay,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: isPlaying
                ? AppColors.primary.withValues(alpha: 0.18)
                : AppColors.surface,
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: thumbPath.existsSync()
                        ? Image.file(
                            thumbPath,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const _ThumbFallback(),
                          )
                        : CachedNetworkImage(
                            imageUrl: track.thumbnailUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) => const _ThumbFallback(),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.offline_pin_rounded,
                              size: 13, color: AppColors.secondary),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatDuration(Duration(milliseconds: track.durationMs)),
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: onDelete,
                  iconSize: 20,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.delete_outline_rounded,
                      color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThumbFallback extends StatelessWidget {
  const _ThumbFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceAlt,
      child: Icon(Icons.music_note, color: AppColors.textSecondary),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.gradientSoft,
            ),
            child: const Icon(Icons.download_rounded,
                size: 54, color: Colors.white),
          ),
          const SizedBox(height: 24),
          Text(
            'Ta bibliothèque est vide',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Recherche ta musique préférée et télécharge-la : elle sera disponible ici, même sans internet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
