import 'package:flutter/material.dart';
import 'services/audio_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'controllers/theme_controller.dart';
import 'controllers/home_controller.dart';
import 'views/home_view.dart';
import 'controllers/playlist_controller.dart';
import 'views/favorites_view.dart';
import 'views/playlists_view.dart';
import 'views/settings_view.dart';
import 'views/splash_view.dart';
import 'controllers/trial_controller.dart';
import 'views/trial_expired_view.dart';
import 'views/activation_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Inicializa el servicio para notificaciones antes de levantar la UI.
  await AudioService.initForNotifications();
  await _ensureNotificationPermission();
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeController(),
      child: const MyApp(),
    ),
  );
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
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Primek Music',
        theme: theme,
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

class _ReproductorHomeState extends State<ReproductorHome> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _openSettings() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SettingsView()));
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const HomeView(),
      const FavoritesView(),
      const PlaylistsView(),
    ];

    return Scaffold(
      appBar: AppBar(
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
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
            tooltip: 'Configuración',
          ),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
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
