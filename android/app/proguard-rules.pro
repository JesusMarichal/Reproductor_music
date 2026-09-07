# Reglas de R8 para la app.
#
# Sólo se conservan las de librerías que la app usa hoy. Las de YouTube
# Player, WebView, okhttp, libVLC y ExoPlayer2 se eliminaron junto con el
# módulo de vídeo: mantener -keep de clases inexistentes no da error, pero
# oculta qué se está protegiendo de verdad.

# --- Flutter ---
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }
# Los plugins se registran por código generado, pero algunos resuelven
# handlers por reflexión desde el canal de plataforma.
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.engine.plugins.** { *; }

# Métodos nativos: el nombre no puede cambiar o falla el enlace JNI.
-keepclasseswithmembernames class * {
    native <methods>;
}

# --- Reproducción de audio ---
# just_audio y audio_service instancian clases por nombre; sin estos keep,
# R8 las elimina y la reproducción falla en release.
-keep class com.ryanheise.audioservice.** { *; }
-dontwarn com.ryanheise.audioservice.**
-keep class com.ryanheise.just_audio.** { *; }
-dontwarn com.ryanheise.just_audio.**
-keep class com.ryanheise.audio_session.** { *; }
-dontwarn com.ryanheise.audio_session.**

# Media3 es el motor de reproducción que usa just_audio.
-keep class androidx.media3.** { *; }
-dontwarn androidx.media3.**
-keep class com.google.common.util.concurrent.ListenableFuture

# --- on_audio_query ---
# El plugin guarda el MethodCall/Result pendientes en WeakReference dentro de
# su PluginProvider. Si R8 optimiza estas clases, el Result queda accesible
# antes de tiempo, el recolector se lo lleva mientras el diálogo de permisos
# está abierto y al volver la app revienta con
# "Tried to get one of the methods but the 'PluginProvider' has not
# initialized". Conservarlas intactas evita esa carrera.
-keep class com.lucasjosino.on_audio_query.** { *; }
-keepclassmembers class com.lucasjosino.on_audio_query.** { *; }
-dontwarn com.lucasjosino.on_audio_query.**

# --- Play Core ---
# Flutter referencia estas clases para componentes diferidos, que esta app no
# usa. Sin los -dontwarn, R8 falla al no encontrarlas.
-dontwarn com.google.android.play.core.**

# --- Kotlin ---
-keepclassmembers class kotlin.coroutines.** { *; }
-dontwarn kotlin.coroutines.**

# Quitar el log de depuración del binario de release.
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}
