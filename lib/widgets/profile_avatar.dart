import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/profile_controller.dart';
import '../theme/app_theme.dart';

/// Avatar del perfil: la foto elegida o, si no hay, las iniciales.
///
/// Se usa tanto en el botón central de la barra como en la cabecera de la
/// pantalla de perfil, para que siempre muestren lo mismo.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileController>();
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    final file = profile.avatarFile;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.colors.primary,
      ),
      clipBehavior: Clip.antiAlias,
      child: file != null
          ? Image.file(
              file,
              fit: BoxFit.cover,
              // Si el fichero desaparece del disco, caemos a las iniciales.
              errorBuilder: (_, _, _) => _Initials(
                text: profile.initials,
                size: size,
                color: onPrimary,
              ),
            )
          : _Initials(text: profile.initials, size: size, color: onPrimary),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({
    required this.text,
    required this.size,
    required this.color,
  });

  final String text;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: size * 0.38,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}
