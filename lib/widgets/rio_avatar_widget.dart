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
      duration: const Duration(milliseconds: 2400),
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
            painter: _RioAvatarPainter(
              animationValue: _animController.value,
              state: widget.state,
            ),
          );
        },
      ),
    );
  }
}

class _RioAvatarPainter extends CustomPainter {
  final double animationValue;
  final RioAvatarState state;

  _RioAvatarPainter({
    required this.animationValue,
    required this.state,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    switch (state) {
      case RioAvatarState.idle:
        _drawIdleState(canvas, center, radius);
        break;
      case RioAvatarState.listening:
        _drawListeningState(canvas, center, radius);
        break;
      case RioAvatarState.working:
        _drawWorkingState(canvas, center, radius);
        break;
      case RioAvatarState.success:
        _drawSuccessState(canvas, center, radius);
        break;
      case RioAvatarState.error:
        _drawErrorState(canvas, center, radius);
        break;
    }
  }

  void _drawIdleState(Canvas canvas, Offset center, double radius) {
    // Ambient breathing pulse
    final pulse = math.sin(animationValue * 2 * math.pi) * 0.08 + 0.92;
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF6366F1).withOpacity(0.55),
          const Color(0xFF38BDF8).withOpacity(0.2),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.15));

    canvas.drawCircle(center, radius * 1.15 * pulse, glowPaint);

    // Inner Core
    final corePaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFF818CF8), Color(0xFF4F46E5), Color(0xFF1E1B4B)],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.75));
    canvas.drawCircle(center, radius * 0.75, corePaint);

    // Rotating orbital cyber ring
    final ringPaint = Paint()
      ..color = const Color(0xFF38BDF8).withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final startAngle = animationValue * 2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.82),
      startAngle,
      math.pi * 1.4,
      false,
      ringPaint,
    );

    // Rio Logo Core
    _drawRioGlyph(canvas, center, radius * 0.45, Colors.white);
  }

  void _drawListeningState(Canvas canvas, Offset center, double radius) {
    // Dynamic sound wave ripple rings
    final wave1 = (animationValue * 1.3) % 1.0;
    final wave2 = ((animationValue * 1.3) + 0.5) % 1.0;

    final wavePaint1 = Paint()
      ..color = const Color(0xFF06B6D4).withOpacity((1.0 - wave1) * 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final wavePaint2 = Paint()
      ..color = const Color(0xFF8B5CF6).withOpacity((1.0 - wave2) * 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(center, radius * (0.6 + wave1 * 0.4), wavePaint1);
    canvas.drawCircle(center, radius * (0.6 + wave2 * 0.4), wavePaint2);

    // Vibrant audio core
    final corePaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFF22D3EE), Color(0xFF6366F1), Color(0xFF0F172A)],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.65));
    canvas.drawCircle(center, radius * 0.65, corePaint);

    // Audio Waveform bars in the center
    final barPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final barOffsets = [-10.0, -5.0, 0.0, 5.0, 10.0];
    for (int i = 0; i < barOffsets.length; i++) {
      final barHeight = math.sin((animationValue * 4 * math.pi) + (i * 0.8)).abs() * 12 + 4;
      canvas.drawLine(
        Offset(center.dx + barOffsets[i], center.dy - barHeight / 2),
        Offset(center.dx + barOffsets[i], center.dy + barHeight / 2),
        barPaint,
      );
    }
  }

  void _drawWorkingState(Canvas canvas, Offset center, double radius) {
    // High-tech quantum processor spin
    final ringPaint1 = Paint()
      ..color = const Color(0xFFF59E0B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final ringPaint2 = Paint()
      ..color = const Color(0xFF06B6D4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final rot1 = animationValue * 4 * math.pi;
    final rot2 = -animationValue * 3 * math.pi;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.85),
      rot1,
      math.pi * 0.9,
      false,
      ringPaint1,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.70),
      rot2,
      math.pi * 1.2,
      false,
      ringPaint2,
    );

    // Core
    final corePaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFFBBF24), Color(0xFFD97706), Color(0xFF1E1B4B)],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.55));
    canvas.drawCircle(center, radius * 0.55, corePaint);

    _drawRioGlyph(canvas, center, radius * 0.35, Colors.white);
  }

  void _drawSuccessState(Canvas canvas, Offset center, double radius) {
    // Emerald confirmation glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF10B981).withOpacity(0.6),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, glowPaint);

    final corePaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFF34D399), Color(0xFF059669), Color(0xFF064E3B)],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.7));
    canvas.drawCircle(center, radius * 0.7, corePaint);

    // Checkmark
    final checkPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(center.dx - 8, center.dy)
      ..lineTo(center.dx - 2, center.dy + 6)
      ..lineTo(center.dx + 8, center.dy - 6);
    canvas.drawPath(path, checkPaint);
  }

  void _drawErrorState(Canvas canvas, Offset center, double radius) {
    final corePaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFF87171), Color(0xFFDC2626), Color(0xFF450A0A)],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.7));
    canvas.drawCircle(center, radius * 0.7, corePaint);

    final markPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(center.dx - 6, center.dy - 6),
      Offset(center.dx + 6, center.dy + 6),
      markPaint,
    );
    canvas.drawLine(
      Offset(center.dx + 6, center.dy - 6),
      Offset(center.dx - 6, center.dy + 6),
      markPaint,
    );
  }

  void _drawRioGlyph(Canvas canvas, Offset center, double size, Color color) {
    // Modern stylized "R" glyph
    final glyphPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(center.dx - size * 0.5, center.dy + size * 0.7)
      ..lineTo(center.dx - size * 0.5, center.dy - size * 0.7)
      ..cubicTo(
        center.dx + size * 0.6,
        center.dy - size * 0.7,
        center.dx + size * 0.6,
        center.dy,
        center.dx - size * 0.5,
        center.dy,
      )
      ..moveTo(center.dx - size * 0.1, center.dy)
      ..lineTo(center.dx + size * 0.5, center.dy + size * 0.7);

    canvas.drawPath(path, glyphPaint);
  }

  @override
  bool shouldRepaint(covariant _RioAvatarPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.state != state;
  }
}
