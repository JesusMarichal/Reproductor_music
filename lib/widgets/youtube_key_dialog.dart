import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/youtube_service.dart';
import '../theme/app_theme.dart';

/// Pide la API key de YouTube y la guarda. Devuelve true si cambió.
Future<bool> showYouTubeKeyDialog(BuildContext context) async {
  final service = YouTubeService.instance;
  if (service.keyFromBuild) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('La API key de YouTube viene fijada en esta versión.'),
      ),
    );
    return false;
  }

  final current = await service.apiKey();
  if (!context.mounted) return false;
  final textController = TextEditingController(text: current ?? '');

  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Conectar con YouTube'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Crea una API key gratuita en Google Cloud con «YouTube Data '
            'API v3» activada y pégala aquí.',
            style: dialogContext.texts.bodyMedium?.copyWith(
              color: dialogContext.colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: textController,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'AIza...'),
            onSubmitted: (v) => Navigator.pop(dialogContext, v),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton.icon(
            onPressed: () => launchUrl(
              Uri.parse(
                'https://console.cloud.google.com/apis/library/youtube.googleapis.com',
              ),
              mode: LaunchMode.externalApplication,
            ),
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('Abrir Google Cloud'),
          ),
        ],
      ),
      actions: [
        if (current != null)
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, ''),
            child: const Text('Quitar'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, textController.text),
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
  textController.dispose();
  if (result == null) return false;
  await service.setApiKey(result);
  return true;
}
