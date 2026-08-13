import 'dart:async';

import 'package:flutter/material.dart';

import '../services/update_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';

/// Fenêtre « une nouvelle version est disponible » (apparition au démarrage).
Future<void> showUpdateAvailableDialog(
  BuildContext context,
  UpdateService service,
  AppUpdate update,
  String currentVersion,
) async {
  final accepted = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: Icon(Icons.system_update_alt_rounded,
          color: AppColors.secondary, size: 36),
      title: Text(
        'Mise à jour disponible',
        style: TextStyle(color: AppColors.textPrimary),
      ),
      content: Text(
        'La version ${update.version} est prête (tu es en v$currentVersion). '
        'Télécharger et installer maintenant ?',
        style: TextStyle(color: AppColors.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Plus tard'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Mettre à jour'),
        ),
      ],
    ),
  );
  if (accepted == true) {
    if (!context.mounted) return;
    await showUpdateProgressDialog(context, service, update);
  }
}

/// Télécharge l'APK avec une vraie barre de progression puis installe.
/// Retourne `true` si l'installation a été lancée.
Future<bool> showUpdateProgressDialog(
  BuildContext context,
  UpdateService service,
  AppUpdate update,
) async {
  final navigator = Navigator.of(context);
  final progress = ValueNotifier<double?>(0);
  final info = ValueNotifier<String>('Préparation…');

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Téléchargement…',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder<double?>(
              valueListenable: progress,
              builder: (_, value, _) => ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: value == 0 ? null : value,
                  minHeight: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                  valueColor:
                      AlwaysStoppedAnimation(AppColors.secondary),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<String>(
              valueListenable: info,
              builder: (_, value, _) => Text(
                value,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  final path = await service.downloadApk(
    update,
    onProgress: (fraction, received, total) {
      progress.value = fraction;
      final percent =
          '${(fraction * 100).clamp(0, 100).toStringAsFixed(0)}%';
      info.value = total > 0
          ? '$percent • ${formatBytes(received)} / ${formatBytes(total)}'
          : percent;
    },
  );

  if (navigator.mounted) navigator.pop();
  if (!context.mounted) return false;

  if (path == null) {
    await showUpdateErrorDialog(
        context, service, 'Téléchargement de la mise à jour impossible.');
    return false;
  }

  var outcome = await service.installApk(path);
  while (outcome == InstallOutcome.permissionRequired) {
    if (!context.mounted) return false;
    // Ouvre les réglages « sources inconnues », puis propose de réessayer.
    await service.openInstallSettings();
    if (!context.mounted) return false;
    final retry = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.security_rounded,
            color: Colors.amber, size: 36),
        title: Text(
          'Autorisation d\'installation requise',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Pour installer Nova Music, autorise « Installer des applications '
          'inconnues » pour l\'app dans les réglages qui viennent de '
          's\'ouvrir. Puis reviens et touche « Réessayer ».',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Plus tard'),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
    if (retry != true || !context.mounted) return false;
    outcome = await service.installApk(path);
  }

  if (outcome == InstallOutcome.installed) {
    if (!context.mounted) return false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.check_circle_rounded,
            color: Colors.greenAccent, size: 36),
        title: Text(
          'Mise à jour installée',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Confirme l\'installation dans la fenêtre Android, puis reviens '
          'dans Nova Music : tout sera mis à jour, sans rien perdre.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return true;
  }

  if (!context.mounted) return false;
  await showUpdateErrorDialog(
      context, service, 'Impossible de lancer l\'installation.');
  return false;
}

/// Message d'erreur avec accès aux réglages d'installation.
Future<void> showUpdateErrorDialog(
  BuildContext context,
  UpdateService service,
  String? message,
) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: const Icon(Icons.error_outline_rounded,
          color: Colors.redAccent, size: 36),
      title: Text(
        'Mise à jour impossible',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textPrimary),
      ),
      content: Text(
        message ?? 'Une erreur est survenue.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Fermer'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: () async {
            Navigator.pop(ctx);
            await service.openInstallSettings();
          },
          child: const Text('Autoriser les installations'),
        ),
      ],
    ),
  );
}

/// Lance une vérification silencieuse au démarrage. Si une version plus
/// récente existe, la mise à jour est **téléchargée automatiquement**, puis
/// l'installation est proposée (Android exige toujours une confirmation).
Future<void> autoCheckForUpdate(
  BuildContext context,
  UpdateService service,
) async {
  try {
    final current = await service.currentVersion();
    final update = await service.checkLatest();
    if (update == null) return;
    if (service.isNewer(current, update.version)) {
      if (!context.mounted) return;
      await showUpdateProgressDialog(context, service, update);
    }
  } catch (_) {}
}
