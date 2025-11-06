# Convenciones MVC (estructura creada)

He creado una estructura mínima para aplicar MVC y escalar la app:

- lib/models/: modelos de datos (ej. `song.dart`, `base_model.dart`)
- lib/views/: pantallas y widgets relacionados a la UI (ej. `home_view.dart`)
- lib/controllers/: lógica por pantalla / controladores (ej. `home_controller.dart`)
- lib/services/: servicios para infraestructura (audio, red, etc.)
- lib/repositories/: acceso a datos (DB, API)
- lib/widgets/: widgets reutilizables y componentes UI
- lib/routes/: rutas y constantes de navegación
- lib/utils/: utilidades varias

Cómo usarlo (ejemplo sencillo):

En `main.dart` puedes instanciar un `HomeController` y pasarlo a `HomeView`:

```dart
// dentro de `main.dart`
import 'package:flutter/material.dart';
import 'views/home_view.dart';
import 'controllers/home_controller.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final homeController = HomeController();
    return MaterialApp(
      title: 'Reproductor',
      home: HomeView(controller: homeController),
    );
  }
}
```

Notas y siguientes pasos sugeridos:
- Implementar controllers como `ChangeNotifier` o usar `Provider` / `Riverpod` para gestión de estado si lo necesitas.
- Mover la lógica de negocio a `controllers` y acceso a datos a `repositories`.
- Añadir tests unitarios para modelos y controladores.

Si quieres, puedo actualizar `lib/main.dart` para utilizar la nueva `HomeView` y añadir un ejemplo de inyección simple. ¿Lo hago ahora?

## Rendimiento y optimizaciones (recomendado)

Pequeñas mejoras y prácticas para mantener la app rápida y fluida:

- Usar un gestor de estado eficiente — ya añadimos `Provider` y `ChangeNotifier` para `HomeController`.
- Evitar llamadas heavy en `build()`; mover IO/CPU a `initState`, `Future`s o `Isolates`.
- Mantener widgets inmutables y usar `const` siempre que sea posible (reduce trabajo del framework).
- Mantener vistas en `IndexedStack` si quieres preservar estado entre pestañas (ya implementado).
- Cargar datos de forma lazy (paginación) y solo cuando la vista los necesita.
- Cachear recursos (imágenes, metadata) y usar `precacheImage` para evitar saltos.
- Usar `ListView.builder` (ya usado) para listas largas y `const` en sus children cuando aplique.
- Delegar trabajo costoso a Isolates o al backend (procesamiento de audio, análisis de archivos grandes).
- Medir con Flutter DevTools (timeline, performance overlay, raster cache) y corregir hotspots.

Siguientes pasos sugeridos (puedo hacerlo por ti):

1. Convertir `HomeController` en `ChangeNotifier` y usar `Provider` (ya hecho).
2. Implementar favoritos persistentes y listas usando un repositorio con `hive`/`sqflite` o similar.
3. Añadir tests de rendimiento básicos y script de profiling con DevTools.
4. Revisar y optimizar cualquier operación que ejecute en el `build()`.

Dime cuál de estos pasos quieres que implemente ahora y lo hago: 1) persistencia de favoritos, 2) integración de Provider más profunda con `ChangeNotifier` (ej.: favoritos), 3) añadir profiling scripts / instrucciones para medir.

## Reproducción de IPTV con VLC

He añadido soporte para usar libVLC a través del paquete `flutter_vlc_player` y un servicio `VideoService` en `lib/services/video_service.dart` junto con una vista de ejemplo `lib/views/iptv_player_view.dart`.

Notas importantes:
- ¿Esto es gratis? El uso del paquete es gratuito y open-source. Sin embargo, libVLC (VLC) está bajo licencia LGPL. Puedes usarlo libremente en aplicaciones, pero debes cumplir los términos de la LGPL (por ejemplo, si modificas las bibliotecas de VLC debes publicar esos cambios, y debes permitir la relinkability según los términos). Para la mayoría de apps que no modifican libVLC, no hay coste, sólo cumplimiento de licencia.
- Requisitos de plataforma: `flutter_vlc_player` añade binarios nativos; revisa la documentación del paquete para cambios en Gradle/Podfile y permisos. En Android asegúrate de tener `minSdk` compatible; en iOS puede requerir configuraciones adicionales.
- Testing: prueba varios streams (HLS, RTMP, UDP) ya que cada plataforma maneja codecs y protocolos de forma distinta.

Si quieres, continúo con:
- A) Integrar `VideoService` como un servicio inyectable vía Provider y un `IptvController` para gestionar listas y favoritos.
- B) Implementar parseo M3U en `repositories/iptv_repository.dart` y un ejemplo de UI para seleccionar canales y reproducir.
