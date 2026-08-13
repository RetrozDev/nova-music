import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AppUpdate {
  final String tag;
  final String downloadUrl;
  final String browserUrl;

  const AppUpdate({
    required this.tag,
    required this.downloadUrl,
    required this.browserUrl,
  });

  String get version => tag.replaceFirst(RegExp(r'^[vV]'), '');
}

class UpdateResult {
  final bool installed;
  final String? message;

  const UpdateResult(this.installed, this.message);
}

/// Vérifie et installe les nouvelles versions publiées sur GitHub Releases.
class UpdateService {
  static const _channel = MethodChannel('nova_music/installer');
  static const _repo = 'RetrozDev/nova-music';

  Future<String> currentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  Future<AppUpdate?> checkLatest() async {
    try {
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/$_repo/releases/latest'),
        headers: {
          'User-Agent': 'nova-music-app',
          'Accept': 'application/vnd.github+json',
        },
      );
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tag = data['tag_name'] as String? ?? '';
      final browser = data['html_url'] as String? ?? '';
      final assets = data['assets'] as List? ?? [];
      String? downloadUrl;
      for (final asset in assets) {
        if (asset is Map<String, dynamic> &&
            (asset['name'] as String? ?? '').endsWith('.apk')) {
          downloadUrl = asset['browser_download_url'] as String?;
          break;
        }
      }
      if (tag.isEmpty || downloadUrl == null) return null;
      return AppUpdate(
        tag: tag,
        downloadUrl: downloadUrl,
        browserUrl: browser,
      );
    } catch (_) {
      return null;
    }
  }

  bool isNewer(String current, String remote) {
    int segment(String version, int i) {
      final parts = version
          .trim()
          .replaceFirst(RegExp(r'^[vV]'), '')
          .split(RegExp(r'[.\-]'));
      if (i >= parts.length) return 0;
      final n = int.tryParse(parts[i]);
      return n ?? 0;
    }

    for (var i = 0; i < 3; i++) {
      final c = segment(current, i);
      final r = segment(remote, i);
      if (r > c) return true;
      if (r < c) return false;
    }
    return false;
  }

  Future<UpdateResult> downloadAndInstall(
    AppUpdate update, {
    void Function(double fraction, int received, int total)? onProgress,
  }) async {
    try {
      final ext = await getExternalStorageDirectory();
      if (ext == null) {
        return const UpdateResult(false, 'Stockage externe indisponible.');
      }
      final dir = p.join(ext.path, 'updates');
      final filePath = p.join(dir, 'nova-music.apk');
      await Directory(dir).create(recursive: true);

      final request = http.Request('GET', Uri.parse(update.downloadUrl));
      final response = await http.Client().send(request);
      if (response.statusCode != 200) {
        return UpdateResult(false, 'Téléchargement impossible (code ${response.statusCode}).');
      }

      final total = response.contentLength ?? 0;
      var received = 0;
      final sink = File(filePath).openWrite();
      try {
        await for (final chunk in response.stream) {
          received += chunk.length;
          sink.add(chunk);
          onProgress?.call(total > 0 ? received / total : 0, received, total);
        }
        await sink.close();
      } catch (e) {
        await sink.close();
        return UpdateResult(false, 'Téléchargement interrompu.');
      }

      final ok = await installApk(filePath);
      if (!ok) {
        return const UpdateResult(false, 'Impossible de lancer l\'installation.');
      }
      return const UpdateResult(true, null);
    } catch (e) {
      return UpdateResult(false, e.toString());
    }
  }

  Future<bool> installApk(String path) async {
    final ok = await _channel.invokeMethod<bool>('installApk', path);
    return ok ?? false;
  }

  Future<void> openInstallSettings() async {
    try {
      await _channel.invokeMethod('openInstallSettings');
    } catch (_) {}
  }
}
