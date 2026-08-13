import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../models/library_track.dart';
import '../models/track.dart';
import 'library_service.dart';
import 'youtube_service.dart';

class ActiveDownload {
  final Track track;
  final int receivedBytes;
  final int totalBytes;
  final double speedBytesPerSec;

  const ActiveDownload({
    required this.track,
    required this.receivedBytes,
    required this.totalBytes,
    this.speedBytesPerSec = 0,
  });

  double? get fraction => totalBytes > 0
      ? (receivedBytes / totalBytes).clamp(0.0, 1.0)
      : null;
}

class DownloadService extends ChangeNotifier {
  final YoutubeService _yt;
  final LibraryService _library;

  final Map<String, ActiveDownload> _active = {};

  DownloadService(this._yt, this._library);

  Map<String, ActiveDownload> get active => Map.unmodifiable(_active);

  bool isDownloading(String id) => _active.containsKey(id);

  Future<void> download(Track track) async {
    final id = track.id;
    if (_active.containsKey(id) || _library.isDownloaded(id)) return;

    _active[id] = ActiveDownload(
      track: track,
      receivedBytes: 0,
      totalBytes: 0,
    );
    notifyListeners();

    try {
      final result = await _yt.downloadStream(id);
      final fileName = '$id.${result.extension}';
      final filePath = p.join(_library.musicDir, fileName);
      final file = File(filePath);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
      final sink = file.openWrite();

      var received = 0;
      var lastBytes = 0;
      var lastTick = DateTime.now();
      var ema = 0.0;

      final timed = result.stream.timeout(
        const Duration(seconds: 45),
        onTimeout: (EventSink<List<int>> eventSink) => eventSink.addError(
          TimeoutException(
              'La connexion de téléchargement est restée bloquée.'),
        ),
      );

      try {
        await for (final chunk in timed) {
          received += chunk.length;
          sink.add(chunk);

          final now = DateTime.now();
          final dt = now.difference(lastTick).inMilliseconds;
          if (dt >= 120) {
            final instant = (received - lastBytes) * 1000 / dt;
            ema = ema == 0 ? instant : ema * 0.6 + instant * 0.4;
            lastBytes = received;
            lastTick = now;
          }

          _active[id] = ActiveDownload(
            track: track,
            receivedBytes: received,
            totalBytes: result.sizeBytes,
            speedBytesPerSec: ema,
          );
          notifyListeners();
        }
        await sink.close();
      } catch (_) {
        await sink.close();
        if (await file.exists()) {
          try {
            await file.delete();
          } catch (_) {}
        }
        rethrow;
      }

      final thumbnailPath = p.join(_library.musicDir, '$id.jpg');
      try {
        final response = await http.get(Uri.parse(track.thumbnailUrl));
        if (response.statusCode == 200) {
          await File(thumbnailPath).writeAsBytes(response.bodyBytes, flush: true);
        }
      } catch (_) {}

      await _library.add(LibraryTrack(
        id: id,
        title: track.title,
        artist: track.artist,
        durationMs: track.duration?.inMilliseconds ?? 0,
        thumbnailUrl: track.thumbnailUrl,
        filePath: filePath,
        addedAt: DateTime.now(),
      ));
    } finally {
      _active.remove(id);
      notifyListeners();
    }
  }
}
