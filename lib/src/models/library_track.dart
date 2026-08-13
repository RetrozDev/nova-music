import 'track.dart';

class LibraryTrack {
  final String id;
  final String title;
  final String artist;
  final int durationMs;
  final String thumbnailUrl;
  final String filePath;
  final DateTime addedAt;

  LibraryTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.durationMs,
    required this.thumbnailUrl,
    required this.filePath,
    required this.addedAt,
  });

  factory LibraryTrack.fromMap(Map<String, Object?> map) => LibraryTrack(
        id: map['id'] as String,
        title: map['title'] as String,
        artist: map['artist'] as String? ?? '',
        durationMs: map['duration_ms'] as int? ?? 0,
        thumbnailUrl: map['thumbnail_url'] as String? ?? '',
        filePath: map['file_path'] as String,
        addedAt: DateTime.fromMillisecondsSinceEpoch(map['added_at'] as int? ?? 0),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'artist': artist,
        'duration_ms': durationMs,
        'thumbnail_url': thumbnailUrl,
        'file_path': filePath,
        'added_at': addedAt.millisecondsSinceEpoch,
      };

  String get thumbnailPath => filePath.endsWith('.jpg')
      ? filePath
      : '${filePath.substring(0, filePath.lastIndexOf('.'))}.jpg';

  Track toTrack() => Track(
        id: id,
        title: title,
        artist: artist,
        duration: Duration(milliseconds: durationMs),
        thumbnailUrl: thumbnailUrl,
      );
}
