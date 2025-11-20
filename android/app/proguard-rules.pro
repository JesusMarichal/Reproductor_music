# ProGuard rules for Flutter app
# Keep Flutter engine and plugin registration
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }

# Keep model classes used via reflection or serialization (adjust as needed)
#-keep class com.example.reproductor_music.models.** { *; }

# If using Gson/other reflection-based JSON libs, keep model fields or add rules per library.

# Keep entry points for native callbacks
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Keep native method names (if using platform channels with named methods)
-keepclasseswithmembernames class * {
    native <methods>;
}

# Add additional -keep rules for any library that requires them (check runtime crashes / docs)

# Remove logging from release
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}
