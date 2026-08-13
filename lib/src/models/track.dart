import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class Track {
  final String id;
  final String title;
  final String artist;
  final Duration? duration;
  final String thumbnailUrl;
  final bool isLive;

  /// Resolved stream URI (http URL or local file path).
  String? streamUri;

  Track({
    required this.id,
    required this.title,
    required this.artist,
    this.duration,
    required this.thumbnailUrl,
    this.isLive = false,
    this.streamUri,
  });

  factory Track.fromVideo(Video video) => Track(
        id: video.id.value,
        title: video.title,
        artist: video.author,
        duration: video.duration,
        thumbnailUrl: video.thumbnails.mediumResUrl,
        isLive: video.isLive,
      );

  Track copyWith({String? streamUri}) => Track(
        id: id,
        title: title,
        artist: artist,
        duration: duration,
        thumbnailUrl: thumbnailUrl,
        isLive: isLive,
        streamUri: streamUri ?? this.streamUri,
      );
}
