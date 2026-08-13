import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/update_service.dart';
import '../theme/app_theme.dart';
import 'update_flow.dart';

/// Section « Mise à jour » affichée dans les réglages.
class UpdateSection extends StatefulWidget {
  const UpdateSection({super.key});

  @override
  State<UpdateSection> createState() => _UpdateSectionState();
}

class _UpdateSectionState extends State<UpdateSection> {
  bool _checking = false;
  bool _upToDate = false;
  String _current = '';
  AppUpdate? _update;
  String? _error;

  UpdateService get _service => context.read<UpdateService>();

  @override
  void initState() {
    super.initState();
    _service.currentVersion().then((v) {
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
    final current = await _service.currentVersion();
    final update = await _service.checkLatest();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _current = current;
      if (update == null) {
        _error = 'Impossible de contacter les serveurs de mise à jour.';
      } else if (_service.isNewer(current, update.version)) {
        _update = update;
      } else {
        _upToDate = true;
      }
    });
  }

  Future<void> _updateNow() async {
    final update = _update;
    if (update == null) return;
    await showUpdateProgressDialog(context, _service, update);
    if (mounted) {
      setState(() => _update = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.system_update_alt_rounded,
                color: AppColors.secondary, size: 22),
            const SizedBox(width: 10),
            Text(
              'Version $_current',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _status(),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: _update != null
              ? FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _updateNow,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text(
                    'Mettre à jour maintenant',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                )
              : OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.6)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _checking ? null : _check,
                  icon: _checking
                      ? SizedBox(
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
        const SizedBox(height: 10),
        Text(
          'Les mises à jour s\'installent par-dessus la version actuelle : '
          'pas besoin de désinstaller, tes téléchargements sont conservés.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _status() {
    if (_checking) {
      return Row(
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
      return Text(
        'Nouvelle version ${_update!.version} disponible 🚀',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      );
    }
    if (_upToDate) {
      return Text(
        'Tu es à jour 🎉',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      );
    }
    if (_error != null) {
      return Text(
        _error!,
        style: const TextStyle(fontSize: 13, color: Colors.redAccent),
      );
    }
    return Text(
      'Reste à jour pour profiter des dernières nouveautés.',
      style: TextStyle(color: AppColors.textSecondary),
    );
  }
}
