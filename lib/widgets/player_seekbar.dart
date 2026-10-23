import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../theme/app_theme.dart';

/// Barra de progreso del reproductor a pantalla completa.
///
/// Detalles:
/// - El avance sólo se repinta cuando el tirador se mueve al menos medio
///   píxel físico. Una canción de 3 min en una barra de ~1000 px avanza un
///   píxel cada ~180 ms: repintar a 60 fps obligaría a rasterizar la
///   pantalla entera en cada vsync para no mover nada.
/// - Pinta también lo que ya está en búfer, en un tono intermedio.
/// - Al tocarla o arrastrarla la pista se ensancha, el tirador crece y sobre
///   él aparece una burbuja con el tiempo de destino.
/// - Tocar la duración alterna entre total y tiempo restante.
///
/// Sólo se repinta el `CustomPaint`, y las etiquetas cuando cambia el
/// segundo; el resto del reproductor no se reconstruye con el avance.
class PlayerSeekBar extends StatefulWidget {
  const PlayerSeekBar({
    super.key,
    required this.player,
    required this.onSeek,
    this.minimal = false,
  });

  final AudioPlayer player;
  final Future<void> Function(Duration position) onSeek;

  /// Estilo plano sobre fondo oscuro: pista fina blanca, sin degradado ni
  /// resplandor, y el tirador sólo aparece al tocar.
  final bool minimal;

  @override
  State<PlayerSeekBar> createState() => _PlayerSeekBarState();
}

class _PlayerSeekBarState extends State<PlayerSeekBar>
    with SingleTickerProviderStateMixin {
  /// Alto de la zona táctil: mucho mayor que la pista para que sea fácil
  /// acertar con el dedo.
  static const double _touchHeight = 36;

  /// 0 = en reposo, 1 = el usuario la está tocando.
  late final AnimationController _active = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
    reverseDuration: const Duration(milliseconds: 260),
  );

  final ValueNotifier<double> _progress = ValueNotifier(0);
  final ValueNotifier<double> _buffered = ValueNotifier(0);

  /// Segundo mostrado en las etiquetas; sólo notifica cuando cambia.
  final ValueNotifier<int> _shownSecond = ValueNotifier(0);

  final List<StreamSubscription<Object?>> _subs = [];

  Duration _duration = Duration.zero;
  bool _dragging = false;

  /// Tras soltar, el reproductor tarda unos ms en llegar a la nueva posición.
  /// Mientras tanto se mantiene el valor soltado para que el tirador no
  /// vuelva atrás un instante.
  double? _pendingSeek;

  bool _showRemaining = false;

  /// Ancho útil de la pista en píxeles físicos (lo fija el LayoutBuilder).
  double _trackPx = 0;

  AudioPlayer get _player => widget.player;

  @override
  void initState() {
    super.initState();
    _bind();
  }

  @override
  void didUpdateWidget(PlayerSeekBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.player != widget.player) {
      _unbind();
      _bind();
    }
  }

  void _bind() {
    _duration = _player.duration ?? Duration.zero;
    _subs
      ..add(
        _player.durationStream.listen((d) {
          _duration = d ?? Duration.zero;
          _syncFromPlayer();
        }),
      )
      ..add(_player.playingStream.listen((_) => _syncFromPlayer()))
      // Saltos de posición (seek, cambio de pista), también en pausa.
      ..add(
        _player.positionDiscontinuityStream.listen((_) => _syncFromPlayer()),
      )
      ..add(_player.bufferedPositionStream.listen((_) => _syncFromPlayer()))
      // just_audio ajusta la frecuencia de este stream a la duración de la
      // pista; `player.position` además viene interpolado.
      ..add(_player.positionStream.listen((_) => _syncFromPlayer()));
    _syncFromPlayer();
  }

  void _unbind() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
  }

  @override
  void dispose() {
    _unbind();
    _active.dispose();
    _progress.dispose();
    _buffered.dispose();
    _shownSecond.dispose();
    super.dispose();
  }

  double get _totalMs => _duration.inMilliseconds.toDouble();

  void _syncFromPlayer() {
    if (!mounted) return;
    final total = _totalMs;
    final buffered = total > 0
        ? (_player.bufferedPosition.inMilliseconds / total).clamp(0.0, 1.0)
        : 0.0;
    if (_movesAPixel(_buffered.value, buffered)) _buffered.value = buffered;
    if (_dragging) return;

    var value = total > 0
        ? (_player.position.inMilliseconds / total).clamp(0.0, 1.0)
        : 0.0;
    final pending = _pendingSeek;
    if (pending != null) {
      // Hasta que el reproductor alcance la posición soltada (±1,5 s).
      if ((value - pending).abs() * total < 1500) {
        _pendingSeek = null;
      } else {
        value = pending;
      }
    }
    final second = (value * total / 1000).floor();
    if (_movesAPixel(_progress.value, value) || second != _shownSecond.value) {
      _setProgress(value);
    }
  }

  /// Si el cambio de [from] a [to] se ve en pantalla (≥ medio píxel físico).
  /// Sin ancho todavía, cualquier cambio cuenta.
  bool _movesAPixel(double from, double to) {
    if (from == to) return false;
    if (_trackPx <= 0 || to == 0 || to == 1) return true;
    return (to - from).abs() * _trackPx >= 0.5;
  }

  void _setProgress(double value) {
    _progress.value = value;
    _shownSecond.value = (value * _totalMs / 1000).floor();
  }

  /// Convierte la x del dedo en progreso, con el mismo margen lateral con el
  /// que se pinta la pista: así el tirador queda justo bajo el dedo.
  double _valueAt(Offset local, double width) {
    const inset = _SeekBarPainter.inset;
    final usable = width - inset * 2;
    if (usable <= 0) return 0;
    return ((local.dx - inset) / usable).clamp(0.0, 1.0);
  }

  void _start(Offset local, double width) {
    if (_totalMs <= 0) return;
    // Un toque que pasa a arrastre llama dos veces: sólo vibra la primera.
    if (_active.value < 0.5) HapticFeedback.selectionClick();
    _dragging = true;
    _active.forward();
    _setProgress(_valueAt(local, width));
  }

  void _update(Offset local, double width) {
    if (!_dragging) return;
    _setProgress(_valueAt(local, width));
  }

  Future<void> _end() async {
    if (!_dragging) return;
    _dragging = false;
    _active.reverse();
    final value = _progress.value;
    _pendingSeek = value;
    // Si el reproductor no llega a confirmar la posición (fallo de seek),
    // se suelta el valor retenido para no congelar la barra.
    Future.delayed(const Duration(seconds: 2), () => _pendingSeek = null);
    await widget.onSeek(Duration(milliseconds: (value * _totalMs).round()));
  }

  void _cancel() {
    if (!_dragging) return;
    _dragging = false;
    _active.reverse();
    _syncFromPlayer();
  }

  static String _format(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final minimal = widget.minimal;
    final restLabel = minimal ? Colors.white60 : colors.textTertiary;
    final activeLabel = minimal ? Colors.white : colors.textPrimary;
    final labelStyle = context.texts.bodySmall?.copyWith(
      color: restLabel,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.2,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            _trackPx =
                (width - _SeekBarPainter.inset * 2) *
                MediaQuery.devicePixelRatioOf(context);
            return Semantics(
              slider: true,
              label: 'Posición de la canción',
              value: _format(Duration(seconds: _shownSecond.value)),
              increasedValue: _format(
                Duration(seconds: _shownSecond.value + 10),
              ),
              decreasedValue: _format(
                Duration(seconds: (_shownSecond.value - 10).clamp(0, 1 << 30)),
              ),
              onIncrease: () =>
                  widget.onSeek(Duration(seconds: _shownSecond.value + 10)),
              onDecrease: () => widget.onSeek(
                Duration(seconds: (_shownSecond.value - 10).clamp(0, 1 << 30)),
              ),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (d) => _start(d.localPosition, width),
                onHorizontalDragUpdate: (d) => _update(d.localPosition, width),
                onHorizontalDragEnd: (_) => _end(),
                onHorizontalDragCancel: _cancel,
                onTapDown: (d) => _start(d.localPosition, width),
                onTapUp: (_) => _end(),
                // Si el toque acaba en arrastre, éste vuelve a llamar a
                // _start justo después; si lo gana el scroll, se restaura.
                onTapCancel: _cancel,
                child: RepaintBoundary(
                  child: SizedBox(
                    height: _touchHeight,
                    width: width,
                    child: CustomPaint(
                      painter: _SeekBarPainter(
                        progress: _progress,
                        buffered: _buffered,
                        active: _active,
                        minimal: minimal,
                        gradient: minimal
                            ? const LinearGradient(
                                colors: [Colors.white, Colors.white],
                              )
                            : colors.brandGradient,
                        glow: minimal ? Colors.white : colors.primary,
                        track: minimal ? Colors.white : colors.textPrimary,
                        thumb: Colors.white,
                        bubbleColor: minimal
                            ? const Color(0xFF2A2A2A)
                            : colors.surface2,
                        bubbleText: context.texts.labelMedium!.copyWith(
                          color: activeLabel,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        labelFor: (v) => _format(
                          Duration(milliseconds: (v * _totalMs).round()),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        Padding(
          // Los tiempos arrancan donde empieza y acaba la pista.
          padding: const EdgeInsets.symmetric(
            horizontal: _SeekBarPainter.inset - 2,
          ),
          child: ValueListenableBuilder<int>(
            valueListenable: _shownSecond,
            builder: (context, second, _) {
              final elapsed = Duration(seconds: second);
              final remaining = _duration - elapsed;
              return AnimatedBuilder(
                animation: _active,
                builder: (context, _) {
                  // Mientras se arrastra, el tiempo transcurrido se resalta.
                  final t = Curves.easeOut.transform(_active.value);
                  final elapsedStyle = labelStyle?.copyWith(
                    color: Color.lerp(restLabel, activeLabel, t),
                  );
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_format(elapsed), style: elapsedStyle),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () =>
                            setState(() => _showRemaining = !_showRemaining),
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: AppSpacing.lg,
                            top: AppSpacing.xxs,
                            bottom: AppSpacing.xxs,
                          ),
                          child: Text(
                            _showRemaining
                                ? '-${_format(remaining.isNegative ? Duration.zero : remaining)}'
                                : _format(_duration),
                            style: labelStyle,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SeekBarPainter extends CustomPainter {
  _SeekBarPainter({
    required this.progress,
    required this.buffered,
    required this.active,
    required this.minimal,
    required this.gradient,
    required this.glow,
    required this.track,
    required this.thumb,
    required this.bubbleColor,
    required this.bubbleText,
    required this.labelFor,
  }) : super(repaint: Listenable.merge([progress, buffered, active]));

  final ValueListenable<double> progress;
  final ValueListenable<double> buffered;
  final Animation<double> active;
  final bool minimal;
  final Gradient gradient;
  final Color glow;
  final Color track;
  final Color thumb;
  final Color bubbleColor;
  final TextStyle bubbleText;
  final String Function(double progress) labelFor;

  /// Margen lateral de la pista: medio tirador activo por cada lado, para que
  /// no se salga de la columna en 0 % ni en 100 %.
  static const double inset = _thumbActive;

  // Medidas en reposo → activo.
  static const double _trackRest = 4;
  static const double _trackActive = 8;
  static const double _thumbRest = 6;
  static const double _thumbActive = 10;
  static const double _minimalTrackRest = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final t = Curves.easeOutCubic.transform(active.value);
    final trackH = minimal
        ? lerpDouble(_minimalTrackRest, _trackRest, t)!
        : lerpDouble(_trackRest, _trackActive, t)!;
    final thumbR = minimal
        ? lerpDouble(0, _thumbRest + 1, t)!
        : lerpDouble(_thumbRest, _thumbActive, t)!;
    final radius = Radius.circular(trackH / 2);

    final left = inset;
    final right = size.width - inset;
    final width = (right - left).clamp(0.0, double.infinity);
    final cy = size.height / 2;
    final top = cy - trackH / 2;

    final p = progress.value.clamp(0.0, 1.0);
    final b = buffered.value.clamp(0.0, 1.0);
    final x = left + width * p;

    final full = RRect.fromLTRBR(left, top, right, top + trackH, radius);

    // 1. Pista de fondo.
    canvas.drawRRect(
      full,
      Paint()..color = track.withValues(alpha: minimal ? 0.22 : 0.12),
    );

    // 2. Parte ya cargada en búfer.
    if (b > p) {
      canvas.drawRRect(
        RRect.fromLTRBR(left, top, left + width * b, top + trackH, radius),
        Paint()..color = track.withValues(alpha: 0.10),
      );
    }

    // 3. Progreso con el degradado de la marca. El shader cubre la pista
    //    entera para que el color de cada punto no cambie al avanzar.
    if (x > left) {
      final played = RRect.fromLTRBR(left, top, x, top + trackH, radius);
      final shader = gradient.createShader(full.outerRect);
      if (minimal) {
        canvas.drawRRect(played, Paint()..shader = shader);
      } else {
        // Resplandor suave bajo lo reproducido; se intensifica al tocar.
        canvas.drawRRect(
          played,
          Paint()
            ..shader = shader
            ..maskFilter = MaskFilter.blur(
              BlurStyle.normal,
              lerpDouble(3, 6, t)!,
            )
            ..color = Colors.white.withValues(alpha: lerpDouble(0.35, 0.6, t)!),
        );
        canvas.drawRRect(played, Paint()..shader = shader);

        // Brillo fino en el borde superior: da volumen a la pista.
        canvas.save();
        canvas.clipRRect(played);
        canvas.drawRect(
          Rect.fromLTWH(left, top, x - left, trackH * 0.45),
          Paint()..color = Colors.white.withValues(alpha: 0.18),
        );
        canvas.restore();
      }
    }

    // 4. Halo del tirador al tocar.
    if (t > 0) {
      canvas.drawCircle(
        Offset(x, cy),
        thumbR + 10 * t,
        Paint()..color = glow.withValues(alpha: 0.18 * t),
      );
    }

    // 5. Tirador: sombra, cuerpo blanco y punto de color en el centro.
    final center = Offset(x, cy);
    if (thumbR > 0) {
      canvas.drawCircle(
        center.translate(0, 1.5),
        thumbR,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawCircle(center, thumbR, Paint()..color = thumb);
      if (!minimal) {
        canvas.drawCircle(center, thumbR * 0.38 * t, Paint()..color = glow);
      }
    }

    // 6. Burbuja con el tiempo de destino, sólo mientras se toca. Sube y
    //    aparece con la misma animación que ensancha la pista.
    if (t > 0.01) _paintBubble(canvas, size, center, thumbR, t);
  }

  void _paintBubble(
    Canvas canvas,
    Size size,
    Offset thumbCenter,
    double thumbR,
    double t,
  ) {
    final text = TextPainter(
      text: TextSpan(text: labelFor(progress.value), style: bubbleText),
      textDirection: TextDirection.ltr,
    )..layout();

    const padH = 10.0;
    const padV = 5.0;
    const arrow = 5.0;
    final w = text.width + padH * 2;
    final h = text.height + padV * 2;
    final lift = lerpDouble(0, 6, t)!;
    final bottom = thumbCenter.dy - thumbR - 8 - lift;
    // Se mantiene dentro de la barra aunque el tirador esté en un extremo.
    final cx = thumbCenter.dx.clamp(w / 2, size.width - w / 2);
    final rect = Rect.fromLTWH(cx - w / 2, bottom - h - arrow, w, h);

    final alpha = t;
    // Píldora y flecha unidas en un solo contorno: si se dibujan por
    // separado, el borde marca una línea en la unión.
    final body = Path.combine(
      PathOperation.union,
      Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(h / 2))),
      Path()
        ..moveTo(thumbCenter.dx - arrow, rect.bottom - 1)
        ..lineTo(thumbCenter.dx, rect.bottom + arrow)
        ..lineTo(thumbCenter.dx + arrow, rect.bottom - 1)
        ..close(),
    );

    canvas.drawShadow(body, Colors.black.withValues(alpha: alpha), 6, false);
    canvas.drawPath(
      body,
      Paint()..color = bubbleColor.withValues(alpha: alpha),
    );
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = glow.withValues(alpha: 0.45 * alpha),
    );

    canvas.saveLayer(
      rect.inflate(2),
      Paint()..color = Colors.white.withValues(alpha: alpha),
    );
    text.paint(canvas, Offset(rect.left + padH, rect.top + padV));
    canvas.restore();
    text.dispose();
  }

  @override
  bool shouldRepaint(_SeekBarPainter old) =>
      old.minimal != minimal ||
      old.gradient != gradient ||
      old.glow != glow ||
      old.track != track ||
      old.thumb != thumb ||
      old.progress != progress ||
      old.buffered != buffered ||
      old.active != active;
}
