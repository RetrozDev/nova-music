import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../models/library_track.dart';
import '../models/track.dart';
import '../utils/constants.dart';
import 'library_service.dart';
import 'youtube_service.dart';

class PlayerService extends ChangeNotifier {
  final YoutubeService _yt;
  final LibraryService _library;

  // maxSkipsOnError: 0 → on NE saute PAS une piste qui échoue : on s'arrête
  // et l'erreur est remontée (visible) au lieu d'un skip silencieux.
  final AudioPlayer _player = AudioPlayer(maxSkipsOnError: 0);

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
  final StreamController<String> _errors = StreamController.broadcast();
  final Set<String> _retriedIds = {};
  int _queueBuildGen = 0;

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
    _player.playbackEventStream.listen((event) {
      if (event.errorCode != null) {
        _errors.add(event.errorMessage ?? 'Erreur de lecture.');
        _maybeRetryCurrent();
      }
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
  Stream<String> get errorStream => _errors.stream;

  /// Returns the locally cached artwork for [id], if it exists.
  File? localThumbnail(String id) {
    final lib = _library.find(id);
    if (lib == null) return null;
    final file = File(lib.thumbnailPath);
    return file.existsSync() ? file : null;
  }

  bool isDownloaded(String id) => _library.isDownloaded(id);

  // ---- Playback control ----

  /// Plays a list of tracks starting at [index]. La piste demandée est résolue
  /// immédiatement, les suivantes sont ajoutées en arrière-plan (les URL yt-dlp
  /// prennent quelques secondes chacune).
  Future<void> playTracks(List<Track> tracks, {required int index}) async {
    if (tracks.isEmpty) return;
    if (index < 0 || index >= tracks.length) index = 0;
    _preparing = true;
    _queueBuildGen++;
    notifyListeners();
    try {
      final currentTrack = tracks[index];
      final uri = await resolveUri(currentTrack);
      _queue = List.of(tracks);
      await _player.setAudioSource(_sourceFor(currentTrack, uri));
      await _player.play();
      unawaited(_buildQueue(tracks, index));
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
    _errors.close();
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

  AudioSource _sourceFor(Track track, Uri uri) {
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      return AudioSource.uri(
        uri,
        tag: _mediaItem(track),
        headers: const {'User-Agent': kMediaUserAgent},
      );
    }
    return AudioSource.uri(uri, tag: _mediaItem(track));
  }

  /// Ajoute progressivement les pistes suivantes à la file (en arrière-plan).
  Future<void> _buildQueue(List<Track> tracks, int startIndex) async {
    final gen = ++_queueBuildGen;
    final order = <Track>[
      ...tracks.skip(startIndex + 1),
      ...tracks.take(startIndex),
    ];
    for (final t in order) {
      if (gen != _queueBuildGen) return;
      try {
        if (_player.sequence.length >= tracks.length) return;
        final uri = await resolveUri(t);
        await _player.addAudioSource(_sourceFor(t, uri));
      } catch (_) {
        // Piste impossible à résoudre : on continue.
      }
    }
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

  /// Une seule tentative automatique : si la lecture échoue sur un titre en
  /// streaming, on récupère une URL YouTube fraîche et on relance.
  Future<void> _maybeRetryCurrent() async {
    final track = current;
    final idx = _index;
    if (track == null || idx == null) return;
    if (_retriedIds.contains(track.id)) return;
    // Fichier local : pas de nouvelle URL possible.
    if (_library.find(track.id) != null) return;
    if (_queue.isEmpty) return;

    _retriedIds.add(track.id);
    _preparing = true;
    notifyListeners();
    try {
      track.streamUri = null; // force une URL fraîche
      await playTracks(_queue, index: idx);
    } catch (_) {
    } finally {
      _preparing = false;
      notifyListeners();
    }
  }
}
