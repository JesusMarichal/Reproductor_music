import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:audio_service/audio_service.dart' as a;
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../controllers/home_controller.dart';
import '../controllers/playlist_controller.dart';
import '../models/song.dart';
import '../services/artwork_cache.dart';
import '../theme/app_theme.dart';
import '../widgets/now_playing_indicator.dart';
import '../widgets/player_seekbar.dart';
import '../widgets/song_artwork.dart' show SongArtwork, artworkFlightShuttle;

/// Reproductor a pantalla completa, al estilo de YouTube Music: fondo teñido
/// con el color de la carátula, controles en blanco y la cola en una hoja
/// que se despliega desde abajo ("Reproduciendo desde").
///
/// Es siempre oscuro, sea cual sea el tema: el color lo pone la carátula.
class PlayerView extends StatefulWidget {
  const PlayerView({super.key});

  /// Bandera global para evitar apilar dos instancias de esta pantalla.
  static bool isOpen = false;

  @override
  State<PlayerView> createState() => _PlayerViewState();
}

/// Color del fondo cuando la canción no tiene carátula.
const Color _kFallbackTint = Color(0xFF2B2B2B);

/// Alto de la hoja de la cola plegada: asa + nombre de la fuente.
const double _kQueuePeek = 76;

/// Duración del ajuste de la hoja de la cola a abierta / plegada.
const Duration _kQueueSnap = Duration(milliseconds: 300);

class _PlayerViewState extends State<PlayerView> {
  /// Clave de caché ([ArtworkCache.keyOf]) de la carátula mostrada.
  String? _artworkSongId;
  Uint8List? _artworkBytes;

  /// Color dominante de la carátula, ya oscurecido para el fondo.
  Color _tint = _kFallbackTint;
  static final Map<String, Color> _tintCache = {};

  final DraggableScrollableController _sheet = DraggableScrollableController();

  /// Textura de ruido para el dithering del degradado del fondo.
  ui.Image? _noise;

  /// 0 = cola plegada, 1 = cola desplegada.
  final ValueNotifier<double> _queueT = ValueNotifier(0);

  /// Si la cola está más abierta que cerrada. Aparte de [_queueT] para que
  /// la barra superior sólo se reconstruya al cruzar la mitad.
  final ValueNotifier<bool> _queueOpen = ValueNotifier(false);

  /// Carátula decodificada para pintarla a todo lo ancho con la cola abierta.
  ui.Image? _bleedImage;
  String? _bleedKey;

  @override
  void initState() {
    super.initState();
    PlayerView.isOpen = true;
    _sheet.addListener(_onSheetChanged);
    _BackdropPainter.noiseTexture().then((image) {
      if (mounted) setState(() => _noise = image);
    });
    // La carátula se lee de forma síncrona de la caché (la precarga
    // HomeController al cambiar de pista). Así el primer frame de la
    // transición ya la lleva y no hay salto ni decodificación a mitad.
    final song = context.read<HomeController>().currentSong;
    if (song != null && ArtworkCache.instance.contains(song)) {
      _artworkSongId = ArtworkCache.keyOf(song);
      _artworkBytes = ArtworkCache.instance.peek(song);
      _tint = _tintCache[_artworkSongId] ?? _kFallbackTint;
      _updateTint(_artworkSongId!, _artworkBytes);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<HomeController>().playerViewOpen = true;
    });
  }

  @override
  void dispose() {
    PlayerView.isOpen = false;
    _sheet.dispose();
    _queueT.dispose();
    _queueOpen.dispose();
    _bleedImage?.dispose();
    super.dispose();
  }

  /// Carga la carátula de [song] si todavía no estaba en caché.
  Future<void> _loadArtwork(Song song) async {
    final key = ArtworkCache.keyOf(song);
    _artworkSongId = key;
    final bytes = await ArtworkCache.instance.load(song);
    if (!mounted || _artworkSongId != key) return;
    setState(() => _artworkBytes = bytes);
    _updateTint(key, bytes);
  }

  Future<void> _updateTint(String key, Uint8List? bytes) async {
    _decodeBleed(key, bytes);
    final cached = _tintCache[key];
    final tint = cached ?? (bytes == null ? null : await _dominantTint(bytes));
    if (tint != null) _tintCache[key] = tint;
    if (!mounted || _artworkSongId != key) return;
    setState(() => _tint = tint ?? _kFallbackTint);
  }

  /// Decodifica la carátula para el fondo de la cola abierta, a un ancho
  /// acotado: se ve a pantalla completa pero detrás de un fundido.
  Future<void> _decodeBleed(String key, Uint8List? bytes) async {
    if (_bleedKey == key) return;
    _bleedKey = key;
    ui.Image? image;
    if (bytes != null) {
      try {
        final codec = await ui.instantiateImageCodec(bytes, targetWidth: 720);
        image = (await codec.getNextFrame()).image;
      } catch (e) {
        debugPrint('PlayerView: no se pudo decodificar la carátula: $e');
      }
    }
    if (!mounted || _bleedKey != key) {
      image?.dispose();
      return;
    }
    setState(() {
      _bleedImage?.dispose();
      _bleedImage = image;
    });
  }

  /// Mueve la hoja siguiendo el dedo sobre la cabecera.
  void _dragSheet(double dy, double height) {
    if (!_sheet.isAttached || height <= 0) return;
    _sheet.jumpTo((_sheet.size - dy / height).clamp(_sheetMin, _sheetMax));
  }

  /// Al soltar la cabecera: un gesto rápido decide por su dirección; uno
  /// lento, por la posición en que se suelta.
  void _endSheetDrag(double velocity) {
    if (!_sheet.isAttached) return;
    final open = velocity.abs() > 300
        ? velocity < 0
        : _sheet.size > (_sheetMin + _sheetMax) / 2;
    _setQueueOpen(open);
  }

  /// Sigue el tamaño de la hoja, venga del dedo, del snap o de animateTo.
  void _onSheetChanged() {
    if (!_sheet.isAttached) return;
    final t = ((_sheet.size - _sheetMin) / (_sheetMax - _sheetMin)).clamp(
      0.0,
      1.0,
    );
    _queueT.value = t;
    _queueOpen.value = t > 0.5;
  }

  void _setQueueOpen(bool open) {
    if (!_sheet.isAttached) return;
    _sheet.animateTo(
      open ? _sheetMax : _sheetMin,
      duration: _kQueueSnap,
      curve: Curves.easeOutCubic,
    );
  }

  double _sheetMin = 0.1;
  static const double _sheetMax = 0.46;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<HomeController>();
    final song = controller.currentSong;

    if (song == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Cerrar',
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        body: const Center(child: Text('No hay ninguna canción sonando')),
      );
    }

    final key = ArtworkCache.keyOf(song);
    if (_artworkSongId != key) {
      final cached = ArtworkCache.instance.peek(song);
      _artworkSongId = key;
      if (cached != null || ArtworkCache.instance.contains(song)) {
        _artworkBytes = cached;
        _tint = _tintCache[key] ?? _tint;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _updateTint(key, cached),
        );
      } else {
        // Fuera del build síncrono: sólo se dispara al cambiar de pista.
        WidgetsBinding.instance.addPostFrameCallback((_) => _loadArtwork(song));
      }
    }

    final sourceTitle =
        controller.queueTitle ??
        controller.currentMixedPlaylistTitle ??
        'Reproduciendo';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: _tint),
          duration: AppDuration.slow,
          // El fondo va en su propia capa: si no, cada frame de la hoja
          // repintaría el degradado a pantalla completa.
          builder: (context, tint, child) => Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(
                child: _BakedBackdrop(tint: tint!, noise: _noise),
              ),
              child!,
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final padding = MediaQuery.paddingOf(context);
              final height = constraints.maxHeight;
              _sheetMin = ((_kQueuePeek + padding.bottom) / height).clamp(
                0.05,
                0.3,
              );
              return Stack(
                children: [
                  // Con la cola abierta la carátula pasa a ser el fondo de
                  // la parte superior, como en YT Music. Tamaño fijo (el
                  // de la cola abierta): sólo cambia su opacidad.
                  if (_bleedImage != null)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: height * (1 - _sheetMax) * 0.82,
                      child: IgnorePointer(
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: _FullBleedPainter(
                              image: _bleedImage!,
                              t: _queueT,
                              tint: _tint,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: height * (1 - _sheetMin),
                    child: _PlayerContent(
                      song: song,
                      bytes: _artworkBytes,
                      queueT: _queueT,
                      queueOpen: _queueOpen,
                      travel: height * (_sheetMax - _sheetMin),
                      topPadding: padding.top,
                      onToggleQueue: () => _setQueueOpen(!_queueOpen.value),
                    ),
                  ),
                  DraggableScrollableSheet(
                    controller: _sheet,
                    initialChildSize: _sheetMin,
                    minChildSize: _sheetMin,
                    maxChildSize: _sheetMax,
                    snap: true,
                    // Sin esto, al soltar la hoja termina el recorrido a la
                    // velocidad del dedo: si se suelta despacio tarda
                    // segundos en asentarse y parece que se queda pegada.
                    snapAnimationDuration: _kQueueSnap,
                    builder: (context, scrollController) => _QueueSheet(
                      scrollController: scrollController,
                      queueT: _queueT,
                      sourceTitle: sourceTitle,
                      bottomPadding: padding.bottom,
                      onHandleTap: () => _setQueueOpen(_queueT.value < 0.5),
                      onHandleDrag: (dy) => _dragSheet(dy, height),
                      onHandleDragEnd: _endSheetDrag,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Color de fondo a partir de una carátula, como hace YouTube Music: el tono
/// más vivo y abundante de la portada, muy oscuro y saturado, para que el
/// texto blanco se lea encima.
///
/// No se promedian los colores: en una portada roja con una cara, la media
/// de rojo y piel da un marrón apagado. En su lugar se agrupan los píxeles
/// por matiz (cubos de 15°), cada uno pesa según lo vivo que es y gana el
/// matiz con más peso.
Future<Color?> _dominantTint(Uint8List bytes) async {
  try {
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 24);
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    frame.image.dispose();
    if (data == null) return null;

    const buckets = 24;
    final weights = List<double>.filled(buckets, 0);
    final sats = List<double>.filled(buckets, 0);
    final pixels = <(double hue, double weight)>[];
    var colorful = 0.0;
    var count = 0;

    for (var i = 0; i + 3 < data.lengthInBytes; i += 4) {
      final hsl = HSLColor.fromColor(
        Color.fromARGB(
          255,
          data.getUint8(i),
          data.getUint8(i + 1),
          data.getUint8(i + 2),
        ),
      );
      count++;
      // Croma relativa: alta en colores vivos de luminosidad media, nula en
      // grises, negros y blancos.
      final chroma = hsl.saturation * (1 - (2 * hsl.lightness - 1).abs());
      if (chroma < 0.05) continue;
      final weight = chroma * chroma;
      final bucket = (hsl.hue / (360 / buckets)).floor() % buckets;
      weights[bucket] += weight;
      sats[bucket] += hsl.saturation * weight;
      colorful += chroma;
      pixels.add((hsl.hue, weight));
    }

    // Portada casi en blanco y negro: gris oscuro neutro.
    final colorfulness = count == 0 ? 0.0 : colorful / count;
    if (colorfulness < 0.02) {
      return const Color(0xFF262626);
    }

    // El cubo ganador se suaviza con sus vecinos para no partir un matiz
    // que cae justo en el borde entre dos cubos.
    var best = 0;
    var bestScore = -1.0;
    for (var b = 0; b < buckets; b++) {
      final score =
          weights[b] * 2 +
          weights[(b + 1) % buckets] +
          weights[(b - 1 + buckets) % buckets];
      if (score > bestScore) {
        bestScore = score;
        best = b;
      }
    }

    // Media circular del matiz dentro del cubo ganador y sus vecinos.
    const span = 360 / buckets;
    final center = (best + 0.5) * span;
    double x = 0, y = 0;
    for (final (hue, weight) in pixels) {
      var delta = (hue - center).abs() % 360;
      if (delta > 180) delta = 360 - delta;
      if (delta > span * 1.5) continue;
      final rad = hue * math.pi / 180;
      x += math.cos(rad) * weight;
      y += math.sin(rad) * weight;
    }
    final hue = (math.atan2(y, x) * 180 / math.pi + 360) % 360;
    final saturation = weights[best] > 0 ? sats[best] / weights[best] : 0.5;

    return HSLColor.fromAHSL(
      1,
      hue,
      // Portadas con poco color (casi todo gris y un acento) tiñen menos.
      saturation.clamp(0.35, 0.75) * (colorfulness < 0.06 ? 0.6 : 1),
      0.15,
    ).toColor();
  } catch (e) {
    debugPrint('PlayerView: no se pudo calcular el color de la carátula: $e');
    return null;
  }
}

/// Pinta [_BackdropPainter] una sola vez en una imagen del tamaño de la
/// pantalla y luego sólo la copia.
///
/// El degradado más el ruido son dos pasadas a pantalla completa; repetirlas
/// en cada frame (la hoja de la cola, la barra de progreso...) era la mayor
/// parte del coste de componer el reproductor.
class _BakedBackdrop extends StatefulWidget {
  const _BakedBackdrop({required this.tint, required this.noise});

  final Color tint;
  final ui.Image? noise;

  @override
  State<_BakedBackdrop> createState() => _BakedBackdropState();
}

class _BakedBackdropState extends State<_BakedBackdrop> {
  ui.Image? _image;
  (Color, ui.Image?, Size, double)? _bakedFor;

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  ui.Image _bake(Size size, double ratio) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(ratio);
    _BackdropPainter(
      tint: widget.tint,
      noise: widget.noise,
    ).paint(canvas, size);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(
      (size.width * ratio).ceil(),
      (size.height * ratio).ceil(),
    );
    picture.dispose();
    return image;
  }

  @override
  Widget build(BuildContext context) {
    final ratio = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final key = (widget.tint, widget.noise, size, ratio);
        if (_bakedFor != key && !size.isEmpty) {
          _image?.dispose();
          _image = _bake(size, ratio);
          _bakedFor = key;
        }
        return RawImage(
          image: _image,
          width: size.width,
          height: size.height,
          fit: BoxFit.fill,
          filterQuality: FilterQuality.none,
        );
      },
    );
  }
}

/// Fondo del reproductor: degradado vertical del color de la carátula a casi
/// negro, con dithering.
///
/// Un degradado tan oscuro recorre muy pocos niveles de color (de ~60 a ~25
/// por canal en toda la pantalla), así que cada nivel ocupa una franja de
/// varias decenas de píxeles y se ven bandas. Una capa de ruido de ±1 nivel,
/// imperceptible como textura, rompe esos bordes.
class _BackdropPainter extends CustomPainter {
  _BackdropPainter({required this.tint, required this.noise});

  final Color tint;
  final ui.Image? noise;

  static Future<ui.Image>? _noiseTexture;

  /// Textura de 64×64 con píxeles blancos y negros casi transparentes. Se
  /// genera una vez y se repite en mosaico.
  static Future<ui.Image> noiseTexture() {
    return _noiseTexture ??= () {
      const side = 64;
      final random = math.Random(7);
      final pixels = Uint8List(side * side * 4);
      for (var i = 0; i < pixels.length; i += 4) {
        // Alfa premultiplicado: el canal de color no puede superar al alfa,
        // así que un blanco casi transparente es (a, a, a, a).
        final alpha = 2 + random.nextInt(5);
        final value = random.nextBool() ? alpha : 0;
        pixels[i] = value;
        pixels[i + 1] = value;
        pixels[i + 2] = value;
        pixels[i + 3] = alpha;
      }
      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        pixels,
        side,
        side,
        ui.PixelFormat.rgba8888,
        completer.complete,
      );
      return completer.future;
    }();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [tint, Color.lerp(tint, Colors.black, 0.6)!],
        ).createShader(rect),
    );
    final texture = noise;
    if (texture != null) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ImageShader(
            texture,
            TileMode.repeated,
            TileMode.repeated,
            Matrix4.identity().storage,
          ),
      );
    }
  }

  @override
  bool shouldRepaint(_BackdropPainter old) =>
      old.tint != tint || old.noise != noise;
}

/// La carátula a todo lo ancho, que aparece al abrir la cola y se funde con
/// el fondo por abajo.
///
/// Se pinta a tiras horizontales con opacidad decreciente en vez de con un
/// `ShaderMask`: la máscara obliga a una capa intermedia (`saveLayer`) en
/// cada frame de la animación, y las tiras son sólo unas decenas de
/// `drawImageRect`. La opacidad global [t] se aplica en las mismas tiras,
/// por lo que tampoco hace falta un widget `Opacity` encima.
class _FullBleedPainter extends CustomPainter {
  _FullBleedPainter({required this.image, required this.t, required this.tint})
    : super(repaint: t);

  final ui.Image image;
  final ValueListenable<double> t;
  final Color tint;

  static const int _strips = 48;

  /// Fracción del alto, desde arriba, que se ve opaca antes del fundido.
  static const double _solid = 0.55;

  @override
  void paint(Canvas canvas, Size size) {
    final visibility = t.value;
    if (visibility <= 0 || size.isEmpty) return;

    // Recorte "cover" alineado arriba, como `BoxFit.cover` + `topCenter`.
    final scale = math.max(
      size.width / image.width,
      size.height / image.height,
    );
    final srcWidth = size.width / scale;
    final srcLeft = (image.width - srcWidth) / 2;

    final paint = Paint()
      ..filterQuality = FilterQuality.medium
      ..isAntiAlias = false;
    final stripHeight = size.height / _strips;
    for (var i = 0; i < _strips; i++) {
      final mid = (i + 0.5) / _strips;
      final fade = mid <= _solid ? 1.0 : 1 - (mid - _solid) / (1 - _solid);
      final alpha = fade * visibility;
      if (alpha <= 0.004) continue;
      paint.color = Colors.white.withValues(alpha: alpha);
      final top = i * stripHeight;
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(srcLeft, top / scale, srcWidth, stripHeight / scale),
        Rect.fromLTWH(0, top, size.width, stripHeight),
        paint,
      );
    }

    // Oscurece arriba (iconos) y hacia el texto, para que se lea en blanco.
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0, 0.2, 0.6, 1],
          colors: [
            Colors.black.withValues(alpha: 0.35 * visibility),
            Colors.transparent,
            tint.withValues(alpha: 0.45 * visibility),
            tint.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_FullBleedPainter old) =>
      old.image != image || old.t != t || old.tint != tint;
}

/// Alto que ocupan los chips (con su margen superior) en la columna.
const double _kChipsBlock = AppSpacing.lg + 40;

/// Todo lo que queda por encima de la hoja de la cola.
///
/// Se maqueta siempre en la posición de cola plegada y no se reconstruye
/// mientras la hoja se mueve: la animación sólo desplaza y desvanece bloques
/// ya pintados (cada uno en su `RepaintBoundary`), lo que se resuelve
/// componiendo capas, sin volver a maquetar ni a pintar nada.
class _PlayerContent extends StatelessWidget {
  const _PlayerContent({
    required this.song,
    required this.bytes,
    required this.queueT,
    required this.queueOpen,
    required this.travel,
    required this.topPadding,
    required this.onToggleQueue,
  });

  final Song song;
  final Uint8List? bytes;
  final ValueListenable<double> queueT;
  final ValueListenable<bool> queueOpen;

  /// Lo que sube la hoja de plegada a desplegada, en píxeles lógicos.
  final double travel;
  final double topPadding;
  final VoidCallback onToggleQueue;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<HomeController>();
    final isFavorite = context.select<HomeController, bool>(
      (c) => c.isFavorite(song.id),
    );

    return Padding(
      padding: EdgeInsets.only(top: topPadding),
      child: Column(
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: queueOpen,
            builder: (context, open, _) =>
                _TopBar(queueOpen: open, onToggleQueue: onToggleQueue),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final side = (constraints.maxWidth - AppSpacing.xl * 2)
                    .clamp(0.0, constraints.maxHeight - AppSpacing.lg)
                    .toDouble();
                // La carátula se va en la primera mitad del recorrido.
                return _Fade(
                  t: queueT,
                  opacity: (t) => (1 - t * 2).clamp(0.0, 1.0),
                  child: Center(
                    child: _Artwork(bytes: bytes, song: song, side: side),
                  ),
                );
              },
            ),
          ),
          // El título sube lo mismo que la hoja menos el hueco de los chips,
          // que desaparecen: así queda justo encima de la barra.
          _Slide(
            t: queueT,
            dy: (t) => (-travel + _kChipsBlock) * t,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: _TrackInfo(
                song: song,
                onTap: () => _showSongDetails(context, song),
              ),
            ),
          ),
          _Slide(
            t: queueT,
            dy: (t) => -travel * t,
            child: _Fade(
              t: queueT,
              opacity: (t) => (1 - t * 2.5).clamp(0.0, 1.0),
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.lg),
                child: _ActionChips(
                  isFavorite: isFavorite,
                  onToggleFavorite: () =>
                      controller.toggleFavoriteById(song.id),
                  onSave: () => showAddToPlaylistSheet(context),
                  onQueue: onToggleQueue,
                ),
              ),
            ),
          ),
          _Slide(
            t: queueT,
            dy: (t) => -travel * t,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Column(
                children: [
                  PlayerSeekBar(
                    player: controller.audioService.player,
                    onSeek: controller.audioService.seek,
                    minimal: true,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _TransportControls(controller: controller),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Desplaza [child] en vertical según la animación de la cola, sin
/// reconstruirlo ni repintarlo: sólo cambia el `transform` de su capa.
class _Slide extends StatelessWidget {
  const _Slide({required this.t, required this.dy, required this.child});

  final ValueListenable<double> t;
  final double Function(double t) dy;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: t,
      builder: (context, value, child) =>
          Transform.translate(offset: Offset(0, dy(value)), child: child),
      child: RepaintBoundary(child: child),
    );
  }
}

/// Desvanece [child] según la animación de la cola. Con opacidad 0 deja de
/// pintarse y de recibir toques.
class _Fade extends StatelessWidget {
  const _Fade({required this.t, required this.opacity, required this.child});

  final ValueListenable<double> t;
  final double Function(double t) opacity;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: t,
      builder: (context, value, child) {
        final o = opacity(value);
        return IgnorePointer(
          ignoring: o == 0,
          child: Opacity(opacity: o, child: child),
        );
      },
      child: RepaintBoundary(child: child),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.queueOpen, required this.onToggleQueue});

  final bool queueOpen;
  final VoidCallback onToggleQueue;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          const SizedBox(width: AppSpacing.xs),
          IconButton(
            tooltip: 'Cerrar',
            color: Colors.white,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const Spacer(),
          // Selector canción / cola, como el de canción / vídeo de YT Music.
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.32),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ToggleSegment(
                  icon: Icons.headphones_rounded,
                  tooltip: 'Canción',
                  selected: !queueOpen,
                  onTap: queueOpen ? onToggleQueue : null,
                ),
                _ToggleSegment(
                  icon: Icons.queue_music_rounded,
                  tooltip: 'Cola',
                  selected: queueOpen,
                  onTap: queueOpen ? null : onToggleQueue,
                ),
              ],
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Añadir a una lista',
            color: Colors.white,
            icon: const Icon(Icons.playlist_add_rounded, size: 26),
            onPressed: () => showAddToPlaylistSheet(context),
          ),
          IconButton(
            tooltip: 'Más opciones',
            color: Colors.white,
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () => _showMoreSheet(context, onToggleQueue),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
    );
  }
}

class _ToggleSegment extends StatelessWidget {
  const _ToggleSegment({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppDuration.fast,
          width: 60,
          height: 36,
          decoration: BoxDecoration(
            color: selected
                ? Colors.white.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Icon(
            icon,
            size: 22,
            color: selected ? Colors.white : Colors.white70,
          ),
        ),
      ),
    );
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork({required this.bytes, required this.song, required this.side});

  final Uint8List? bytes;
  final Song song;

  /// Lado del cuadrado, ya acotado por el espacio disponible.
  final double side;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'artwork-${song.id}',
      flightShuttleBuilder: artworkFlightShuttle(song),
      child: Container(
        width: side,
        height: side,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xs),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: bytes != null
            // Sin `cacheWidth`: así comparte la imagen decodificada con la
            // carátula que vuela en el Hero y no hay un salto al aterrizar.
            ? Image.memory(bytes!, fit: BoxFit.cover, gaplessPlayback: true)
            : ColoredBox(
                color: Colors.white.withValues(alpha: 0.08),
                child: Icon(
                  Icons.music_note_rounded,
                  size: side * 0.28,
                  color: Colors.white38,
                ),
              ),
      ),
    );
  }
}

class _TrackInfo extends StatelessWidget {
  const _TrackInfo({required this.song, required this.onTap});

  final Song song;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final artist = song.artist?.trim();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 24,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white70,
                size: 26,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            artist?.isNotEmpty == true ? artist! : 'Artista desconocido',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.texts.bodyLarge?.copyWith(color: Colors.white60),
          ),
        ],
      ),
    );
  }
}

/// Fila de acciones en píldoras, desplazable en horizontal.
class _ActionChips extends StatelessWidget {
  const _ActionChips({
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onSave,
    required this.onQueue,
  });

  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onSave;
  final VoidCallback onQueue;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        children: [
          _Chip(
            icon: isFavorite
                ? Icons.thumb_up_alt_rounded
                : Icons.thumb_up_off_alt_rounded,
            label: isFavorite ? 'Te gusta' : 'Me gusta',
            onTap: onToggleFavorite,
          ),
          const SizedBox(width: AppSpacing.sm),
          _Chip(
            icon: Icons.playlist_add_rounded,
            label: 'Guardar',
            onTap: onSave,
          ),
          const SizedBox(width: AppSpacing.sm),
          _Chip(
            icon: Icons.queue_music_rounded,
            label: 'A continuación',
            onTap: onQueue,
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.1),
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: Colors.white),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: context.texts.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransportControls extends StatelessWidget {
  const _TransportControls({required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    final player = controller.audioService.player;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        StreamBuilder<bool>(
          stream: player.shuffleModeEnabledStream,
          initialData: player.shuffleModeEnabled,
          builder: (context, snapshot) {
            final on = snapshot.data ?? false;
            return _ModeButton(
              icon: Icons.shuffle_rounded,
              tooltip: on ? 'Aleatorio activado' : 'Aleatorio',
              on: on,
              onPressed: controller.toggleShuffle,
            );
          },
        ),
        IconButton(
          tooltip: 'Anterior',
          iconSize: 44,
          color: Colors.white,
          icon: const Icon(Icons.skip_previous_rounded),
          onPressed: controller.previous,
        ),
        StreamBuilder<PlayerState>(
          stream: player.playerStateStream,
          initialData: player.playerState,
          builder: (context, snapshot) {
            final state = snapshot.data;
            final playing = state?.playing ?? false;
            final waiting =
                state?.processingState == ProcessingState.loading ||
                state?.processingState == ProcessingState.buffering;

            return SizedBox(
              width: 76,
              height: 76,
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: waiting && !playing
                    ? const Padding(
                        padding: EdgeInsets.all(AppSpacing.xl),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.black,
                        ),
                      )
                    : InkWell(
                        onTap: controller.togglePlayPause,
                        child: Tooltip(
                          message: playing ? 'Pausar' : 'Reproducir',
                          child: Icon(
                            playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 44,
                            color: Colors.black,
                          ),
                        ),
                      ),
              ),
            );
          },
        ),
        IconButton(
          tooltip: 'Siguiente',
          iconSize: 44,
          color: Colors.white,
          icon: const Icon(Icons.skip_next_rounded),
          onPressed: controller.next,
        ),
        StreamBuilder<LoopMode>(
          stream: player.loopModeStream,
          initialData: player.loopMode,
          builder: (context, snapshot) {
            final mode = snapshot.data ?? LoopMode.off;
            final (icon, tooltip) = switch (mode) {
              LoopMode.off => (Icons.repeat_rounded, 'Repetir'),
              LoopMode.all => (Icons.repeat_rounded, 'Repetir todo'),
              LoopMode.one => (Icons.repeat_one_rounded, 'Repetir una'),
            };
            return _ModeButton(
              icon: icon,
              tooltip: tooltip,
              on: mode != LoopMode.off,
              onPressed: controller.cycleRepeatMode,
            );
          },
        ),
      ],
    );
  }
}

/// Aleatorio / repetir: blanco y con un punto debajo cuando está activo.
class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.icon,
    required this.tooltip,
    required this.on,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool on;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 5),
          Icon(icon, size: 26, color: on ? Colors.white : Colors.white60),
          const SizedBox(height: 1),
          AnimatedOpacity(
            duration: AppDuration.fast,
            opacity: on ? 1 : 0,
            child: Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hoja inferior con la cola: plegada enseña el nombre de la fuente;
/// desplegada, "Reproduciendo desde" y las canciones que vienen.
class _QueueSheet extends StatelessWidget {
  const _QueueSheet({
    required this.scrollController,
    required this.queueT,
    required this.sourceTitle,
    required this.bottomPadding,
    required this.onHandleTap,
    required this.onHandleDrag,
    required this.onHandleDragEnd,
  });

  final ScrollController scrollController;
  final ValueListenable<double> queueT;
  final String sourceTitle;
  final double bottomPadding;
  final VoidCallback onHandleTap;

  /// Arrastre de la cabecera, en píxeles (positivo hacia abajo).
  final ValueChanged<double> onHandleDrag;

  /// Fin del arrastre de la cabecera, con su velocidad vertical en px/s.
  final ValueChanged<double> onHandleDragEnd;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<HomeController>();
    final player = controller.audioService.player;

    // La cabecera queda fuera de la lista: así no se va con el scroll (al
    // desplegar con un gesto largo, lo que sobraba desplazaba la lista y la
    // cabecera desaparecía) y arrastrarla siempre mueve la hoja.
    return Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onHandleTap,
          onVerticalDragUpdate: (d) => onHandleDrag(d.delta.dy),
          onVerticalDragEnd: (d) =>
              onHandleDragEnd(d.velocity.pixelsPerSecond.dy),
          child: SizedBox(
            height: _kQueuePeek,
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.md),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white38,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: ValueListenableBuilder<double>(
                    valueListenable: queueT,
                    builder: (context, t, _) => Stack(
                      children: [
                        if (t < 1)
                          Opacity(
                            opacity: (1 - t * 2).clamp(0.0, 1.0),
                            child: Center(
                              child: Text(
                                sourceTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.texts.titleSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        if (t > 0)
                          Opacity(
                            opacity: (t * 2 - 1).clamp(0.0, 1.0),
                            child: _QueueHeader(sourceTitle: sourceTitle),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              // Con la hoja plegada la lista no debe asomar bajo la fuente.
              ValueListenableBuilder<double>(
                valueListenable: queueT,
                // Plegada, además, sus animaciones (el ecualizador de la fila en
                // curso) se detienen: no se ven y obligaban a pintar sin parar.
                builder: (context, t, sliver) => TickerMode(
                  enabled: t > 0,
                  child: SliverOpacity(
                    opacity: (t * 3).clamp(0.0, 1.0),
                    sliver: sliver,
                  ),
                ),
                child: StreamBuilder<SequenceState?>(
                  stream: player.sequenceStateStream,
                  initialData: player.sequenceState,
                  builder: (context, snapshot) {
                    final state = snapshot.data;
                    final current = state?.currentIndex;
                    if (state == null || current == null) {
                      return const SliverToBoxAdapter(child: SizedBox.shrink());
                    }
                    // Orden efectivo (respeta el aleatorio) desde la pista actual.
                    final order = state.shuffleModeEnabled
                        ? state.shuffleIndices
                        : List<int>.generate(state.sequence.length, (i) => i);
                    final start = order.indexOf(current);
                    final upcoming = start < 0 ? <int>[] : order.sublist(start);
                    final canReorder = !state.shuffleModeEnabled;

                    return SliverPadding(
                      padding: EdgeInsets.only(
                        bottom: bottomPadding + AppSpacing.lg,
                      ),
                      sliver: SliverReorderableList(
                        itemCount: upcoming.length,
                        onReorder: (from, to) {
                          if (to > from) to -= 1;
                          // La pista en curso se queda arriba.
                          if (from == 0 || to < 1) to = 1;
                          if (from == to) return;
                          controller.audioService.moveQueueItem(
                            upcoming[from],
                            upcoming[to],
                          );
                        },
                        itemBuilder: (context, i) {
                          final index = upcoming[i];
                          final tag = state.sequence[index].tag;
                          return _QueueTile(
                            key: ValueKey(
                              '${state.sequence[index].hashCode}-$index',
                            ),
                            index: i,
                            item: tag is a.MediaItem ? tag : null,
                            current: i == 0,
                            reorderable: canReorder && i > 0,
                            onTap: () =>
                                controller.audioService.playIndex(index),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QueueHeader extends StatelessWidget {
  const _QueueHeader({required this.sourceTitle});

  final String sourceTitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Reproduciendo desde',
                  style: context.texts.bodyMedium?.copyWith(
                    color: Colors.white60,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  sourceTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: () => _saveQueueAsPlaylist(context, sourceTitle),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              side: BorderSide.none,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
            ),
            icon: const Icon(Icons.playlist_add_rounded, size: 22),
            label: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

class _QueueTile extends StatelessWidget {
  const _QueueTile({
    super.key,
    required this.index,
    required this.item,
    required this.current,
    required this.reorderable,
    required this.onTap,
  });

  final int index;
  final a.MediaItem? item;
  final bool current;
  final bool reorderable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<HomeController>();
    final uri = item?.id;
    final song = uri == null
        ? null
        : controller.songs.where((s) => s.uri == uri).firstOrNull;
    final duration = item?.duration;
    final subtitle = [
      item?.artist ?? song?.artist ?? 'Artista desconocido',
      if (duration != null) _formatDuration(duration),
    ].join(' • ');

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: current ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (song != null)
                      SongArtwork(song: song, size: 56, radius: 4)
                    else
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.music_note_rounded,
                          color: Colors.white38,
                        ),
                      ),
                    if (current)
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Center(
                          child: StreamBuilder<bool>(
                            stream:
                                controller.audioService.player.playingStream,
                            initialData: controller.audioService.player.playing,
                            builder: (context, snapshot) => NowPlayingIndicator(
                              isPlaying: snapshot.data ?? false,
                              color: Colors.white,
                              barWidth: 3,
                              maxHeight: 18,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item?.title ?? song?.title ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.bodyMedium?.copyWith(
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
              if (reorderable)
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Icon(Icons.drag_handle_rounded, color: Colors.white),
                  ),
                )
              else
                const SizedBox(width: 48),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDuration(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// Detalles de la canción, al tocar el título.
void _showSongDetails(BuildContext context, Song song) {
  showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.music_note_rounded),
            title: Text(song.title),
            subtitle: const Text('Título'),
          ),
          ListTile(
            leading: const Icon(Icons.person_outline_rounded),
            title: Text(song.artist ?? 'Artista desconocido'),
            subtitle: const Text('Artista'),
          ),
          if (song.album?.trim().isNotEmpty == true)
            ListTile(
              leading: const Icon(Icons.album_outlined),
              title: Text(song.album!),
              subtitle: const Text('Álbum'),
            ),
          if (song.duration != null)
            ListTile(
              leading: const Icon(Icons.schedule_rounded),
              title: Text(
                _formatDuration(Duration(milliseconds: song.duration!)),
              ),
              subtitle: const Text('Duración'),
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    ),
  );
}

/// Menú de los tres puntos.
void _showMoreSheet(BuildContext context, VoidCallback onShowQueue) {
  final controller = context.read<HomeController>();
  final song = controller.currentSong;
  if (song == null) return;
  final isFavorite = controller.isFavorite(song.id);

  showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(
              isFavorite
                  ? Icons.thumb_up_alt_rounded
                  : Icons.thumb_up_off_alt_rounded,
            ),
            title: Text(isFavorite ? 'Quitar de Me gusta' : 'Me gusta'),
            onTap: () {
              Navigator.pop(sheetContext);
              controller.toggleFavoriteById(song.id);
            },
          ),
          ListTile(
            leading: const Icon(Icons.playlist_add_rounded),
            title: const Text('Guardar en una lista'),
            onTap: () {
              Navigator.pop(sheetContext);
              showAddToPlaylistSheet(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.queue_music_rounded),
            title: const Text('A continuación'),
            onTap: () {
              Navigator.pop(sheetContext);
              onShowQueue();
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('Detalles de la canción'),
            onTap: () {
              Navigator.pop(sheetContext);
              _showSongDetails(context, song);
            },
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    ),
  );
}

/// Guarda la cola en curso como una lista nueva.
Future<void> _saveQueueAsPlaylist(
  BuildContext context,
  String suggestedTitle,
) async {
  final home = context.read<HomeController>();
  final playlists = context.read<PlaylistController>();
  final messenger = ScaffoldMessenger.of(context);
  final state = home.audioService.player.sequenceState;
  if (state.sequence.isEmpty) return;

  final ids = <String>[];
  for (final source in state.effectiveSequence) {
    final tag = source.tag;
    if (tag is! a.MediaItem) continue;
    final song = home.songs.where((s) => s.uri == tag.id).firstOrNull;
    if (song != null) ids.add(song.id);
  }
  if (ids.isEmpty) return;

  final textController = TextEditingController(text: suggestedTitle);
  final title = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Guardar cola como lista'),
      content: TextField(
        controller: textController,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Nombre de la lista'),
        onSubmitted: (v) => Navigator.pop(dialogContext, v),
      ),
      actions: [
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
  if (title == null || title.trim().isEmpty) return;

  await playlists.createPlaylist(title.trim(), '', ids);
  messenger.showSnackBar(
    SnackBar(content: Text('Lista "${title.trim()}" creada')),
  );
}

/// Transición de entrada del reproductor: sube desde abajo.
PageRoute<void> buildPlayerRoute() {
  return PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, __, ___) => const PlayerView(),
    transitionsBuilder: (_, animation, __, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutQuart,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
  );
}

/// Hoja para añadir la canción en curso a una lista de reproducción.
void showAddToPlaylistSheet(BuildContext context) {
  final playlistController = context.read<PlaylistController>();
  final playlists = playlistController.playlists;

  showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) {
      if (playlists.isEmpty) {
        return const SizedBox(
          height: 220,
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Text(
                'Todavía no has creado ninguna lista.\n'
                'Créala desde la pestaña Listas.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      }

      return SafeArea(
        child: ListView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          itemCount: playlists.length,
          itemBuilder: (context, index) {
            final playlist = playlists[index];
            return ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: sheetContext.colors.surface2,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(Icons.queue_music_rounded, size: 20),
              ),
              title: Text(playlist.title),
              subtitle: Text(
                playlist.description.isEmpty
                    ? 'Sin descripción'
                    : playlist.description,
              ),
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.of(sheetContext).pop();
                await playlistController.addSongToPlaylist(playlist.id);
                messenger.showSnackBar(
                  SnackBar(content: Text('Añadido a ${playlist.title}')),
                );
              },
            );
          },
        ),
      );
    },
  );
}
