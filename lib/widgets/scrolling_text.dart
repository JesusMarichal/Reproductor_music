import 'package:flutter/material.dart';

class ScrollingText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final double velocity; // pixels per second
  final Duration pauseDuration;

  const ScrollingText({
    super.key,
    required this.text,
    this.style,
    this.velocity = 30.0,
    this.pauseDuration = const Duration(seconds: 2),
  });

  @override
  State<ScrollingText> createState() => _ScrollingTextState();
}

class _ScrollingTextState extends State<ScrollingText>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _animationController = AnimationController(vsync: this);

    // Start scrolling after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startScrolling();
    });
  }

  @override
  void didUpdateWidget(ScrollingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text) {
      _stopScrolling(); // Reset
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startScrolling();
      });
    }
  }

  void _stopScrolling() {
    _animationController.stop();
    _animationController.reset();
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0.0);
    }
  }

  void _startScrolling() {
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return; // No need to scroll

    final durationSeconds = maxScroll / widget.velocity;
    _animationController.duration = Duration(
      milliseconds: (durationSeconds * 1000).toInt(),
    );

    _animation =
        Tween<double>(begin: 0.0, end: maxScroll).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.linear),
        )..addListener(() {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(_animation.value);
          }
        });

    _runAnimationLoop();
  }

  Future<void> _runAnimationLoop() async {
    while (mounted) {
      if (!_scrollController.hasClients ||
          _scrollController.position.maxScrollExtent <= 0)
        break;

      // Pause at start
      await Future.delayed(widget.pauseDuration);
      if (!mounted) break;

      // Scroll to end
      try {
        await _animationController.forward(from: 0.0);
      } catch (_) {
        break;
      } // Handle dispose

      if (!mounted) break;

      // Pause at end
      await Future.delayed(widget.pauseDuration);
      if (!mounted) break;

      // Jump back to start
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0.0);
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Text(widget.text, style: widget.style, maxLines: 1),
    );
  }
}
