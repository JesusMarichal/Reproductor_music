# Reproductor_music

Proyecto Flutter de ejemplo creado en la carpeta raíz `Reproductor_music`.

Este repositorio contiene una aplicación Flutter mínima (interfaz de reproductor) en `lib/main.dart`.

---

## Requisitos previos

- Tener instalado Flutter (versión 3.x o superior). Verifica con:

```powershell
flutter --version
```

- Tener las herramientas necesarias según la plataforma donde quieras ejecutar:
  - Para web: Chrome o Edge.
  - Para Windows (desktop): Visual Studio con "Desktop development with C++".
  - Para Android: Android SDK y aceptar licencias.

Si falten licencias de Android, ejecuta:

```powershell
flutter doctor --android-licenses
```

Comprueba el estado general con:

```powershell
flutter doctor -v
```

---

## Estructura relevante

- `lib/main.dart` — punto de entrada con un ejemplo sencillo de UI (botón Play/Pause).
- `pubspec.yaml` — dependencias y configuración del package (`reproductor_music`).

---

## Pasos para ejecutar la app (Windows / Chrome / Android)

1. Abrir PowerShell y situarse en la carpeta del proyecto:

```powershell
Set-Location -Path 'C:\Users\maric\Reproductor_music'
```

2. Obtener dependencias (opcional, `flutter create` ya las resolvió, pero es buena práctica):

```powershell
flutter pub get
```

3. Ejecutar en el target deseado:

- Ejecutar en Windows (desktop):

```powershell
flutter run -d windows
```

- Ejecutar en Chrome (web):

```powershell
flutter run -d chrome
```

- Ejecutar en un dispositivo Android conectado o emulador:

```powershell
flutter run
```

4. Problemas comunes:

- Si `flutter doctor` indica que faltan licencias Android, ejecuta `flutter doctor --android-licenses` y responde `y` a los prompts.
- Si quieres compilar para Windows y `flutter doctor` reclama Visual Studio, instala Visual Studio (no VS Code) con la workload "Desktop development with C++".

---

## Abrir el proyecto en VS Code

Desde PowerShell puedes abrir el proyecto en VS Code con:

```powershell
Set-Location -Path 'C:\Users\maric\Reproductor_music'; code .
```

Instala la extensión Flutter en VS Code para soporte de depuración y hot reload.

---

## Notas adicionales

- El nombre del package del proyecto es `reproductor_music` (requerido por Dart para nombres válidos).
- El ejemplo en `lib/main.dart` es un placeholder — no reproduce audio real. Si quieres soporte de audio real, puedo añadir dependencias como `just_audio` y configurar la reproducción.

---

Si quieres, puedo:

- Añadir instrucciones para crear un emulador Android en Android Studio.
- Añadir reproducción de audio real con un paquete y ejemplo.
- Configurar integración con Git (crear .gitignore adicional, etc.).

Dime qué prefieres y lo agrego.
# Reproductor_music
Desarrollo de App Para Escuchar Musica.
