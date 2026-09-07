import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Indicador de carga: un arco con degradado que gira mientras su longitud
/// se abre y se cierra.
///
/// El movimiento es continuo —ninguna fase salta al reiniciarse el ciclo— y
/// no recurre a barras de ecualizador, que competían visualmente con el
/// resto de la interfaz.
class MusicLoader extends StatefulWidget {
  const MusicLoader({
    super.key,
    this.label = 'Leyendo tu biblioteca…',
    this.size = 52,
  });

  /// Texto bajo la animación. Pasa `null` para ocultarlo.
  final String? label;

  final double size;

  @override
  State<MusicLoader> createState() => _MusicLoaderState();
}

class _MusicLoaderState extends State<MusicLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: _ArcLoaderPainter(
                  progress: _controller.value,
                  track: colors.border,
                  from: colors.primary,
                  to: colors.accent,
                ),
              );
            },
          ),
        ),
        if (widget.label != null) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(
            widget.label!,
            textAlign: TextAlign.center,
            style:
                context.texts.bodySmall?.copyWith(color: colors.textTertiary),
          ),
        ],
      ],
    );
  }
}

class _ArcLoaderPainter extends CustomPainter {
  const _ArcLoaderPainter({
    required this.progress,
    required this.track,
    required this.from,
    required this.to,
  });

  /// Fase del ciclo, de 0 a 1.
  final double progress;

  final Color track;
  final Color from;
  final Color to;

  static const double _tau = math.pi * 2;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.shortestSide * 0.10;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height)
        .deflate(stroke / 2);

    // Aro de fondo, apenas visible: da cuerpo al arco sin llamar la atención.
    canvas.drawCircle(
      rect.center,
      rect.shortestSide / 2,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );

    // La longitud del arco respira con un seno, que es periódico en el ciclo:
    // al volver a empezar no hay ningún salto.
    final breath = (math.sin(progress * _tau) + 1) / 2;
    final sweep =
        lerpDouble(0.10, 0.72, Curves.easeInOut.transform(breath))! * _tau;

    // Dos vueltas por ciclo, de nuevo cerrando en el punto de partida.
    final start = progress * _tau * 2 - math.pi / 2;

    final paint = Paint()
      ..shader = SweepGradient(
        colors: [from, to, from],
        stops: const [0.0, 0.5, 1.0],
        transform: GradientRotation(start),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, start, sweep, false, paint);
  }

  @override
  bool shouldRepaint(_ArcLoaderPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.from != from ||
      oldDelegate.to != to ||
      oldDelegate.track != track;
}
