import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../models/library_track.dart';
import '../models/track.dart';
import '../utils/constants.dart';
import '../utils/format.dart';
import 'library_service.dart';
import 'youtube_service.dart';

class ActiveDownload {
  final Track track;
  final double? percent;
  final int receivedBytes;
  final int totalBytes;
  final double speedBytesPerSec;
  final String? status;

  const ActiveDownload({
    required this.track,
    this.percent,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.speedBytesPerSec = 0,
    this.status,
  });

  double? get fraction {
    if (percent != null) return (percent! / 100).clamp(0.0, 1.0);
    if (totalBytes > 0) return (receivedBytes / totalBytes).clamp(0.0, 1.0);
    return null;
  }
}

class DownloadService extends ChangeNotifier {
  static const _ytdl = MethodChannel('nova_music/ytdl');
  static const _ytdlProgress = EventChannel('nova_music/ytdl_progress');

  final YoutubeService _yt;
  final LibraryService _library;
  final http.Client _http = http.Client();

  final Map<String, ActiveDownload> _active = {};

  DownloadService(this._yt, this._library) {
    _ytdlProgress.receiveBroadcastStream().listen(_onProgressEvent);
  }

  Map<String, ActiveDownload> get active => Map.unmodifiable(_active);

  bool isDownloading(String id) => _active.containsKey(id);

  void _onProgressEvent(Object? event) {
    if (event is! Map) return;
    final id = event['id'];
    if (id is! String) return;
    final prev = _active[id];
    if (prev == null) return;
    final type = event['type'] ?? 'progress';
    if (type == 'progress') {
      final percent = event['percent'];
      if (percent is num) {
        _active[id] = ActiveDownload(
          track: prev.track,
          percent: percent.toDouble(),
          status: prev.status,
        );
        notifyListeners();
      }
    } else if (type == 'log') {
      final line = event['line'];
      if (line is String) {
        _active[id] = ActiveDownload(
          track: prev.track,
          percent: prev.percent,
          status: line,
        );
        notifyListeners();
      }
    } else if (type == 'error') {
      final msg = event['message'];
      _active[id] = ActiveDownload(
        track: prev.track,
        percent: prev.percent,
        status: 'Erreur : ${msg ?? 'yt-dlp'}',
      );
      notifyListeners();
    }
  }

  Future<void> download(Track track) async {
    final id = track.id;
    if (_active.containsKey(id) || _library.isDownloaded(id)) return;

    _active[id] = ActiveDownload(track: track, percent: 0);
    notifyListeners();

    try {
      // Test d'écriture : vérifie que le stockage est accessible.
      final writeTest = File(p.join(_library.musicDir, '.write_test'));
      try {
        await writeTest.writeAsString('ok', flush: true);
        await writeTest.delete();
      } catch (e) {
        throw Exception(
          'Stockage inaccessible (${e is FileSystemException ? e.message : e}). '
          'Vérifie l\'espace disponible sur ton téléphone.',
        );
      }

      // 1) yt-dlp natif (téléchargement robuste + progression en %).
      final native = await _nativeDownload(id);
      var filePath = native.path;
      // 2) Repli : téléchargement HTTP à partir de l'URL du flux.
      if (filePath == null) {
        try {
          filePath = await _httpDownload(track);
        } catch (e) {
          throw Exception(native.error ?? friendlyDownloadError(e));
        }
      }

      final thumbnailPath = p.join(_library.musicDir, '$id.jpg');
      try {
        final response = await _http
            .get(Uri.parse(track.thumbnailUrl))
            .timeout(const Duration(seconds: 15));
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

  Future<({String? path, String? error})> _nativeDownload(String id) async {
    final outputPath = p.join(_library.musicDir, id);
    try {
      final path = await _ytdl
          .invokeMethod<String>('download', {
        'videoId': id,
        'outputPath': outputPath,
      }).timeout(const Duration(minutes: 6));
      if (path == null || path.isEmpty) {
        return (path: null, error: 'yt-dlp n\'a pas produit de fichier.');
      }
      return (path: await File(path).exists() ? path : null, error: null);
    } on PlatformException catch (e) {
      return (path: null, error: e.message ?? 'Échec de yt-dlp.');
    } catch (_) {
      return (
        path: null,
        error: 'Téléchargement yt-dlp trop long (réseau bloqué ?).',
      );
    }
  }

  Future<String> _httpDownload(Track track) async {
    final id = track.id;
    var resolved = await _yt.downloadStream(id);
    final filePath = p.join(_library.musicDir, '$id.${resolved.extension}');
    final file = File(filePath);
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {}
    }

    var received = 0;
    var lastBytes = 0;
    var lastTick = DateTime.now();
    var ema = 0.0;
    var attempt = 0;

    Future<void> fetch() async {
      final request = http.Request('GET', resolved.url);
      request.headers['Range'] = 'bytes=0-';
      request.headers['User-Agent'] = kMediaUserAgent;
      final response =
          await _http.send(request).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200 && response.statusCode != 206) {
        throw HttpException('HTTP ${response.statusCode}');
      }

      final sink = file.openWrite();
      final timed = response.stream.timeout(
        const Duration(seconds: 20),
        onTimeout: (EventSink<List<int>> eventSink) => eventSink.addError(
          TimeoutException('flux gelé'),
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
            totalBytes: resolved.sizeBytes,
            speedBytesPerSec: ema,
          );
          notifyListeners();
        }
        await sink.close();
      } catch (_) {
        await sink.close();
        rethrow;
      }
    }

    while (true) {
      try {
        await fetch();
        break;
      } catch (e) {
        attempt++;
        if (attempt >= 3) rethrow;
        try {
          if (await file.exists()) await file.delete();
        } catch (_) {}
        received = 0;
        lastBytes = 0;
        ema = 0;
        await Future<void>.delayed(const Duration(seconds: 2));
        resolved = await _yt.downloadStream(id);
      }
    }
    return filePath;
  }
}
