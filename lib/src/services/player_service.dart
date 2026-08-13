import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../models/library_track.dart';
import '../models/track.dart';
import 'library_service.dart';
import 'youtube_service.dart';

class PlayerService extends ChangeNotifier {
  final YoutubeService _yt;
  final LibraryService _library;

  final AudioPlayer _player = AudioPlayer(maxSkipsOnError: 3);

  List<Track> _queue = [];
  int? _index;
  bool _playing = false;
  bool _preparing = false;
  ProcessingState _processing = ProcessingState.idle;
  LoopMode _loopMode = LoopMode.off;
  bool _shuffle = false;

  final StreamController<Duration> _position = StreamController.broadcast();
  final StreamController<Duration?> _duration = StreamController.broadcast();
  final StreamController<Duration> _buffered = StreamController.broadcast();

  PlayerService(this._yt, this._library) {
    _player.currentIndexStream.listen((i) {
      _index = i;
      notifyListeners();
    });
    _player.playingStream.listen((p) {
      _playing = p;
      notifyListeners();
    });
    _player.playerStateStream.listen((s) {
      _processing = s.processingState;
      notifyListeners();
    });
    _player.loopModeStream.listen((m) {
      _loopMode = m;
      notifyListeners();
    });
    _player.shuffleModeEnabledStream.listen((s) {
      _shuffle = s;
      notifyListeners();
    });
    _player.positionStream.listen(_position.add);
    _player.durationStream.listen(_duration.add);
    _player.bufferedPositionStream.listen(_buffered.add);
  }

  // ---- Exposed state ----

  AudioPlayer get player => _player;

  List<Track> get queue => List.unmodifiable(_queue);

  int? get index => _index;

  Track? get current {
    if (_index == null || _index! < 0 || _index! >= _queue.length) return null;
    return _queue[_index!];
  }

  bool get isPlaying => _playing;

  bool get isPreparing => _preparing;

  ProcessingState get processingState => _processing;

  LoopMode get loopMode => _loopMode;

  bool get shuffleEnabled => _shuffle;

  Stream<Duration> get positionStream => _position.stream;
  Stream<Duration?> get durationStream => _duration.stream;
  Stream<Duration> get bufferedStream => _buffered.stream;

  /// Returns the locally cached artwork for [id], if it exists.
  File? localThumbnail(String id) {
    final lib = _library.find(id);
    if (lib == null) return null;
    final file = File(lib.thumbnailPath);
    return file.existsSync() ? file : null;
  }

  bool isDownloaded(String id) => _library.isDownloaded(id);

  // ---- Playback control ----

  /// Plays a list of tracks starting at [index]. Streams are resolved lazily
  /// (locally stored files first, then YouTube).
  Future<void> playTracks(List<Track> tracks, {required int index}) async {
    if (tracks.isEmpty) return;
    _preparing = true;
    notifyListeners();
    try {
      final items = await _resolveAll(tracks);
      if (items.isEmpty) {
        throw Exception('Impossible de lire ces pistes pour le moment.');
      }
      final startIndex = index < items.length ? index : 0;
      _queue = items.map((e) => e.$2).toList();
      await _player.setAudioSources(
        items.map((e) => e.$1).toList(),
        initialIndex: startIndex,
      );
      await _player.play();
    } finally {
      _preparing = false;
      notifyListeners();
    }
  }

  Future<void> playLibrary(List<LibraryTrack> tracks,
      {required int index}) async {
    await playTracks(
      tracks.map((t) => t.toTrack()).toList(),
      index: index,
    );
  }

  Future<void> toggle() =>
      _playing ? _player.pause() : _player.play();

  Future<void> play() => _player.play();

  Future<void> pause() => _player.pause();

  Future<void> next() {
    if (_player.hasNext) return _player.seekToNext();
    return _player.seek(Duration.zero, index: 0);
  }

  Future<void> previous() {
    if (_player.hasPrevious) return _player.seekToPrevious();
    return _player.seek(Duration.zero);
  }

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> seekToTrack(int index) =>
      _player.seek(Duration.zero, index: index);

  Future<void> cycleLoopMode() {
    const modes = [LoopMode.off, LoopMode.all, LoopMode.one];
    final next = modes[(modes.indexOf(_loopMode) + 1) % modes.length];
    return _player.setLoopMode(next);
  }

  Future<void> cycleShuffle() => _player.setShuffleModeEnabled(!_shuffle);

  Future<void> clear() {
    _queue = [];
    _index = null;
    return _player.stop();
  }

  @override
  void dispose() {
    _player.dispose();
    _position.close();
    _duration.close();
    _buffered.close();
    super.dispose();
  }

  // ---- Internals ----

  /// Resolves a playable [Uri] for [track]: a local file if it has been
  /// downloaded, otherwise a fresh YouTube stream URL.
  Future<Uri> resolveUri(Track track) async {
    final cached = track.streamUri;
    if (cached != null) {
      return cached.startsWith('http')
          ? Uri.parse(cached)
          : Uri.file(cached);
    }
    final lib = _library.find(track.id);
    if (lib != null) {
      final file = File(lib.filePath);
      if (await file.exists()) {
        track.streamUri = file.path;
        return Uri.file(file.path);
      }
    }
    final url = await _yt.streamUrl(track.id);
    track.streamUri = url;
    return Uri.parse(url);
  }

  Future<List<(AudioSource, Track)>> _resolveAll(List<Track> tracks) async {
    final out = List<(AudioSource, Track)?>.filled(tracks.length, null);
    const pool = 4;
    var next = 0;

    Future<void> worker() async {
      while (true) {
        final i = next++;
        if (i >= tracks.length) break;
        try {
          final uri = await resolveUri(tracks[i]);
          out[i] = (AudioSource.uri(uri, tag: _mediaItem(tracks[i])), tracks[i]);
        } catch (_) {
          // Skip tracks whose stream could not be resolved.
        }
      }
    }

    await Future.wait(List.generate(pool, (_) => worker()));
    return out.whereType<(AudioSource, Track)>().toList();
  }

  MediaItem _mediaItem(Track track) {
    final lib = _library.find(track.id);
    final localThumb = lib?.thumbnailPath;
    final art = (localThumb != null && File(localThumb).existsSync())
        ? Uri.file(localThumb)
        : (track.thumbnailUrl.isNotEmpty ? Uri.parse(track.thumbnailUrl) : null);
    return MediaItem(
      id: track.id,
      title: track.title,
      artist: track.artist,
      duration: track.duration,
      artUri: art,
    );
  }
}
