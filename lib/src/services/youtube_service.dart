import 'package:flutter/services.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class ResolvedAudio {
  final Uri url;
  final String extension;
  final int sizeBytes;

  const ResolvedAudio({
    required this.url,
    required this.extension,
    required this.sizeBytes,
  });
}

class YoutubeService {
  static const _ytdl = MethodChannel('nova_music/ytdl');

  final _yt = YoutubeExplode();
  final _urlCache = <String, String>{};
  final _inFlight = <String, Future<String>>{};

  Future<VideoSearchList> search(String query) => _yt.search.search(query);

  Future<List<String>> suggestions(String query) =>
      _yt.search.getQuerySuggestions(query);

  Future<String> streamUrl(String videoId) => _urlCache[videoId] != null
      ? Future.value(_urlCache[videoId])
      : _inFlight.putIfAbsent(videoId, () async {
          final url = await _resolveUrl(videoId);
          _urlCache[videoId] = url;
          return url;
        });

  Future<String> _resolveUrl(String videoId) async {
    // 1) yt-dlp embarqué (robuste face aux blocages / anti-bot de YouTube).
    try {
      final url = await _ytdl
          .invokeMethod<String>('streamUrl', videoId)
          .timeout(const Duration(seconds: 60));
      if (url != null && url.isNotEmpty) return url;
    } catch (_) {}
    // 2) Repli : youtube_explode (client iOS en priorité).
    final chosen = await _pickAudioStream(videoId);
    return chosen.url.toString();
  }

  Future<ResolvedAudio> downloadStream(String videoId) async {
    final chosen = await _pickAudioStream(videoId);
    return ResolvedAudio(
      url: chosen.url,
      extension: chosen.container.name == 'mp4' ? 'm4a' : chosen.container.name,
      sizeBytes: chosen.size.totalBytes,
    );
  }

  Future<AudioOnlyStreamInfo> _pickAudioStream(String videoId) async {
    final manifest = await _fetchManifest(videoId);
    final audio = manifest.audioOnly.toList();
    if (audio.isEmpty) {
      throw Exception('Aucun flux audio disponible pour cette vidéo.');
    }
    final mp4 = audio
        .where((s) => s.container == StreamContainer.mp4)
        .toList()
      ..sort((a, b) => b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond));
    if (mp4.isNotEmpty) return mp4.first;
    return audio.reduce(
      (a, b) =>
          a.bitrate.bitsPerSecond >= b.bitrate.bitsPerSecond ? a : b,
    );
  }

  /// Récupère un manifeste contenant de l'audio, avec timeout et repli sur
  /// d'autres clients si le client préféré est bloqué.
  ///
  /// Le client `ios` (celui de l'app YouTube officielle) génère des URL
  /// `c=IOS` qui sont généralement **moins restreintes** (streaming +
  /// téléchargement) que les URL `c=ANDROID`, fréquemment bloquées par YouTube.
  Future<StreamManifest> _fetchManifest(String videoId) async {
    final attempts = <List<YoutubeApiClient>?>[
      [YoutubeApiClient.ios],
      null,
      [
        YoutubeApiClient.androidVr,
        YoutubeApiClient.androidSdkless,
        YoutubeApiClient.tv,
      ],
    ];
    Object? lastError;
    for (final clients in attempts) {
      try {
        final manifest = await (clients == null
                ? _yt.videos.streamsClient.getManifest(videoId)
                : _yt.videos.streamsClient.getManifest(
                    videoId,
                    ytClients: clients,
                  ))
            .timeout(const Duration(seconds: 30));
        if (manifest.audioOnly.isNotEmpty) return manifest;
      } catch (e) {
        lastError = e;
      }
    }
    if (lastError != null && lastError is Exception) {
      throw lastError;
    }
    throw Exception('Aucun flux audio disponible pour cette vidéo.');
  }

  void dispose() => _yt.close();
}
