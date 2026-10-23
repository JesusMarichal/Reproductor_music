import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'controllers/home_controller.dart';
import 'controllers/playlist_controller.dart';
import 'controllers/profile_controller.dart';
import 'controllers/theme_controller.dart';
import 'services/audio_service.dart';
import 'theme/app_theme.dart';
import 'views/favorites_view.dart';
import 'views/home_view.dart';
import 'views/playlists_view.dart';
import 'views/profile_view.dart';
import 'views/search_view.dart';
import 'views/splash_view.dart';
import 'views/spotify_discovery_view.dart';
import 'widgets/app_nav_bar.dart';
import 'widgets/mini_player.dart';
import 'widgets/profile_avatar.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Solicita notificaciones antes de la primera pantalla (Android 13+).
  await _ensureNotificationPermission();

  final prefs = await SharedPreferences.getInstance();
  final savedTheme = prefs.getString('theme_key');

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeController(initialKey: savedTheme),
      child: const KissMusicApp(),
    ),
  );

  // El servicio de notificaciones se inicializa después de `runApp` para no
  // bloquear el primer frame. Si falla, la app sigue funcionando sin
  // controles en la barra de notificaciones.
  AudioService.initForNotifications().catchError((Object e) {
    debugPrint('AudioService.initForNotifications error: $e');
  });
}

/// Solicita el permiso de notificaciones en Android 13+. En el resto de
/// plataformas la llamada es inocua.
Future<void> _ensureNotificationPermission() async {
  try {
    final status = await Permission.notification.status;
    if (status.isDenied || status.isRestricted) {
      await Permission.notification.request();
    }
  } catch (e) {
    debugPrint('Permiso de notificaciones no disponible: $e');
  }
}

class KissMusicApp extends StatelessWidget {
  const KissMusicApp({super.key});

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
        ChangeNotifierProvider(create: (_) => ProfileController()..load()),
      ],
      child: MaterialApp(
        title: 'Kiss Music',
        debugShowCheckedModeBanner: false,
        theme: theme,
        routes: {'/discovery': (_) => const SpotifyDiscoveryView()},
        home: const SplashView(),
      ),
    );
  }
}

/// Destinos de la app. El botón central de la barra no es un destino: abre el
/// perfil, desde donde se llega a los ajustes.
enum AppTab {
  songs(
    Icons.library_music_outlined,
    Icons.library_music,
    'Canciones',
    'Kiss Music',
  ),
  search(Icons.search_rounded, Icons.search_rounded, 'Buscar', 'Buscar'),
  playlists(
    Icons.queue_music_outlined,
    Icons.queue_music,
    'Listas',
    'Tus listas',
  ),
  favorites(Icons.favorite_border, Icons.favorite, 'Favoritos', 'Favoritos');

  const AppTab(this.icon, this.selectedIcon, this.label, this.title);

  final IconData icon;
  final IconData selectedIcon;

  /// Etiqueta de accesibilidad en la barra.
  final String label;

  /// Título mostrado en la barra superior.
  final String title;
}

/// Contenedor principal: barra superior, contenido, mini reproductor y barra
/// de navegación.
///
/// El mini reproductor vive aquí y no dentro de cada vista, de modo que sigue
/// visible al cambiar de pestaña y sólo existe una instancia.
class ReproductorHome extends StatefulWidget {
  const ReproductorHome({super.key});

  @override
  State<ReproductorHome> createState() => _ReproductorHomeState();
}

class _ReproductorHomeState extends State<ReproductorHome> {
  AppTab _tab = AppTab.songs;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_tab.title)),
      body: IndexedStack(
        index: _tab.index,
        children: const [
          HomeView(),
          SearchView(),
          PlaylistsView(),
          FavoritesView(),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: MiniPlayer(),
          ),
          AppNavBar(
            currentIndex: _tab.index,
            onSelected: (i) => setState(() => _tab = AppTab.values[i]),
            items: [
              for (final tab in AppTab.values)
                NavItem(
                  icon: tab.icon,
                  selectedIcon: tab.selectedIcon,
                  label: tab.label,
                ),
            ],
            centerTooltip: 'Tu perfil',
            // Mismo tamaño que el botón y sin aro: la foto llena el círculo.
            centerChild: const ProfileAvatar(size: 60),
            onCenterPressed: _openProfile,
          ),
        ],
      ),
    );
  }

  void _openProfile() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ProfileView()));
  }
}
