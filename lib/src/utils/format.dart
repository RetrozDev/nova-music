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
    return 'Téléchargement bloqué : réseau trop lent ou instable. Réessaie.';
  }
  final message = e.toString();
  if (message.contains('FileSystemException') ||
      message.contains('No space left') ||
      message.contains('Permission denied')) {
    return 'Stockage plein ou inaccessible. Libère de l\'espace ou réessaie.';
  }
  if (message.contains('Stockage inaccessible')) {
    return message;
  }
  if (message.contains('403')) {
    return 'YouTube bloque les téléchargements depuis ce réseau (erreur 403). '
        'Essaie en WiFi, sur une autre connexion, ou réessaie plus tard.';
  }
  if (message.contains('VideoUnavailable') ||
      message.contains('Unplayable') ||
      message.contains('416')) {
    return 'Ce titre ne peut pas être téléchargé pour le moment.';
  }
  return 'Échec du téléchargement : $message';
}

String friendlyPlaybackError(Object raw) {
  final m = raw.toString().toLowerCase();
  if (m.contains('403') ||
      m.contains('source error') ||
      m.contains('unexpected status') ||
      m.contains('response code') ||
      m.contains('playback error')) {
    return 'YouTube refuse de lire ce flux depuis ton réseau (bloqué). '
        'Essaie un autre réseau (WiFi / données) ou un VPN.';
  }
  if (m.contains('unable to resolve host') ||
      m.contains('unknown host') ||
      m.contains('socketexception') ||
      m.contains('failed to connect') ||
      m.contains('connection refused')) {
    return 'Réseau injoignable. Vérifie ta connexion internet.';
  }
  return 'Lecture impossible : $raw';
}
