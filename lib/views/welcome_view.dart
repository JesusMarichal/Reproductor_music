import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../main.dart';

class WelcomeView extends StatefulWidget {
  const WelcomeView({super.key});

  @override
  State<WelcomeView> createState() => _WelcomeViewState();
}

class _WelcomeViewState extends State<WelcomeView> {
  // Secuencia de textos
  final List<String> _texts = [
    'Hola',
    'Preparando tu música',
    'Organizando biblioteca',
    'Todo casi listo',
    'Bienvenido a Primek Music',
  ];

  int _currentIndex = 0;
  double _opacity = 0.0;

  @override
  void initState() {
    super.initState();
    _initWelcome();
  }

  Future<void> _initWelcome() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_name') ?? '';
    // Si tenemos nombre, actualizamos el primer mensaje
    if (name.isNotEmpty) {
      // Capitalizar primera letra por elegancia
      final capitalized = name.length > 1
          ? '${name[0].toUpperCase()}${name.substring(1)}'
          : name.toUpperCase();
      _texts[0] = 'Hola, $capitalized';
    }
    _startSequence();
  }

  Future<void> _startSequence() async {
    // 1. Pequeña pausa inicial
    await Future.delayed(const Duration(milliseconds: 500));

    // 2. Loop de textos
    for (int i = 0; i < _texts.length; i++) {
      if (!mounted) return;

      setState(() {
        _currentIndex = i;
        _opacity = 1.0; // Fade In
      });

      // Acción especial durante "Preparando tu música"
      if (i == 1) {
        // Solicitamos permisos básicos si no los tiene (storage/audio)
        await _askPermissions();
      }

      // Tiempo de lectura (más largo para el último)
      final waitTime = (i == _texts.length - 1) ? 2500 : 2000;
      await Future.delayed(Duration(milliseconds: waitTime));

      if (!mounted) return;

      // Si no es el último, hacemos fade out
      if (i < _texts.length - 1) {
        setState(() {
          _opacity = 0.0; // Fade Out
        });
        await Future.delayed(
          const Duration(milliseconds: 600),
        ); // Tiempo de fade out
      }
    }

    _finishWelcome();
  }

  Future<void> _askPermissions() async {
    // Pedimos audio/storage según versión android
    // Esto puede pausar la UI visualmente si sale el popup del sistema,
    // pero el usuario sentirá que es parte del proceso de "preparación".
    if (await Permission.audio.status.isDenied) {
      await Permission.audio.request();
    }
    if (await Permission.storage.status.isDenied) {
      await Permission.storage.request();
    }
  }

  Future<void> _finishWelcome() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_first_run', false);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const ReproductorHome(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 1000),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Fondo sólido elegante (inspirado en Windows OOBE azul oscuro o negro)
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: AnimatedOpacity(
          opacity: _opacity,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _texts[_currentIndex],
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily:
                      'Segoe UI', // Intento de font estilo Windows (si disponible) o default
                  fontSize: 24,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),

              // Spinner estilo Windows (puntos) solo si no es el mensaje final
              // Spinner removido por solicitud
            ],
          ),
        ),
      ),
    );
  }
}
