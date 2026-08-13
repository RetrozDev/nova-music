import 'dart:async';

String formatDuration(Duration? d) {
  if (d == null || d.inMilliseconds <= 0) return '--:--';
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

String formatBytes(num bytes) {
  final b = bytes.toDouble();
  if (b < 1024) return '${b.round()} o';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} Ko';
  return '${(b / (1024 * 1024)).toStringAsFixed(1)} Mo';
}

String friendlyDownloadError(Object e) {
  if (e is TimeoutException) {
    return 'Téléchargement bloqué : réseau trop lent ou instable.';
  }
  final message = e.toString();
  if (message.contains('403') ||
      message.contains('VideoUnavailable') ||
      message.contains('Unplayable')) {
    return 'Ce titre ne peut pas être téléchargé pour le moment.';
  }
  return 'Échec du téléchargement : $message';
}
