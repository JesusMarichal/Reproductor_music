package com.example.reproductor_music

import com.ryanheise.audioservice.AudioServiceActivity

// Extiende AudioServiceActivity para que audio_service comparta correctamente
// el FlutterEngine entre la Activity y el servicio en segundo plano.
class MainActivity : AudioServiceActivity()
