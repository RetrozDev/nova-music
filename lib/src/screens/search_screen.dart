import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/track.dart';
import '../services/download_service.dart';
import '../services/library_service.dart';
import '../services/player_service.dart';
import '../services/youtube_service.dart';
import '../theme/app_theme.dart';
import '../widgets/track_card.dart';

const _categories = [
  'Pop',
  'Rap français',
  'Électro',
  'Rock',
  'Lo-fi',
  'R&B',
  'Jazz',
  'Hip-hop',
  'Reggaeton',
  'Classique',
];

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  List<Track> _results = [];
  List<String> _suggestions = [];
  VideoSearchList? _nextPage;
  Timer? _debounce;

  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 600 &&
        !_loadingMore &&
        _nextPage != null) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    final page = _nextPage;
    if (page == null) return;
    setState(() => _loadingMore = true);
    try {
      final next = await page.nextPage();
      if (next != null) {
        setState(() {
          _results.addAll(next.map(Track.fromVideo));
          _nextPage = next;
        });
      } else {
        setState(() => _nextPage = null);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.length < 2) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final yt = context.read<YoutubeService>();
      try {
        final suggestions = await yt.suggestions(query);
        if (mounted) setState(() => _suggestions = suggestions);
      } catch (_) {}
    });
  }

  Future<void> _submit(String query) async {
    query = query.trim();
    if (query.isEmpty) return;
    _controller.text = query;
    _controller.selection = TextSelection.collapsed(offset: query.length);
    FocusScope.of(context).unfocus();
    setState(() {
      _query = query;
      _suggestions = [];
      _loading = true;
      _error = null;
    });
    try {
      final yt = context.read<YoutubeService>();
      final list = await yt.search(query);
      if (!mounted) return;
      setState(() {
        _results = list.map(Track.fromVideo).toList();
        _nextPage = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Recherche impossible. Vérifie ta connexion internet.';
      });
    }
  }

  void _clearSearch() {
    _controller.clear();
    setState(() {
      _query = '';
      _results = [];
      _suggestions = [];
      _error = null;
    });
  }

  Future<void> _play(int index) async {
    final player = context.read<PlayerService>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await player.playTracks(_results, index: index);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Lecture impossible : $e')),
      );
    }
  }

  Future<void> _download(Track track) async {
    final download = context.read<DownloadService>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await download.download(track);
      messenger.showSnackBar(
        const SnackBar(content: Text('Téléchargé dans la bibliothèque')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Échec du téléchargement : $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nova Music',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Outfit',
                ),
              ),
              const Text(
                'Recherche, écoute, télécharge.',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              _SearchBar(
                controller: _controller,
                onChanged: _onChanged,
                onSubmitted: _submit,
                onClear: _clearSearch,
                hasQuery: _query.isNotEmpty,
              ),
            ],
          ),
        ),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.secondary),
      );
    }
    if (_error != null) {
      return _ErrorState(message: _error!, onRetry: () => _submit(_query));
    }
    if (_query.isEmpty && _suggestions.isEmpty) {
      return _Discover(onQuery: _submit);
    }
    if (_query.isEmpty && _suggestions.isNotEmpty) {
      return _Suggestions(
        suggestions: _suggestions,
        onSelected: _submit,
      );
    }
    if (_query.isNotEmpty && _suggestions.isNotEmpty) {
      return _Suggestions(
        suggestions: _suggestions,
        onSelected: _submit,
      );
    }
    if (_results.isEmpty) {
      return const Center(
        child: Text(
          'Aucun résultat',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    return _ResultsList(
      results: _results,
      nextPage: _nextPage,
      loadingMore: _loadingMore,
      scrollController: _scrollController,
      onPlay: _play,
      onDownload: _download,
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;
  final bool hasQuery;

  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    required this.hasQuery,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      onSubmitted: onSubmitted,
      style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
      cursorColor: AppColors.secondary,
      decoration: InputDecoration(
        hintText: 'Artiste, titre, genre…',
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        prefixIcon: const Icon(Icons.search_rounded,
            color: AppColors.textSecondary),
        suffixIcon: hasQuery
            ? IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded,
                    color: AppColors.textSecondary),
              )
            : null,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}

class _Discover extends StatelessWidget {
  final ValueChanged<String> onQuery;

  const _Discover({required this.onQuery});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: AppColors.gradient,
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '🎧 Prêt à vibrer ?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Tape le nom d\'un son, d\'un artiste…\nou choisis un mood ci-dessous.',
                style: TextStyle(fontSize: 13, color: Colors.white70),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Trouver une vibe',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _categories
              .map(
                (c) => ActionChip(
                  label: Text(c),
                  labelStyle: const TextStyle(
                      fontSize: 13, color: AppColors.textPrimary),
                  backgroundColor: AppColors.surface,
                  side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.4),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  onPressed: () => onQuery(c),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _Suggestions extends StatelessWidget {
  final List<String> suggestions;
  final ValueChanged<String> onSelected;

  const _Suggestions({required this.suggestions, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: suggestions.length,
      itemBuilder: (context, i) {
        final s = suggestions[i];
        return ListTile(
          dense: true,
          leading: const Icon(Icons.history_rounded,
              color: AppColors.textSecondary, size: 20),
          title: Text(
            s,
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          ),
          onTap: () => onSelected(s),
        );
      },
    );
  }
}

class _ResultsList extends StatelessWidget {
  final List<Track> results;
  final VideoSearchList? nextPage;
  final bool loadingMore;
  final ScrollController scrollController;
  final ValueChanged<int> onPlay;
  final ValueChanged<Track> onDownload;

  const _ResultsList({
    required this.results,
    required this.nextPage,
    required this.loadingMore,
    required this.scrollController,
    required this.onPlay,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: results.length + 1,
      itemBuilder: (context, i) {
        if (i == results.length) {
          if (nextPage == null) return const SizedBox(height: 8);
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.secondary,
                ),
              ),
            ),
          );
        }
        final track = results[i];
        return _TrackItem(
          track: track,
          index: i,
          results: results,
          onPlay: onPlay,
          onDownload: onDownload,
        );
      },
    );
  }
}

class _TrackItem extends StatelessWidget {
  final Track track;
  final int index;
  final List<Track> results;
  final ValueChanged<int> onPlay;
  final ValueChanged<Track> onDownload;

  const _TrackItem({
    required this.track,
    required this.index,
    required this.results,
    required this.onPlay,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerService>();
    final download = context.watch<DownloadService>();
    final library = context.watch<LibraryService>();

    final isCurrent = player.current?.id == track.id;
    final downloading = download.isDownloading(track.id);
    final downloaded = library.isDownloaded(track.id);
    final progress = downloading
        ? download.active[track.id]?.fraction
        : null;

    return TrackCard(
      track: track,
      isPlaying: isCurrent,
      onTap: () => onPlay(index),
      onDownload: downloaded ? null : () => onDownload(track),
      downloading: downloading,
      progress: progress,
      localThumbnailPath: library.find(track.id)?.thumbnailPath,
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 56, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}
