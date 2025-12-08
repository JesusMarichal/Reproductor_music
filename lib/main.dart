import 'package:flutter/material.dart';
import 'services/audio_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  // Solicita permiso de notificaciones y carga preferencias antes de la UI
  await _ensureNotificationPermission();

  final prefs = await SharedPreferences.getInstance();
  final savedTheme = prefs.getString('theme_key');

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeController(initialKey: savedTheme),
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

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header
                          Container(
                            padding: const EdgeInsets.fromLTRB(24, 50, 24, 30),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Theme.of(
                                    context,
                                  ).primaryColor.withOpacity(0.15),
                                  Colors.transparent,
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Theme.of(
                                          context,
                                        ).primaryColor.withOpacity(0.3),
                                        blurRadius: 15,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: Image.asset(
                                    'assets/menu_logo.png',
                                    width: 60,
                                    height: 60,
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Primek Music',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.5,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurface,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'v1.0.0',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 8,
                            ),
                            child: Text(
                              'APARIENCIA',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                            ),
                          ),

                          // Horizontal Theme Selector
                          SizedBox(
                            height: 70,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: keys.length,
                              itemBuilder: (context, index) {
                                final k = keys[index];
                                final isSelected = themeCtrl.currentKey == k;
                                // Map simplistic colors for preview circles if possible, or use standard palette
                                Color previewColor;
                                switch (k) {
                                  case 'dark':
                                    previewColor = Colors.grey.shade900;
                                    break;
                                  case 'red_black':
                                    previewColor = Colors.red.shade900;
                                    break;
                                  case 'blue_light':
                                    previewColor = Colors.blue;
                                    break;
                                  case 'sunset':
                                    previewColor = Colors.orange;
                                    break;
                                  case 'ocean':
                                    previewColor = Colors.cyan;
                                    break;
                                  case 'deep_space':
                                    previewColor = const Color(0xFF1A237E);
                                    break;
                                  default:
                                    previewColor = Colors.deepPurple;
                                }

                                return GestureDetector(
                                  onTap: () => themeCtrl.setTheme(k),
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: previewColor,
                                      shape: BoxShape.circle,
                                      border: isSelected
                                          ? Border.all(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                              width: 3,
                                            )
                                          : Border.all(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withOpacity(0.3),
                                            ),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: previewColor.withOpacity(
                                                  0.4,
                                                ),
                                                blurRadius: 8,
                                                spreadRadius: 2,
                                              ),
                                            ]
                                          : [],
                                    ),
                                    child: isSelected
                                        ? const Icon(
                                            Icons.check,
                                            color: Colors.white,
                                          )
                                        : null,
                                  ),
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 20),
                          const Divider(indent: 24, endIndent: 24),
                          const SizedBox(height: 10),

                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 8,
                            ),
                            child: Text(
                              'GENERAL',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                            ),
                          ),

                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 24,
                            ),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.notifications_outlined,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            title: Text(
                              'Notificaciones',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            trailing: Icon(
                              Icons.chevron_right,
                              size: 16,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Notificaciones'),
                                  content: const Text(
                                    'La configuración de notificaciones se gestiona desde el sistema.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cerrar'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 24,
                            ),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.info_outline,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            title: Text(
                              'Acerca de',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            trailing: Icon(
                              Icons.chevron_right,
                              size: 16,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => Dialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).cardColor,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withOpacity(0.1),
                                          ),
                                          child: Image.asset(
                                            'assets/menu_logo.png',
                                            width: 64,
                                            height: 64,
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Primek Music',
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'v1.0.0',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(color: Colors.grey),
                                        ),
                                        const SizedBox(height: 24),
                                        const Text(
                                          'Desarrollado por',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'AbstracDev',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.secondary,
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                                        const Text(
                                          'Tu música, tu ritmo. Disfruta de la mejor experiencia de reproducción.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(height: 1.5),
                                        ),
                                        const SizedBox(height: 24),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton(
                                            onPressed: () => Navigator.pop(ctx),
                                            style: ElevatedButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 12,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                            child: const Text('Cerrar'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
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
