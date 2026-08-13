import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/library_track.dart';

class LibraryService extends ChangeNotifier {
  static const _dbName = 'nova_music.db';

  Database? _db;
  final List<LibraryTrack> _tracks = [];
  late String _musicDir;

  List<LibraryTrack> get tracks => List.unmodifiable(_tracks);

  String get musicDir => _musicDir;

  LibraryTrack? find(String id) {
    for (final t in _tracks) {
      if (t.id == id) return t;
    }
    return null;
  }

  bool isDownloaded(String id) => _tracks.any((t) => t.id == id);

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _musicDir = p.join(dir.path, 'nova_music');
    await Directory(_musicDir).create(recursive: true);

    _db = await openDatabase(
      p.join(dir.path, _dbName),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE tracks(
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            artist TEXT,
            duration_ms INTEGER NOT NULL,
            thumbnail_url TEXT,
            file_path TEXT NOT NULL,
            added_at INTEGER NOT NULL
          )
        ''');
      },
    );

    final rows = await _db!.query('tracks', orderBy: 'added_at DESC');
    _tracks
      ..clear()
      ..addAll(rows.map(LibraryTrack.fromMap));
    notifyListeners();
  }

  Future<void> add(LibraryTrack track) async {
    await _db!.insert(
      'tracks',
      track.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _tracks.removeWhere((t) => t.id == track.id);
    _tracks.insert(0, track);
    notifyListeners();
  }

  Future<void> remove(String id) async {
    final index = _tracks.indexWhere((t) => t.id == id);
    if (index < 0) return;
    final track = _tracks[index];

    await _db!.delete('tracks', where: 'id = ?', whereArgs: [id]);

    final file = File(track.filePath);
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {}
    }
    final thumb = File(track.thumbnailPath);
    if (await thumb.exists()) {
      try {
        await thumb.delete();
      } catch (_) {}
    }

    _tracks.removeAt(index);
    notifyListeners();
  }

  Future<void> clearDownloads() async {
    final ids = _tracks.map((t) => t.id).toList();
    for (final id in ids) {
      await remove(id);
    }
  }
}
