import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../models/library_track.dart';
import '../models/track.dart';
import 'library_service.dart';
import 'youtube_service.dart';

class DownloadProgress {
  final String id;
  final int receivedBytes;
  final int totalBytes;

  const DownloadProgress({
    required this.id,
    required this.receivedBytes,
    required this.totalBytes,
  });

  double? get fraction =>
      totalBytes > 0 ? (receivedBytes / totalBytes).clamp(0.0, 1.0) : null;
}

class DownloadService extends ChangeNotifier {
  final YoutubeService _yt;
  final LibraryService _library;

  final Map<String, DownloadProgress> _active = {};

  DownloadService(this._yt, this._library);

  Map<String, DownloadProgress> get active => Map.unmodifiable(_active);

  bool isDownloading(String id) => _active.containsKey(id);

  Future<void> download(Track track) async {
    final id = track.id;
    if (_active.containsKey(id) || _library.isDownloaded(id)) return;

    _active[id] = DownloadProgress(id: id, receivedBytes: 0, totalBytes: 0);
    notifyListeners();

    try {
      final result = await _yt.downloadStream(id);
      final fileName = '$id.${result.extension}';
      final filePath = p.join(_library.musicDir, fileName);
      final file = File(filePath);
      final sink = file.openWrite();
      var received = 0;
      try {
        await for (final chunk in result.stream) {
          received += chunk.length;
          sink.add(chunk);
          _active[id] = DownloadProgress(
            id: id,
            receivedBytes: received,
            totalBytes: result.sizeBytes,
          );
          notifyListeners();
        }
        await sink.close();
      } catch (_) {
        await sink.close();
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
