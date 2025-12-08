import 'package:flutter/material.dart';

class NowPlayingIndicator extends StatefulWidget {
  final bool isPlaying;
  final Color? color;
  final double barWidth;
  final double maxHeight;
  final double minHeight;

  const NowPlayingIndicator({
    super.key,
    required this.isPlaying,
    this.color,
    this.barWidth = 4.0,
    this.maxHeight = 16.0,
    this.minHeight = 4.0,
  });

  @override
  State<NowPlayingIndicator> createState() => _NowPlayingIndicatorState();
}

class _NowPlayingIndicatorState extends State<NowPlayingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

    if (widget.isPlaying) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(NowPlayingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
        _controller.animateTo(0.2, duration: const Duration(milliseconds: 200));
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.color ?? Theme.of(context).colorScheme.primary;

    return SizedBox(
      width: widget.barWidth * 3 + 8, // 3 bars + 2 gaps of 4px
      height: widget.maxHeight,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, _) {
          final t = _animation.value;

          // Generate 3 different heights based on t to simulate equalizer
          // Bar 1: standard sine wave
          final h1 = _lerp(widget.minHeight, widget.maxHeight, t);

          // Bar 2: offset phase
          final h2 = _lerp(widget.minHeight, widget.maxHeight, (t + 0.5) % 1.0);

          // Bar 3: faster or different phase
          final h3 = _lerp(widget.minHeight, widget.maxHeight, (1.0 - t));

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildBar(h1, activeColor),
              _buildBar(h2, activeColor.withOpacity(0.85)),
              _buildBar(h3, activeColor.withOpacity(0.7)),
            ],
          );
        },
      ),
    );
  }

  double _lerp(double min, double max, double t) {
    return min + (max - min) * t;
  }

  Widget _buildBar(double height, Color color) {
    return Container(
      width: widget.barWidth,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(widget.barWidth / 2),
      ),
    );
  }
}
