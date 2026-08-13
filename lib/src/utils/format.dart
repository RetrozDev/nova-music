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
