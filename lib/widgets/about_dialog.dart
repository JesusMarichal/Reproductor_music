import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Versión mostrada en la app. Mantener alineada con `version:` de
/// pubspec.yaml.
const String kAppVersion = '1.0.0';

/// Diálogo "Acerca de".
Future<void> showAboutAppDialog(BuildContext context) {
  final colors = context.colors;

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76,
            height: 76,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: colors.brandGradient,
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/logo_music_app.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => ColoredBox(
                  color: colors.surface2,
                  child: Icon(Icons.music_note_rounded, color: colors.primary),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Kiss Music', style: context.texts.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Versión $kAppVersion',
            style:
                context.texts.bodySmall?.copyWith(color: colors.textTertiary),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Desarrollado por',
            style:
                context.texts.bodySmall?.copyWith(color: colors.textTertiary),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'AbstracDev',
            style: context.texts.titleMedium?.copyWith(color: colors.primary),
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
        ),
      ],
    ),
  );
}
