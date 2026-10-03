import 'dart:math' as math;
import 'package:flutter/material.dart';

enum RioAvatarState { idle, listening, working, success, error }

class RioAvatarWidget extends StatefulWidget {
  final RioAvatarState state;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;
  final double size;

  const RioAvatarWidget({
    super.key,
    required this.state,
    required this.onTap,
    this.onDoubleTap,
    this.size = 56.0,
  });

  @override
  State<RioAvatarWidget> createState() => _RioAvatarWidgetState();
}

class _RioAvatarWidgetState extends State<RioAvatarWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTap: widget.onDoubleTap,
      child: AnimatedBuilder(
        animation: _animController,
        builder: (context, child) {
          return CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _GptDotsPainter(
              animationValue: _animController.value,
              state: widget.state,
            ),
          );
        },
      ),
    );
  }
}

class _DotData {
  final double x;
  final double y;
  final double radius;
  final Color color;

  _DotData({
    required this.x,
    required this.y,
    required this.radius,
    required this.color,
  });
}

class _GptDotsPainter extends CustomPainter {
  final double animationValue;
  final RioAvatarState state;

  _GptDotsPainter({
    required this.animationValue,
    required this.state,
  });

  static const List<Color> _gptColors = [
    Color(0xFFFFFFFF), // White luminous
    Color(0xFF38BDF8), // Electric Sky Blue
    Color(0xFFA855F7), // Neon Violet
    Color(0xFFF43F5E), // Vivid Coral
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final baseRadius = size.width / 2;
    final time = animationValue * 2 * math.pi;

    // 1. Ambient Background Glow Aura
    final auraPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          _getAuraColor(state).withOpacity(0.35),
          _getAuraColor(state).withOpacity(0.10),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: baseRadius * 1.1));
    canvas.drawCircle(Offset(cx, cy), baseRadius * 1.1, auraPaint);

    // 2. Compute 4 Fluid Dots Positions based on state
    final dots = <_DotData>[];
    const numDots = 4;

    for (int i = 0; i < numDots; i++) {
      double x, y, dotRadius;
      final baseAngle = (i * (2 * math.pi) / numDots);

      switch (state) {
        case RioAvatarState.idle:
          // Soft circular breathing orbit with gentle sine wave undulation
          final orbitRadius = baseRadius * 0.44 + math.sin(time * 2 + i) * (baseRadius * 0.04);
          final currentAngle = baseAngle + time * 0.8;
          x = cx + math.cos(currentAngle) * orbitRadius;
          y = cy + math.sin(currentAngle) * orbitRadius;
          dotRadius = baseRadius * 0.22 + math.sin(time * 3 + i * 2) * (baseRadius * 0.03);
          break;

        case RioAvatarState.listening:
          // Elastic acoustic frequency waves
          final spread = baseRadius * 0.42;
          final targetX = cx + (i - 1.5) * spread;
          final waveHeight = (math.sin(time * 6 + i * 1.5).abs() * 0.55 + 0.20) * baseRadius;
          x = targetX;
          y = cy + math.sin(time * 4 + i) * (baseRadius * 0.08);
          dotRadius = waveHeight * 0.45;
          break;

        case RioAvatarState.working:
          // Rapid orbital swirl vortex
          final orbitRadius = baseRadius * 0.48 + math.sin(time * 4) * (baseRadius * 0.08);
          final currentAngle = baseAngle + time * 3.5;
          x = cx + math.cos(currentAngle) * orbitRadius;
          y = cy + math.sin(currentAngle) * orbitRadius;
          dotRadius = baseRadius * 0.18 + math.cos(time * 6 + i) * (baseRadius * 0.04);
          break;

        case RioAvatarState.success:
          // Harmonic bloom & breath
          final bloom = math.sin(time * 4) * (baseRadius * 0.12);
          final orbitRadius = baseRadius * 0.48 + bloom;
          final currentAngle = baseAngle + time * 1.2;
          x = cx + math.cos(currentAngle) * orbitRadius;
          y = cy + math.sin(currentAngle) * orbitRadius;
          dotRadius = baseRadius * 0.26 + math.sin(time * 4 + i) * (baseRadius * 0.04);
          break;

        case RioAvatarState.error:
          // Mild warning vibration
          final shake = math.sin(time * 12 + i) * 2;
          x = cx + math.cos(baseAngle) * (baseRadius * 0.38) + shake;
          y = cy + math.sin(baseAngle) * (baseRadius * 0.38);
          dotRadius = baseRadius * 0.18;
          break;
      }

      dots.add(_DotData(
        x: x,
        y: y,
        radius: dotRadius,
        color: state == RioAvatarState.error ? const Color(0xFFEF4444) : _gptColors[i],
      ));
    }

    // 3. Draw Fluid Connective Bridges (Metaball effect)
    for (int i = 0; i < dots.length; i++) {
      for (int j = i + 1; j < dots.length; j++) {
        final d1 = dots[i];
        final d2 = dots[j];
        final dist = math.sqrt(math.pow(d2.x - d1.x, 2) + math.pow(d2.y - d1.y, 2));
        final maxConnectDist = baseRadius * 1.35;

        if (dist < maxConnectDist) {
          final opacity = ((maxConnectDist - dist) / maxConnectDist).clamp(0.0, 1.0) * 0.42;
          final bridgePaint = Paint()
            ..color = const Color(0xFF93C5FD).withOpacity(opacity)
            ..strokeWidth = math.min(d1.radius, d2.radius) * 1.1
            ..strokeCap = StrokeCap.round;
          canvas.drawLine(Offset(d1.x, d1.y), Offset(d2.x, d2.y), bridgePaint);
        }
      }
    }

    // 4. Draw Radiant Glowing Dots
    for (final d in dots) {
      // Outer Soft Glow
      final glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            d.color.withOpacity(0.65),
            d.color.withOpacity(0.20),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: Offset(d.x, d.y), radius: d.radius * 2.2));
      canvas.drawCircle(Offset(d.x, d.y), d.radius * 2.2, glowPaint);

      // Core Luminous Solid Dot
      final corePaint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.3),
          colors: [
            Colors.white,
            d.color,
            d.color.withOpacity(0.85),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(d.x, d.y), radius: d.radius));
      canvas.drawCircle(Offset(d.x, d.y), d.radius, corePaint);
    }
  }

  Color _getAuraColor(RioAvatarState st) {
    switch (st) {
      case RioAvatarState.idle:
        return const Color(0xFF6366F1); // Indigo
      case RioAvatarState.listening:
        return const Color(0xFF06B6D4); // Cyan
      case RioAvatarState.working:
        return const Color(0xFFF59E0B); // Amber
      case RioAvatarState.success:
        return const Color(0xFF10B981); // Emerald
      case RioAvatarState.error:
        return const Color(0xFFEF4444); // Red
    }
  }

  @override
  bool shouldRepaint(covariant _GptDotsPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.state != state;
  }
}
