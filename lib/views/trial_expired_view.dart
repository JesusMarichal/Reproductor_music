import 'package:flutter/material.dart';

class TrialExpiredView extends StatelessWidget {
  const TrialExpiredView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_clock, size: 96, color: Colors.redAccent),
              const SizedBox(height: 24),
              const Text(
                '¡Ups! Se acabó el tiempo de Prueba',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Esta versión de prueba ha expirado tras 2 días de uso. Muchas gracias por probar la app.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: () {
                  // Placeholder: se podría abrir un enlace de compra o página informativa.
                  Navigator.of(context).maybePop();
                },
                child: const Text('Cerrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
