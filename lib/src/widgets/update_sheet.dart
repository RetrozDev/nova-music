import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/update_service.dart';
import '../theme/app_theme.dart';
import 'update_flow.dart';

Future<void> showUpdateSheet(BuildContext context) {
  final service = context.read<UpdateService>();
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => UpdateSheet(service: service),
  );
}

class UpdateSheet extends StatefulWidget {
  final UpdateService service;

  const UpdateSheet({super.key, required this.service});

  @override
  State<UpdateSheet> createState() => _UpdateSheetState();
}

class _UpdateSheetState extends State<UpdateSheet> {
  bool _checking = false;
  bool _upToDate = false;
  String _current = '';
  AppUpdate? _update;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.service.currentVersion().then((v) {
      if (mounted) setState(() => _current = v);
    });
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _error = null;
      _update = null;
      _upToDate = false;
    });
    final current = await widget.service.currentVersion();
    final update = await widget.service.checkLatest();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _current = current;
      if (update == null) {
        _error = 'Impossible de contacter les serveurs de mise à jour.';
      } else if (widget.service.isNewer(current, update.version)) {
        _update = update;
      } else {
        _upToDate = true;
      }
    });
  }

  Future<void> _updateNow() async {
    final update = _update;
    if (update == null) return;
    final installed = await showUpdateProgressDialog(context, widget.service, update);
    if (installed && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: AppColors.gradient,
                  ),
                  child: const Icon(Icons.music_note_rounded,
                      color: Colors.white, size: 30),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nova Music',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        fontFamily: 'Outfit',
                      ),
                    ),
                    Text(
                      _current.isEmpty ? '…' : 'Version $_current',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            _statusArea(),
            const SizedBox(height: 16),
            if (_update != null)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _updateNow,
                  icon: const Icon(Icons.system_update_alt_rounded),
                  label: const Text(
                    'Mettre à jour maintenant',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.6)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _checking ? null : _check,
                  icon: _checking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.secondary,
                          ),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: Text(
                    _checking ? 'Vérification…' : 'Vérifier les mises à jour',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            const Text(
              'Les mises à jour s\'installent par-dessus la version actuelle : '
              'pas besoin de désinstaller, tes téléchargements sont conservés.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusArea() {
    if (_checking) {
      return const Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: AppColors.secondary),
          ),
          SizedBox(width: 12),
          Text(
            'Vérification de la dernière version…',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      );
    }
    if (_update != null) {
      return Row(
        children: [
          const Icon(Icons.download_rounded, color: AppColors.secondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Nouvelle version ${_update!.version} disponible 🚀',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      );
    }
    if (_upToDate) {
      return const Row(
        children: [
          Icon(Icons.check_circle_rounded, color: Colors.greenAccent),
          SizedBox(width: 10),
          Text(
            'Tu es à jour 🎉',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      );
    }
    if (_error != null) {
      return Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.redAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
        ],
      );
    }
    return const Text(
      'Reste à jour pour profiter des dernières nouveautés.',
      style: TextStyle(color: AppColors.textSecondary),
    );
  }
}
