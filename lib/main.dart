import 'package:flutter/material.dart';
import 'services/audio_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'controllers/theme_controller.dart';
import 'controllers/home_controller.dart';
import 'views/home_view.dart';
import 'views/search_view.dart';
import 'views/spotify_discovery_view.dart';
import 'controllers/playlist_controller.dart';
import 'views/favorites_view.dart';
import 'views/playlists_view.dart';
// videos_view.dart: UI oculta temporalmente
// settings moved into drawer menu
import 'views/splash_view.dart';
import 'controllers/trial_controller.dart';
import 'views/trial_expired_view.dart';
import 'views/activation_view.dart';
import 'controllers/video_controller.dart';
import 'controllers/video_settings_controller.dart';
// Videos UI hidden for now

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Solicita permiso de notificaciones en Android 13+ antes de mostrar UI.
  // NOTA: no inicializamos el servicio de notificaciones antes de `runApp`
  // porque en algunos dispositivos esa inicialización puede bloquear o
  // lanzar trabajo pesado en el arranque (causando frames perdidos o
  // crashes tempranos). En su lugar inicializamos en background tras
  // arrancar la UI.
  await _ensureNotificationPermission();
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeController(),
      child: const MyApp(),
    ),
  );

  // Inicializamos el soporte de notificaciones en background sin bloquear
  // el arranque de la UI. Si falla, lo registramos pero no impedimos que
  // la app siga iniciando.
  AudioService.initForNotifications().catchError((e, st) {
    debugPrint('AudioService.initForNotifications error: $e');
  });
}

/// Solicita permiso de notificaciones en Android 13+ (en otras plataformas se ignora).
Future<void> _ensureNotificationPermission() async {
  final status = await Permission.notification.status;
  if (status.isDenied || status.isRestricted) {
    await Permission.notification.request();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>().theme;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => HomeController()),
        ChangeNotifierProvider(
          create: (ctx) =>
              PlaylistController(homeController: ctx.read<HomeController>()),
        ),
        ChangeNotifierProvider(create: (_) => TrialController()..init()),
        ChangeNotifierProvider(create: (_) => VideoController()),
        ChangeNotifierProvider(
          create: (_) => VideoSettingsController()..load(),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Primek Music',
        theme: theme,
        routes: {
          '/search': (ctx) => const SearchView(),
          '/spotify_discovery': (ctx) => const SpotifyDiscoveryView(),
        },
        home: Consumer<TrialController>(
          builder: (context, trial, _) {
            if (trial.loading) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (!trial.activated) {
              return const ActivationView();
            }
            if (trial.expired) {
              return const TrialExpiredView();
            }
            return const SplashView();
          },
        ),
      ),
    );
  }
}

class ReproductorHome extends StatefulWidget {
  const ReproductorHome({super.key});

  @override
  State<ReproductorHome> createState() => _ReproductorHomeState();
}

class _ReproductorHomeState extends State<ReproductorHome>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _drawerOpen = false;
  late final AnimationController _drawerCtrl;
  final Duration _openDuration = const Duration(milliseconds: 200);
  final Duration _closeDuration = const Duration(milliseconds: 80);

  @override
  void initState() {
    super.initState();
    _drawerCtrl = AnimationController(vsync: this, duration: _openDuration);
    // Registrar acceso a settings de video para bloqueo WiFi y subtítulos
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final settings = context.read<VideoSettingsController>();
        VideoSettingsAccess.register(
          settings,
          onBlocked: () {
            final messenger = ScaffoldMessenger.of(context);
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Reproducción bloqueada: requiere conexión WiFi'),
              ),
            );
          },
        );
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _drawerCtrl.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      // Clamp index to available pages in case it was out of range
      final maxIndex = 2; // Home, Favorites, Playlists
      _selectedIndex = index.clamp(0, maxIndex);
    });
  }

  void _toggleDrawer() {
    setState(() {
      _drawerOpen = !_drawerOpen;
      _drawerCtrl.duration = _drawerOpen ? _openDuration : _closeDuration;
      if (_drawerOpen) {
        _drawerCtrl.forward();
      } else {
        _drawerCtrl.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const HomeView(),
      const FavoritesView(),
      const PlaylistsView(),
    ];

    final drawerWidth = MediaQuery.of(context).size.width * 0.78;

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: AnimatedIcon(
                icon: AnimatedIcons.menu_close,
                progress: _drawerCtrl,
              ),
              onPressed: _toggleDrawer,
              tooltip: 'Menú',
            ),
            title: Consumer<TrialController>(
              builder: (context, trial, _) {
                final limitedActive =
                    trial.activated &&
                    !trial.unlimited &&
                    !trial.expired &&
                    trial.remaining != null;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Primek Music'),
                    if (limitedActive) ...[
                      const SizedBox(width: 8),
                      _trialBadge(remaining: trial.remaining!),
                    ],
                  ],
                );
              },
            ),
            // Icono de búsqueda: empuja a la ruta '/search'.
            // La vista de búsqueda se implementará en otra parte; aquí sólo añadimos el símbolo.
            actions: [
              IconButton(
                icon: const Icon(Icons.search),
                tooltip: 'Buscar',
                onPressed: () async {
                  // Búsqueda local (videos temporalmente ocultos)
                  try {
                    Navigator.pushNamed(context, '/search');
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Vista de búsqueda no implementada'),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          body: IndexedStack(index: _selectedIndex, children: pages),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            // Forzamos colores explícitos para evitar que los iconos aparezcan en negro
            selectedItemColor: Theme.of(context).colorScheme.primary,
            unselectedItemColor: Theme.of(
              context,
            ).colorScheme.onSurface.withOpacity(0.7),
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.music_note),
                label: 'Canciones',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.favorite),
                label: 'Favoritos',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.playlist_play),
                label: 'Listas',
              ),
            ],
          ),
        ),

        // Mini video bar hidden while videos are disabled in the UI
        if (_drawerOpen)
          FadeTransition(
            opacity: CurvedAnimation(
              parent: _drawerCtrl,
              curve: Curves.easeInOut,
            ),
            child: GestureDetector(
              onTap: _toggleDrawer,
              child: Container(color: Colors.black54),
            ),
          ),

        // Drawer panel (mejor diseño + staggered animations)
        AnimatedBuilder(
          animation: _drawerCtrl,
          builder: (context, child) {
            final slide =
                Tween<Offset>(
                  begin: const Offset(-1.0, 0.0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: _drawerCtrl,
                    curve: Curves.easeOutCubic,
                  ),
                );
            return FractionalTranslation(
              translation: slide.value,
              child: child,
            );
          },
          child: SizedBox(
            width: drawerWidth,
            child: SafeArea(
              child: Material(
                elevation: 12,
                color: Theme.of(context).scaffoldBackgroundColor,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Consumer<ThemeController>(
                    builder: (context, themeCtrl, _) {
                      final keys = themeCtrl.availableKeys;
                      final names = <String, String>{
                        'default': 'Clásico (Morado)',
                        'dark': 'Oscuro',
                        'red_black': 'Rojo & Negro',
                        'blue_light': 'Azul (Claro)',
                      };

                      Animation<double> stagger(
                        int index,
                        int total, {
                        double start = 0.12,
                        double step = 0.06,
                      }) {
                        final s = (start + index * step).clamp(0.0, 1.0);
                        final e = (s + step).clamp(0.0, 1.0);
                        return CurvedAnimation(
                          parent: _drawerCtrl,
                          curve: Interval(s, e, curve: Curves.easeOut),
                        );
                      }

                      final totalItems = 3 + keys.length;
                      int idx = 0;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FadeTransition(
                            opacity: stagger(idx++, totalItems),
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(-0.05, 0),
                                end: Offset.zero,
                              ).animate(stagger(0, totalItems)),
                              child: Container(
                                margin: const EdgeInsets.all(12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Theme.of(context).primaryColor,
                                      Theme.of(
                                        context,
                                      ).primaryColor.withOpacity(0.9),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 8,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 56,
                                      height: 56,
                                      alignment: Alignment.center,
                                      child: CircleAvatar(
                                        radius: 28,
                                        backgroundColor: Colors.white24,
                                        backgroundImage: const AssetImage(
                                          'assets/menu_logo.png',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: const [
                                          Text(
                                            'Primek Music',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'Tu música, tu ritmo',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          FadeTransition(
                            opacity: stagger(idx++, totalItems),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                              ),
                              child: Text(
                                'Tema',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Expanded(
                            child: ListView(
                              padding: EdgeInsets.zero,
                              children: [
                                ...keys.asMap().entries.map((entry) {
                                  final kIndex = entry.key;
                                  final k = entry.value;
                                  final anim = stagger(
                                    idx + kIndex,
                                    totalItems,
                                  );
                                  return FadeTransition(
                                    opacity: anim,
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(-0.03, 0),
                                        end: Offset.zero,
                                      ).animate(anim),
                                      child: RadioListTile<String>(
                                        value: k,
                                        groupValue: themeCtrl.currentKey,
                                        onChanged: (v) {
                                          if (v != null) themeCtrl.setTheme(v);
                                        },
                                        title: Text(names[k] ?? k),
                                      ),
                                    ),
                                  );
                                }).toList(),
                                const Divider(),
                                FadeTransition(
                                  opacity: stagger(
                                    idx + keys.length,
                                    totalItems,
                                  ),
                                  child: SlideTransition(
                                    position:
                                        Tween<Offset>(
                                          begin: const Offset(-0.03, 0),
                                          end: Offset.zero,
                                        ).animate(
                                          stagger(
                                            idx + keys.length,
                                            totalItems,
                                          ),
                                        ),
                                    child: ListTile(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      leading: CircleAvatar(
                                        backgroundColor: Theme.of(
                                          context,
                                        ).primaryColor,
                                        child: const Icon(
                                          Icons.notifications,
                                          color: Colors.white,
                                        ),
                                      ),
                                      title: const Text('Notificaciones'),
                                      subtitle: const Text(
                                        'Configuración del sistema',
                                      ),
                                      onTap: () {
                                        showDialog(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            title: const Text('Notificaciones'),
                                            content: const Text(
                                              'La configuración de notificaciones se gestiona desde el sistema. En Android 13+ solicita permiso si es necesario.',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                child: const Text('Cerrar'),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                // Nuevo: Encontrar Nuevos Temas (Spotify)
                                FadeTransition(
                                  opacity: stagger(
                                    idx + keys.length + 1,
                                    totalItems,
                                  ),
                                  child: SlideTransition(
                                    position:
                                        Tween<Offset>(
                                          begin: const Offset(-0.03, 0),
                                          end: Offset.zero,
                                        ).animate(
                                          stagger(
                                            idx + keys.length + 1,
                                            totalItems,
                                          ),
                                        ),
                                    child: ListTile(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      leading: CircleAvatar(
                                        backgroundColor: Theme.of(
                                          context,
                                        ).primaryColor,
                                        child: const Icon(
                                          Icons.search,
                                          color: Colors.white,
                                        ),
                                      ),
                                      title: const Text(
                                        'Encontrar Nuevos Temas',
                                      ),
                                      subtitle: const Text('Buscar en Spotify'),
                                      onTap: () {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Esta funcionalidad no está implementada',
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),

                                // EzConv downloader removed
                                // Acerca de (mantenido)
                                FadeTransition(
                                  opacity: stagger(
                                    idx + keys.length + 2,
                                    totalItems,
                                  ),
                                  child: SlideTransition(
                                    position:
                                        Tween<Offset>(
                                          begin: const Offset(-0.03, 0),
                                          end: Offset.zero,
                                        ).animate(
                                          stagger(
                                            idx + keys.length + 2,
                                            totalItems,
                                          ),
                                        ),
                                    child: ListTile(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      leading: CircleAvatar(
                                        backgroundColor: Theme.of(
                                          context,
                                        ).primaryColor,
                                        child: const Icon(
                                          Icons.info,
                                          color: Colors.white,
                                        ),
                                      ),
                                      title: const Text('Acerca de'),
                                      subtitle: const Text('Versión 0.0.1'),
                                      onTap: () {
                                        showAboutDialog(
                                          context: context,
                                          applicationName: 'Primek Music',
                                          applicationVersion: '0.0.1',
                                          applicationIcon: const Icon(
                                            Icons.music_note,
                                          ),
                                          children: const [
                                            Text(
                                              'Reproductor simple de música.',
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _trialBadge({required Duration remaining}) {
    String fmt(Duration d) {
      final days = d.inDays;
      final hours = d.inHours % 24;
      if (days > 0) {
        return '${days}d ${hours}h';
      }
      final h = d.inHours;
      final m = d.inMinutes % 60;
      return '${h}h ${m}m';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange.shade600,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer, size: 16, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            fmt(remaining),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
