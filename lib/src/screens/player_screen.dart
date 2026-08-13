import 'dart:io';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../models/track.dart';
import '../services/download_service.dart';
import '../services/player_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerService>();
    final track = player.current;

    if (track == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final localArt = player.localThumbnail(track.id);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _ArtworkBackground(artUri: track.thumbnailUrl, local: localArt),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  _TopBar(trackId: track.id),
                  const Spacer(),
                  _Artwork(artUri: track.thumbnailUrl, local: localArt),
                  const Spacer(),
                  _TrackInfo(title: track.title, artist: track.artist),
                  const SizedBox(height: 8),
                  _SeekBar(player: player),
                  const SizedBox(height: 4),
                  _Controls(player: player),
                  const SizedBox(height: 16),
                  _QueueButton(player: player),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String trackId;

  const _TopBar({required this.trackId});

  @override
  Widget build(BuildContext context) {
    final download = context.read<DownloadService>();
    final player = context.read<PlayerService>();
    final track = player.current;

    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: AppColors.textPrimary, size: 30),
        ),
        Expanded(
          child: Text(
            'En cours de lecture',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        if (track != null && !download.isDownloading(trackId))
          IconButton(
            onPressed: () => _startDownload(context, track),
            icon: Icon(
              download.active.containsKey(trackId) ||
                      player.isDownloaded(trackId)
                  ? Icons.check_circle
                  : Icons.download_rounded,
              color: AppColors.secondary,
              size: 26,
            ),
          )
        else
          const SizedBox(width: 48),
      ],
    );
  }

  Future<void> _startDownload(BuildContext context, Track track) async {
    final download = context.read<DownloadService>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await download.download(track);
      messenger.showSnackBar(
        const SnackBar(content: Text('Téléchargé dans la bibliothèque')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(friendlyDownloadError(e))),
      );
    }
  }
}

class _ArtworkBackground extends StatelessWidget {
  final String artUri;
  final File? local;

  const _ArtworkBackground({required this.artUri, this.local});

  @override
  Widget build(BuildContext context) {
    final image = local != null
        ? Image.file(local!, fit: BoxFit.cover, width: double.infinity)
        : CachedNetworkImage(
            imageUrl: artUri,
            fit: BoxFit.cover,
            width: double.infinity,
            errorWidget: (_, _, _) => Container(
              decoration: BoxDecoration(gradient: AppColors.gradient),
            ),
          );
    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
          child: image,
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                AppColors.background.withValues(alpha: 0.92),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Artwork extends StatelessWidget {
  final String artUri;
  final File? local;

  const _Artwork({required this.artUri, this.local});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.width * 0.62;
    final image = local != null
        ? Image.file(local!, fit: BoxFit.cover)
        : CachedNetworkImage(
            imageUrl: artUri,
            fit: BoxFit.cover,
            placeholder: (_, _) => Center(
              child: CircularProgressIndicator(color: AppColors.secondary),
            ),
            errorWidget: (_, _, _) => Container(
              decoration: BoxDecoration(gradient: AppColors.gradient),
              child: const Icon(Icons.music_note,
                  size: 80, color: Colors.white70),
            ),
          );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.45),
            blurRadius: 60,
            spreadRadius: 4,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: image,
    );
  }
}

class _TrackInfo extends StatelessWidget {
  final String title;
  final String artist;

  const _TrackInfo({required this.title, required this.artist});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 15,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _SeekBar extends StatelessWidget {
  final PlayerService player;

  const _SeekBar({required this.player});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration?>(
      stream: player.durationStream,
      builder: (context, durSnap) {
        final duration = durSnap.data;
        if (duration == null || duration.inMilliseconds <= 0) {
          return const SizedBox(height: 52);
        }
        return StreamBuilder<Duration>(
          stream: player.positionStream,
          builder: (context, posSnap) {
            final position = posSnap.data ?? Duration.zero;
            final fraction =
                (position.inMilliseconds / duration.inMilliseconds)
                    .clamp(0.0, 1.0);
            return Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 16),
                    activeTrackColor: AppColors.primary,
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
                    thumbColor: AppColors.textPrimary,
                    overlayColor: AppColors.primary.withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: fraction,
                    onChanged: (v) =>
                        player.seek(Duration(milliseconds: (v * duration.inMilliseconds).round())),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(formatDuration(position),
                          style: _timeStyle),
                      Text(formatDuration(duration), style: _timeStyle),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static final _timeStyle = TextStyle(
    fontSize: 12,
    color: AppColors.textSecondary,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

class _Controls extends StatelessWidget {
  final PlayerService player;

  const _Controls({required this.player});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          onPressed: player.cycleShuffle,
          icon: Icon(
            Icons.shuffle_rounded,
            color: player.shuffleEnabled
                ? AppColors.secondary
                : AppColors.textSecondary,
          ),
          iconSize: 26,
        ),
        IconButton(
          onPressed: player.previous,
          icon: Icon(Icons.skip_previous_rounded,
              color: AppColors.textPrimary, size: 40),
        ),
        _PlayPauseButton(player: player),
        IconButton(
          onPressed: player.next,
          icon: Icon(Icons.skip_next_rounded,
              color: AppColors.textPrimary, size: 40),
        ),
        _LoopButton(player: player),
      ],
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  final PlayerService player;

  const _PlayPauseButton({required this.player});

  @override
  Widget build(BuildContext context) {
    if (player.isPreparing) {
      return Padding(
        padding: EdgeInsets.all(18),
        child: SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(color: AppColors.secondary),
        ),
      );
    }
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.gradient,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.5),
            blurRadius: 24,
            spreadRadius: 1,
          ),
        ],
      ),
      child: IconButton(
        onPressed: () => player.toggle(),
        iconSize: 40,
        padding: EdgeInsets.zero,
        icon: Icon(
          player.isPlaying
              ? Icons.pause_rounded
              : Icons.play_arrow_rounded,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _LoopButton extends StatelessWidget {
  final PlayerService player;

  const _LoopButton({required this.player});

  @override
  Widget build(BuildContext context) {
    final (icon, active) = switch (player.loopMode) {
      LoopMode.off => (Icons.repeat_rounded, false),
      LoopMode.all => (Icons.repeat_rounded, true),
      LoopMode.one => (Icons.repeat_one_rounded, true),
    };
    return IconButton(
      onPressed: player.cycleLoopMode,
      icon: Icon(icon,
          color: active ? AppColors.secondary : AppColors.textSecondary),
      iconSize: 26,
    );
  }
}

class _QueueButton extends StatelessWidget {
  final PlayerService player;

  const _QueueButton({required this.player});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _showQueue(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.queue_music_rounded,
                color: AppColors.textSecondary, size: 20),
            const SizedBox(width: 8),
            Text(
              'File d\'attente (${player.queue.length})',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQueue(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final p = context.watch<PlayerService>();
        final queue = p.queue;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'File d\'attente',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: queue.length,
                  itemBuilder: (context, i) {
                    final t = queue[i];
                    final active = i == p.index;
                    return ListTile(
                      leading: active
                          ? Icon(Icons.graphic_eq,
                              color: AppColors.secondary)
                          : Icon(Icons.music_note,
                              color: AppColors.textSecondary),
                      title: Text(
                        t.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: active
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                          fontWeight:
                              active ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                      onTap: () => p.seekToTrack(i),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
