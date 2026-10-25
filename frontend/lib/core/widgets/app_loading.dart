import 'dart:math' as math;

import 'package:flutter/material.dart';

class AppLoading extends StatefulWidget {
  const AppLoading({this.compact = false, this.color, super.key});

  final bool compact;
  final Color? color;

  @override
  State<AppLoading> createState() => _AppLoadingState();
}

class _AppLoadingState extends State<AppLoading> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bike = Semantics(
      label: 'Cargando información',
      liveRegion: true,
      child: SizedBox(
        width: widget.compact ? 22 : 82,
        height: widget.compact ? 22 : 58,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (!widget.compact)
              Positioned(
                left: 8,
                right: 8,
                bottom: 7,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final phase = _controller.value * math.pi * 2;
                final travel = widget.compact ? 1.5 : 10.0;
                return Transform.translate(
                  offset: Offset(
                    (_controller.value * 2 - 1) * travel,
                    widget.compact ? 0 : math.sin(phase) * 2,
                  ),
                  child: Transform.rotate(
                    angle: math.sin(phase) * (widget.compact ? 0.04 : 0.07),
                    child: child,
                  ),
                );
              },
              child: Icon(
                Icons.two_wheeler_rounded,
                size: widget.compact ? 18 : 42,
                color: widget.color ?? colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.compact) return bike;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          bike,
          const SizedBox(height: 8),
          Text(
            'Cargando información',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
