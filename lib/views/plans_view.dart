import 'package:flutter/material.dart';

class PlansView extends StatelessWidget {
  const PlansView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, size: 20, color: textColor),
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                // Fallback: Si no hay historial, ir a Home
                Navigator.pushReplacementNamed(context, '/');
              }
            },
            tooltip: 'Volver',
          ),
        ),
        title: Text(
          'Planes Premium',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.primaryContainer.withOpacity(0.3),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
                Text(
                  'Desbloquea el Máximo Potencial',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Elige tu plan y accede a audio de alta definición y temas exclusivos sin límites.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),

                // PLAN MENSUAL
                _PlanCard(
                  title: 'Mensual',
                  price: '\$1.50',
                  period: '/mes',
                  features: const [
                    'Experiencia Sin Límites 🌐',
                    'Audio Hi-Fi (Lossless) 🎧',
                    'Nuevos Temas y Diseños 🎨',
                    'Sin Anuncios 🚫',
                  ],
                  color: Colors.blueAccent,
                  isPopular: true,
                ),
                const SizedBox(height: 20),

                // PLAN ANUAL
                _PlanCard(
                  title: 'Anual',
                  price: '\$15.00',
                  period: '/año',
                  features: const [
                    '2 Meses GRATIS 🎁',
                    'Audio Ultra HD 4K 🔊',
                    'Prioridad en Soporte ⚡',
                    'Todos los beneficios mensuales ✨',
                  ],
                  color: Colors.purpleAccent,
                  badgeText: 'AHORRA 17%',
                ),
                const SizedBox(height: 20),

                // PLAN VITALICIO
                _PlanCard(
                  title: 'Vitalicio',
                  price: '\$35.00',
                  period: 'pago único',
                  features: const [
                    'Acceso de por VIDA ♾️',
                    'Modo Cine (Sin límites) 🎬',
                    'Diseños "Founder" Exclusivos 💎',
                    'Insignia de Perfil Gold 🌟',
                  ],
                  color: Colors.orangeAccent,
                  isPremium: true,
                  badgeText: 'MEJOR VALOR',
                ),

                const SizedBox(height: 30),
                Center(
                  child: TextButton(
                    onPressed: () {},
                    child: const Text('Restaurar Compras'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final String period;
  final List<String> features;
  final Color color;
  final bool isPopular;
  final bool isPremium;
  final String? badgeText;

  const _PlanCard({
    required this.title,
    required this.price,
    required this.period,
    required this.features,
    required this.color,
    this.isPopular = false,
    this.isPremium = false,
    this.badgeText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(24),
            border: isPopular || isPremium
                ? Border.all(color: color, width: 2)
                : Border.all(color: theme.dividerColor.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 1.2,
                    ),
                  ),
                  if (isPremium) Icon(Icons.star, color: color, size: 20),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    price,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    period,
                    style: TextStyle(
                      fontSize: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ...features.map(
                (f) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_rounded, size: 20, color: color),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          f,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Plan $title seleccionado. Procesando...',
                        ),
                        backgroundColor: color,
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: color,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Obtener Plan',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (isPopular || badgeText != null)
          Positioned(
            top: -12,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: color.withOpacity(0.4), blurRadius: 8),
                ],
              ),
              child: Text(
                badgeText ?? 'POPULAR',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
