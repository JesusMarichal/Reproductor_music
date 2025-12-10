import 'package:flutter/material.dart';
import 'services/audio_service.dart';
import 'views/videos_view.dart';

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
import 'views/welcome_view.dart';
import 'views/plans_view.dart';

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
          '/plans': (ctx) => const PlansView(),
        },
        home: Consumer<TrialController>(
          builder: (context, trial, _) {
            if (trial.loading) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            return FutureBuilder<bool>(
              future: SharedPreferences.getInstance().then(
                (p) => p.getBool('is_first_run') ?? true,
              ),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SplashView(); // Evitar pantalla negra
                }
                // Prioridad: 1. Activación (Código)
                if (!trial.activated) return const ActivationView();

                // 2. Bienvenida (Solo primera vez, tras activar)
                if (snapshot.data == true) {
                  return const WelcomeView();
                }

                // 3. Flujo normal
                if (trial.expired) return const TrialExpiredView();
                return const SplashView(); // Splash normal para siguientes inicios
              },
            );
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
      // Clamp index to available pages in case it was out of range
      final maxIndex = 3; // Home, Favorites, Playlists, Assistant
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
      const VideosView(),
    ];

    final screenWidth = MediaQuery.of(context).size.width;
    final drawerWidth = screenWidth * 0.75;

    // Definicón de nombres de tema para la UI
    final themeNames = <String, String>{
      'default': 'Clásico',
      'dark': 'Oscuro',
      'red_black': 'Rojo & Negro',
      'blue_light': 'Azul',
      'deep_space': 'Espacio',
      'sunset': 'Atardecer',
      'ocean': 'Océano',
      'forest_green': 'Bosque',
      'minimal_gray': 'Minimal',
      'rose_gold': 'Rosa',
      'lavender_dream': 'Lavanda',
      'mint_fresh': 'Menta',
      'peach_blossom': 'Durazno',
    };

    return Stack(
      children: [
        // 1. MAIN CONTENT (Scales down when drawer opens)
        AnimatedBuilder(
          animation: _drawerCtrl,
          builder: (context, child) {
            final scale = 1.0 - (_drawerCtrl.value * 0.1); // 1.0 -> 0.9
            final borderRadius = _drawerCtrl.value * 24.0;
            return Transform(
              transform: Matrix4.identity()..scale(scale),
              alignment: Alignment.centerRight, // Scale towards right
              child: ClipRRect(
                borderRadius: BorderRadius.circular(borderRadius),
                child: child,
              ),
            );
          },
          child: Scaffold(
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
              actions: [
                IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: 'Buscar',
                  onPressed: () async {
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
                BottomNavigationBarItem(icon: Icon(Icons.tv), label: 'Videos'),
              ],
            ),
          ),
        ),

        // 2. BACKDROP (Darkens when drawer opens)
        if (_drawerOpen)
          Positioned.fill(
            child: GestureDetector(
              onTap: _toggleDrawer,
              child: FadeTransition(
                opacity: _drawerCtrl,
                child: Container(color: Colors.black45),
              ),
            ),
          ),

        // 3. DRAWER PANEL (Slides in from left)
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
                    curve: Curves.easeOutQuint, // Smoother curve
                  ),
                );
            return FractionalTranslation(
              translation: slide.value,
              child: child,
            );
          },
          child: SizedBox(
            width: drawerWidth,
            height: double.infinity,
            child: Material(
              elevation: 16,
              color: Theme.of(context).scaffoldBackgroundColor,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- HEADER ---
                    Container(
                      padding: const EdgeInsets.fromLTRB(28, 40, 28, 30),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withOpacity(0.5),
                                width: 2,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 28,
                              backgroundImage: const AssetImage(
                                'assets/menu_logo.png',
                              ),
                              backgroundColor: Colors.transparent,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Primek Music',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Premium',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onPrimaryContainer,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // --- PLANES ---
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Theme.of(context).colorScheme.primary,
                                      Theme.of(context).colorScheme.secondary,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary.withOpacity(0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(16),
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white24,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.star_rounded,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                  title: const Text(
                                    'Mejorar a Premium',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  subtitle: const Text(
                                    'Desbloquea todo',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  trailing: const Icon(
                                    Icons.arrow_forward,
                                    color: Colors.white,
                                  ),
                                  onTap: () {
                                    _toggleDrawer();
                                    Navigator.pushNamed(context, '/plans');
                                  },
                                ),
                              ),
                            ),

                            const SizedBox(height: 30),

                            // --- TEMAS (New Horizontal Design) ---
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 28,
                                vertical: 8,
                              ),
                              child: Text(
                                'PERSONALIZACIÓN',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5,
                                    ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 90,
                              child: Consumer<ThemeController>(
                                builder: (context, themeCtrl, _) {
                                  final activeKey = themeCtrl.currentKey;
                                  final keys = themeCtrl.availableKeys;

                                  return ListView.builder(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                    ),
                                    scrollDirection: Axis.horizontal,
                                    itemCount: keys.length,
                                    itemBuilder: (context, index) {
                                      final key = keys[index];
                                      final isActive = activeKey == key;
                                      final color = themeCtrl.getThemeColor(
                                        key,
                                      );
                                      final name = themeNames[key] ?? key;

                                      return GestureDetector(
                                        onTap: () => themeCtrl.setTheme(key),
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            right: 16,
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              AnimatedContainer(
                                                duration: const Duration(
                                                  milliseconds: 300,
                                                ),
                                                width: isActive ? 56 : 48,
                                                height: isActive ? 56 : 48,
                                                padding: const EdgeInsets.all(
                                                  3,
                                                ),
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  border: isActive
                                                      ? Border.all(
                                                          color: Theme.of(
                                                            context,
                                                          ).colorScheme.primary,
                                                          width: 2,
                                                        )
                                                      : null,
                                                  boxShadow: [
                                                    if (isActive)
                                                      BoxShadow(
                                                        color: color
                                                            .withOpacity(0.4),
                                                        blurRadius: 10,
                                                        spreadRadius: 1,
                                                      ),
                                                  ],
                                                ),
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color: color,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: isActive
                                                      ? const Icon(
                                                          Icons.check,
                                                          color: Colors.white,
                                                          size: 20,
                                                        )
                                                      : null,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                name,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: isActive
                                                      ? FontWeight.bold
                                                      : FontWeight.w500,
                                                  color: isActive
                                                      ? Theme.of(
                                                          context,
                                                        ).colorScheme.primary
                                                      : Theme.of(context)
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),

                            const SizedBox(height: 30),
                            const Divider(indent: 28, endIndent: 28),
                            const SizedBox(height: 20),

                            // --- OTROS MENU ITEMS ---
                            _drawerItem(
                              context: context,
                              icon: Icons.notifications_none_rounded,
                              title: 'Notificaciones',
                              onTap: () {
                                _toggleDrawer();
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
                            _drawerItem(
                              context: context,
                              icon: Icons.info_outline_rounded,
                              title: 'Acerca de',
                              onTap: () {
                                _toggleDrawer();
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
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx),
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
                            const SizedBox(height: 100), // Bottom padding
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _drawerItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 4),
      leading: Icon(
        icon,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
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
