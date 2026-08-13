import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class ResolvedStream {
  final Stream<List<int>> stream;
  final String extension;
  final int sizeBytes;

  const ResolvedStream({
    required this.stream,
    required this.extension,
    required this.sizeBytes,
  });
}

class YoutubeService {
  final _yt = YoutubeExplode();
  final _urlCache = <String, String>{};
  final _inFlight = <String, Future<String>>{};

  Future<VideoSearchList> search(String query) => _yt.search.search(query);

  Future<List<String>> suggestions(String query) =>
      _yt.search.getQuerySuggestions(query);

  Future<String> streamUrl(String videoId) =>
      _urlCache[videoId] != null
          ? Future.value(_urlCache[videoId])
          : _inFlight.putIfAbsent(videoId, () async {
              final url = await _resolveUrl(videoId);
              _urlCache[videoId] = url;
              return url;
            });

  Future<String> _resolveUrl(String videoId) async {
    final chosen = await _pickAudioStream(videoId);
    return chosen.url.toString();
  }

  Future<ResolvedStream> downloadStream(String videoId) async {
    final chosen = await _pickAudioStream(videoId);
    final stream = _yt.videos.streamsClient.get(chosen);
    return ResolvedStream(
      stream: stream,
      extension: chosen.container.name == 'mp4' ? 'm4a' : chosen.container.name,
      sizeBytes: chosen.size.totalBytes,
    );
  }

  Future<AudioOnlyStreamInfo> _pickAudioStream(String videoId) async {
    final manifest = await _yt.videos.streamsClient.getManifest(videoId);
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

  void dispose() => _yt.close();
}
