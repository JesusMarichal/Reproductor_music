import 'package:flutter/material.dart';
import 'dart:math';

class MusicLoader extends StatefulWidget {
  const MusicLoader({super.key});

  @override
  State<MusicLoader> createState() => _MusicLoaderState();
}

class _MusicLoaderState extends State<MusicLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final value = sin((_controller.value * 2 * pi) + (i * pi / 3));
            final height = (value.abs() * 30) + 10;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Container(
                width: 6,
                height: height,
                decoration: BoxDecoration(
                  color: Colors.deepPurpleAccent,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
