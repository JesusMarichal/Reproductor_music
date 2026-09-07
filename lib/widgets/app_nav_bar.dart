import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Un destino de la barra de navegación.
class NavItem {
  const NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;

  /// Etiqueta de accesibilidad y tooltip: la barra es de iconos, sin texto.
  final String label;
}

/// Barra de navegación inferior en color de marca, con una muesca circular
/// que aloja el botón de perfil.
///
/// Los destinos se reparten a izquierda y derecha del botón central, así que
/// [items] debe tener un número par de elementos.
class AppNavBar extends StatelessWidget {
  const AppNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelected,
    required this.centerTooltip,
    required this.onCenterPressed,
    this.centerChild,
  });

  final List<NavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  /// Contenido del botón central (por ejemplo, el avatar del perfil).
  final Widget? centerChild;
  final String centerTooltip;
  final VoidCallback onCenterPressed;

  static const double barHeight = 68;
  static const double _fabSize = 60;

  /// Holgura entre el botón y el borde de la muesca.
  static const double _notchMargin = 6;

  static double get _fabRadius => _fabSize / 2;

  /// Altura total ocupada, incluida la parte del botón que sobresale.
  static double get totalHeight => barHeight + _fabRadius;

  @override
  Widget build(BuildContext context) {
    assert(
      items.length.isEven,
      'AppNavBar reparte los destinos a ambos lados del botón central, '
      'así que necesita un número par.',
    );

    final colors = context.colors;
    final onBrand = Theme.of(context).colorScheme.onPrimary;
    final half = items.length ~/ 2;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return SizedBox(
      height: totalHeight + bottomInset,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // Barra con la muesca recortada en el borde superior.
          ClipPath(
            clipper: _NotchedBarClipper(
              notchRadius: _fabRadius + _notchMargin,
              cornerRadius: AppRadius.xl,
            ),
            child: Container(
              height: barHeight + bottomInset,
              color: colors.primary,
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Row(
                children: [
                  for (var i = 0; i < half; i++)
                    Expanded(
                      child: _NavButton(
                        index: i,
                        parent: this,
                        onBrand: onBrand,
                      ),
                    ),
                  // Hueco reservado para la muesca.
                  SizedBox(width: (_fabRadius + _notchMargin) * 2),
                  for (var i = half; i < items.length; i++)
                    Expanded(
                      child: _NavButton(
                        index: i,
                        parent: this,
                        onBrand: onBrand,
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Botón central, centrado sobre el borde superior de la barra.
          Positioned(
            bottom: barHeight + bottomInset - _fabRadius,
            child: _CenterButton(
              size: _fabSize,
              tooltip: centerTooltip,
              onPressed: onCenterPressed,
              child: centerChild,
            ),
          ),
        ],
      ),
    );
  }
}

/// Recorta el rectángulo de la barra: esquinas superiores redondeadas menos
/// una muesca circular centrada en el borde de arriba.
class _NotchedBarClipper extends CustomClipper<Path> {
  const _NotchedBarClipper({
    required this.notchRadius,
    required this.cornerRadius,
  });

  final double notchRadius;
  final double cornerRadius;

  @override
  Path getClip(Size size) {
    final host = Offset.zero & size;

    // La muesca se apoya en el borde superior, centrada horizontalmente.
    final guest = Rect.fromCircle(
      center: Offset(size.width / 2, 0),
      radius: notchRadius,
    );

    // Reutilizamos la geometría de Flutter para la curva de la muesca y le
    // aplicamos encima las esquinas redondeadas.
    final notched = const CircularNotchedRectangle().getOuterPath(host, guest);
    final rounded = Path()
      ..addRRect(
        RRect.fromRectAndCorners(
          host,
          topLeft: Radius.circular(cornerRadius),
          topRight: Radius.circular(cornerRadius),
        ),
      );

    return Path.combine(PathOperation.intersect, notched, rounded);
  }

  @override
  bool shouldReclip(_NotchedBarClipper oldClipper) =>
      oldClipper.notchRadius != notchRadius ||
      oldClipper.cornerRadius != cornerRadius;
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.index,
    required this.parent,
    required this.onBrand,
  });

  final int index;
  final AppNavBar parent;
  final Color onBrand;

  @override
  Widget build(BuildContext context) {
    final item = parent.items[index];
    final selected = index == parent.currentIndex;

    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      child: Tooltip(
        message: item.label,
        child: InkResponse(
          onTap: () => parent.onSelected(index),
          containedInkWell: true,
          highlightShape: BoxShape.rectangle,
          // Realce discreto: sobre un fondo de color saturado, un halo grande
          // resulta aparatoso.
          splashColor: onBrand.withValues(alpha: 0.10),
          highlightColor: onBrand.withValues(alpha: 0.06),
          child: SizedBox(
            height: AppNavBar.barHeight,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  selected ? item.selectedIcon : item.icon,
                  size: 25,
                  // Todos los iconos van en el color de contraste de la marca;
                  // el activo se distingue por opacidad plena y el punto.
                  color: selected ? onBrand : onBrand.withValues(alpha: 0.62),
                ),
                const SizedBox(height: AppSpacing.xs + 1),
                AnimatedContainer(
                  duration: AppDuration.fast,
                  width: selected ? 5 : 0,
                  height: selected ? 5 : 0,
                  decoration: BoxDecoration(
                    color: onBrand,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CenterButton extends StatelessWidget {
  const _CenterButton({
    required this.size,
    required this.tooltip,
    required this.onPressed,
    this.child,
  });

  final double size;
  final String tooltip;
  final VoidCallback onPressed;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: colors.primary,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.4),
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: child ??
                  Icon(
                    Icons.person_rounded,
                    size: 26,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
