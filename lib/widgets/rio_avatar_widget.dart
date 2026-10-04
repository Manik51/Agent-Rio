import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rive/rive.dart'
    show SMIBool, SMITrigger, Artboard, StateMachineController, RiveAnimation;

enum RioAvatarState { idle, listening, working, success, error }

enum RioAvatarType {
  rioOfficial,
  pinkChill,
  yellowNerd,
  blueBeret,
  greenFrog,
  heartCool,
  gptDots,
}

class RioAvatarWidget extends StatefulWidget {
  final RioAvatarState state;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;
  final double size;
  final RioAvatarType? avatarType;

  const RioAvatarWidget({
    super.key,
    required this.state,
    required this.onTap,
    this.onDoubleTap,
    this.size = 56.0,
    this.avatarType,
  });

  static Future<RioAvatarType> getSavedAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('rio_selected_avatar') ?? 'rioOfficial';
    return RioAvatarType.values.firstWhere(
      (e) => e.name == name,
      orElse: () => RioAvatarType.rioOfficial,
    );
  }

  static Future<void> saveAvatar(RioAvatarType type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('rio_selected_avatar', type.name);
  }

  @override
  State<RioAvatarWidget> createState() => _RioAvatarWidgetState();
}

class _RioAvatarWidgetState extends State<RioAvatarWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  RioAvatarType _currentType = RioAvatarType.rioOfficial;

  @override
  void initState() {
    super.initState();
    _currentType = widget.avatarType ?? RioAvatarType.rioOfficial;
    _loadType();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
  }

  Future<void> _loadType() async {
    if (widget.avatarType == null) {
      final saved = await RioAvatarWidget.getSavedAvatar();
      if (mounted) setState(() => _currentType = saved);
    }
  }

  @override
  void didUpdateWidget(covariant RioAvatarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.avatarType != null && widget.avatarType != _currentType) {
      setState(() => _currentType = widget.avatarType!);
    }
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
            painter: _CompanionAvatarPainter(
              animationValue: _animController.value,
              state: widget.state,
              type: _currentType,
            ),
          );
        },
      ),
    );
  }
}

class _RioRiveAvatarWidget extends StatefulWidget {
  final RioAvatarState state;
  final double size;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;

  const _RioRiveAvatarWidget({
    required this.state,
    required this.size,
    required this.onTap,
    this.onDoubleTap,
  });

  @override
  State<_RioRiveAvatarWidget> createState() => _RioRiveAvatarWidgetState();
}

class _RioRiveAvatarWidgetState extends State<_RioRiveAvatarWidget>
    with SingleTickerProviderStateMixin {
  SMIBool? _typingInput;
  SMIBool? _loadingInput;
  SMITrigger? _correctInput;
  SMITrigger? _wrongInput;
  SMITrigger? _jumpInput;
  bool _isLoaded = false;
  bool _hasError = false;
  late AnimationController _fallbackAnim;

  @override
  void initState() {
    super.initState();
    _fallbackAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _fallbackAnim.dispose();
    super.dispose();
  }

  void _onRiveInit(Artboard artboard) {
    try {
      final controller = StateMachineController.fromArtboard(
        artboard,
        'State Machine 1',
      ) ?? (artboard.stateMachines.isNotEmpty
          ? StateMachineController.fromArtboard(artboard, artboard.stateMachines.first.name)
          : null);
      if (controller != null) {
        artboard.addController(controller);
        _typingInput = controller.findInput<bool>('typingBoolean') as SMIBool?;
        _loadingInput = controller.findInput<bool>('loadingBoolean') as SMIBool?;
        _correctInput = controller.findInput<bool>('correct') as SMITrigger?;
        _wrongInput = controller.findInput<bool>('wrong') as SMITrigger?;
        _jumpInput = controller.findInput<bool>('jump') as SMITrigger?;
        if (mounted) setState(() => _isLoaded = true);
        _syncState(widget.state);
      }
    } catch (e) {
      debugPrint('Error attaching Rive controller: $e');
      if (mounted) setState(() => _hasError = true);
    }
  }

  void _syncState(RioAvatarState state) {
    if (!_isLoaded) return;
    try {
      switch (state) {
        case RioAvatarState.listening:
          _typingInput?.value = true;
          _loadingInput?.value = false;
          break;
        case RioAvatarState.working:
          _loadingInput?.value = true;
          _typingInput?.value = false;
          break;
        case RioAvatarState.success:
          _correctInput?.fire();
          _loadingInput?.value = false;
          _typingInput?.value = false;
          break;
        case RioAvatarState.error:
          _wrongInput?.fire();
          _loadingInput?.value = false;
          _typingInput?.value = false;
          break;
        case RioAvatarState.idle:
          _loadingInput?.value = false;
          _typingInput?.value = false;
          break;
      }
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant _RioRiveAvatarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _syncState(widget.state);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      // Graceful fallback to glowing animated official AI Orb Mascot
      return GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: AnimatedBuilder(
            animation: _fallbackAnim,
            builder: (context, _) {
              return CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _CompanionAvatarPainter(
                  animationValue: _fallbackAnim.value,
                  state: widget.state,
                  type: RioAvatarType.rioOfficial,
                ),
              );
            },
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        try {
          _jumpInput?.fire();
        } catch (_) {}
        widget.onTap();
      },
      onDoubleTap: widget.onDoubleTap,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: RiveAnimation.asset(
          'assets/Rio.riv',
          fit: BoxFit.contain,
          onInit: _onRiveInit,
          placeHolder: Center(
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: AnimatedBuilder(
                animation: _fallbackAnim,
                builder: (context, _) {
                  return CustomPaint(
                    size: Size(widget.size, widget.size),
                    painter: _CompanionAvatarPainter(
                      animationValue: _fallbackAnim.value,
                      state: widget.state,
                      type: RioAvatarType.rioOfficial,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompanionAvatarPainter extends CustomPainter {
  final double animationValue;
  final RioAvatarState state;
  final RioAvatarType type;

  _CompanionAvatarPainter({
    required this.animationValue,
    required this.state,
    required this.type,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;
    final time = animationValue * 2 * math.pi;

    if (type == RioAvatarType.gptDots) {
      _drawGptDots(canvas, cx, cy, r, time);
      return;
    }

    // Breathing float & bounce
    final bounce = math.sin(time * 2) * (r * 0.05);
    final center = Offset(cx, cy + bounce);

    // Reactive glow ring when listening / working
    if (state == RioAvatarState.listening) {
      final pulse = (math.sin(time * 6).abs() * 0.2 + 0.95);
      final glowPaint = Paint()
        ..color = const Color(0xFF38BDF8).withOpacity(0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5;
      canvas.drawCircle(center, r * pulse, glowPaint);
    } else if (state == RioAvatarState.working) {
      final ringPaint = Paint()
        ..color = const Color(0xFFF59E0B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r * 0.96),
        time * 3,
        math.pi * 1.3,
        false,
        ringPaint,
      );
    }

    switch (type) {
      case RioAvatarType.rioOfficial:
        _drawRioOfficial(canvas, center, r, time);
        break;
      case RioAvatarType.pinkChill:
        _drawPinkChill(canvas, center, r, time);
        break;
      case RioAvatarType.yellowNerd:
        _drawYellowNerd(canvas, center, r, time);
        break;
      case RioAvatarType.blueBeret:
        _drawBlueBeret(canvas, center, r, time);
        break;
      case RioAvatarType.greenFrog:
        _drawGreenFrog(canvas, center, r, time);
        break;
      case RioAvatarType.heartCool:
        _drawHeartCool(canvas, center, r, time);
        break;
      case RioAvatarType.gptDots:
        break;
    }
  }

  // Official Rio AI Orb Mascot (Vibrant Circular Rainbow Halo with Obsidian Core & Twin Pill Eyes)
  // Perfectly matching the user's authentic asset (media_1791128528498.jpg)
  void _drawRioOfficial(Canvas canvas, Offset center, double r, double time) {
    // 1. Rainbow Halo Colors
    final rainbowColors = const [
      Color(0xFFFF5A1F), // Neon Orange (top-left)
      Color(0xFFE02497), // Hot Pink / Magenta (top)
      Color(0xFF7E22CE), // Purple / Violet (top-right)
      Color(0xFF2563EB), // Royal Blue (right)
      Color(0xFF00D2FF), // Bright Cyan (bottom-right)
      Color(0xFF00E5FF), // Electric Cyan (bottom)
      Color(0xFF9D1DF2), // Purple-Pink (bottom-left)
      Color(0xFFFF4D2D), // Red-Orange (left)
      Color(0xFFFF5A1F), // Orange (completes 360 loop)
    ];

    // Smooth subtle rotation when active/working
    final rotationAngle = (state == RioAvatarState.working) ? time * 1.6 : 0.0;
    final baseAngle = -math.pi * 0.75 + rotationAngle;

    // Outer Radiant Glow
    final glowRadius = r * 0.82;
    final glowPaint = Paint()
      ..shader = SweepGradient(
        colors: rainbowColors,
        startAngle: 0.0,
        endAngle: math.pi * 2,
        transform: GradientRotation(baseAngle),
      ).createShader(Rect.fromCircle(center: center, radius: glowRadius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.24
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.16);

    final glowPulse = (state == RioAvatarState.listening)
        ? (0.75 + 0.25 * math.sin(time * 5).abs())
        : 0.70;
    glowPaint.color = Colors.white.withOpacity(glowPulse);
    canvas.drawCircle(center, glowRadius, glowPaint);

    // 2. Crisp, Thick Rainbow Gradient Ring
    final ringRadius = r * 0.79;
    final ringPaint = Paint()
      ..shader = SweepGradient(
        colors: rainbowColors,
        startAngle: 0.0,
        endAngle: math.pi * 2,
        transform: GradientRotation(baseAngle),
      ).createShader(Rect.fromCircle(center: center, radius: ringRadius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.26
      ..strokeCap = StrokeCap.butt;
    canvas.drawCircle(center, ringRadius, ringPaint);

    // 3. Deep Obsidian Midnight Core Circle
    final corePaint = Paint()
      ..color = const Color(0xFF131620)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, r * 0.65, corePaint);

    // 4. Subtle Inner Rim Depth Shadow
    final innerRimPaint = Paint()
      ..color = Colors.black.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.035;
    canvas.drawCircle(center, r * 0.64, innerRimPaint);

    // 5. Iconic Twin White Vertical Pill Eyes (..)
    final blinkSin = math.sin(time * 2.8);
    final isBlinking = blinkSin > 0.94;
    final blinkFactor = isBlinking ? (1.0 - (blinkSin - 0.94) / 0.06).clamp(0.12, 1.0) : 1.0;

    final eyeWidth = r * 0.20;
    final baseEyeHeight = r * 0.30;
    final eyeY = center.dy - r * 0.03;
    final eyeSpacing = r * 0.32;

    final leftEyeCenter = Offset(center.dx - eyeSpacing / 2, eyeY);
    final rightEyeCenter = Offset(center.dx + eyeSpacing / 2, eyeY);

    if (state == RioAvatarState.success) {
      // Cheerful upside-down arcs on success (^ ^)
      final happyPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.055
        ..strokeCap = StrokeCap.round;

      final arcRadius = r * 0.09;
      canvas.drawArc(
        Rect.fromCircle(center: leftEyeCenter, radius: arcRadius),
        math.pi * 1.15,
        math.pi * 0.7,
        false,
        happyPaint,
      );
      canvas.drawArc(
        Rect.fromCircle(center: rightEyeCenter, radius: arcRadius),
        math.pi * 1.15,
        math.pi * 0.7,
        false,
        happyPaint,
      );
    } else {
      // Clean Pill Eyes with subtle vertical shading
      final eyePaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: (state == RioAvatarState.error)
              ? const [Color(0xFFFFA4A4), Color(0xFFFF4848)]
              : const [Color(0xFFFFFFFF), Color(0xFFE2E8F0)],
        ).createShader(Rect.fromCenter(
          center: center,
          width: r,
          height: r,
        ))
        ..style = PaintingStyle.fill;

      final currentHeight = (state == RioAvatarState.listening)
          ? (baseEyeHeight * 1.08)
          : (baseEyeHeight * blinkFactor);

      // Left Pill Eye
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: leftEyeCenter,
            width: eyeWidth,
            height: currentHeight,
          ),
          Radius.circular(eyeWidth / 2),
        ),
        eyePaint,
      );

      // Right Pill Eye
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: rightEyeCenter,
            width: eyeWidth,
            height: currentHeight,
          ),
          Radius.circular(eyeWidth / 2),
        ),
        eyePaint,
      );
    }
  }

  // 1. Pink Chill (Pink fuzzy ball with black over-ear headphones)
  void _drawPinkChill(Canvas canvas, Offset center, double r, double time) {
    final bodyPaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFF472B6), Color(0xFFEC4899), Color(0xFFBE185D)],
        stops: [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: r * 0.72));

    canvas.drawCircle(center, r * 0.72, bodyPaint);

    // Cute closed smiling eyes
    final eyePaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    final leftEye = Rect.fromCircle(center: Offset(center.dx - r * 0.24, center.dy - r * 0.05), radius: r * 0.14);
    final rightEye = Rect.fromCircle(center: Offset(center.dx + r * 0.24, center.dy - r * 0.05), radius: r * 0.14);
    canvas.drawArc(leftEye, 0, math.pi, false, eyePaint);
    canvas.drawArc(rightEye, 0, math.pi, false, eyePaint);

    // Happy little mouth
    final mouthRect = Rect.fromCircle(center: Offset(center.dx, center.dy + r * 0.18), radius: r * 0.10);
    canvas.drawArc(mouthRect, 0, math.pi, false, eyePaint);

    // Over-ear Headphones (Headband + Earcups)
    final bandPaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(Rect.fromCircle(center: center, radius: r * 0.84), math.pi, math.pi, false, bandPaint);

    final earCupPaint = Paint()..color = const Color(0xFF1E293B);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(center.dx - r * 0.78, center.dy), width: r * 0.22, height: r * 0.52), const Radius.circular(8)),
      earCupPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(center.dx + r * 0.78, center.dy), width: r * 0.22, height: r * 0.52), const Radius.circular(8)),
      earCupPaint,
    );
  }

  // 2. Yellow Nerd (Yellow triangle creature with nerd glasses and bow tie)
  void _drawYellowNerd(Canvas canvas, Offset center, double r, double time) {
    final bodyPaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFFDE047), Color(0xFFEAB308), Color(0xFFCA8A04)],
      ).createShader(Rect.fromCircle(center: center, radius: r * 0.75));

    final path = Path()
      ..moveTo(center.dx, center.dy - r * 0.78)
      ..quadraticBezierTo(center.dx + r * 0.80, center.dy + r * 0.75, center.dx, center.dy + r * 0.75)
      ..quadraticBezierTo(center.dx - r * 0.80, center.dy + r * 0.75, center.dx, center.dy - r * 0.78);
    canvas.drawPath(path, bodyPaint);

    // Round Glasses
    final glassFrame = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8;

    final lensFill = Paint()..color = Colors.white;

    final leftCenter = Offset(center.dx - r * 0.26, center.dy - r * 0.12);
    final rightCenter = Offset(center.dx + r * 0.26, center.dy - r * 0.12);

    canvas.drawCircle(leftCenter, r * 0.24, lensFill);
    canvas.drawCircle(rightCenter, r * 0.24, lensFill);
    canvas.drawCircle(leftCenter, r * 0.24, glassFrame);
    canvas.drawCircle(rightCenter, r * 0.24, glassFrame);
    canvas.drawLine(Offset(leftCenter.dx + r * 0.24, leftCenter.dy), Offset(rightCenter.dx - r * 0.24, rightCenter.dy), glassFrame);

    // Pupils
    final pupilPaint = Paint()..color = Colors.black;
    canvas.drawCircle(leftCenter, r * 0.10, pupilPaint);
    canvas.drawCircle(rightCenter, r * 0.10, pupilPaint);

    // Black Bow Tie
    _drawBowTie(canvas, Offset(center.dx, center.dy + r * 0.48), r * 0.32, Colors.black87);
  }

  // 3. Blue Beret (Blue fuzzy cloud with stylish black French beret)
  void _drawBlueBeret(Canvas canvas, Offset center, double r, double time) {
    final cloudPaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFF60A5FA), Color(0xFF3B82F6), Color(0xFF1D4ED8)],
      ).createShader(Rect.fromCircle(center: center, radius: r * 0.75));

    // Fluffy cloud body
    canvas.drawCircle(center, r * 0.58, cloudPaint);
    canvas.drawCircle(Offset(center.dx - r * 0.32, center.dy + r * 0.12), r * 0.34, cloudPaint);
    canvas.drawCircle(Offset(center.dx + r * 0.32, center.dy + r * 0.12), r * 0.34, cloudPaint);

    // Eyes
    final eyePaint = Paint()..color = Colors.black87;
    canvas.drawCircle(Offset(center.dx - r * 0.14, center.dy + r * 0.05), r * 0.07, eyePaint);
    canvas.drawCircle(Offset(center.dx + r * 0.14, center.dy + r * 0.05), r * 0.07, eyePaint);

    // Black Beret on top slanted
    final beretPaint = Paint()..color = const Color(0xFF0F172A);
    canvas.save();
    canvas.translate(center.dx - r * 0.12, center.dy - r * 0.52);
    canvas.rotate(-0.25);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 0.85, height: r * 0.38), beretPaint);
    canvas.drawCircle(Offset(0, -r * 0.18), r * 0.06, beretPaint);
    canvas.restore();
  }

  // 4. Green Frog (Curious green frog with top eyes and black bow tie)
  void _drawGreenFrog(Canvas canvas, Offset center, double r, double time) {
    final frogPaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFA3E635), Color(0xFF84CC16), Color(0xFF4D7C0F)],
      ).createShader(Rect.fromCircle(center: center, radius: r * 0.75));

    // Body
    canvas.drawCircle(Offset(center.dx, center.dy + r * 0.12), r * 0.60, frogPaint);

    // Two big cute frog eyes popping on top
    final leftEyeTop = Offset(center.dx - r * 0.32, center.dy - r * 0.40);
    final rightEyeTop = Offset(center.dx + r * 0.32, center.dy - r * 0.40);

    canvas.drawCircle(leftEyeTop, r * 0.24, frogPaint);
    canvas.drawCircle(rightEyeTop, r * 0.24, frogPaint);

    canvas.drawCircle(leftEyeTop, r * 0.18, Paint()..color = Colors.white);
    canvas.drawCircle(rightEyeTop, r * 0.18, Paint()..color = Colors.white);

    // Pupils looking up curiously
    canvas.drawCircle(Offset(leftEyeTop.dx + 2, leftEyeTop.dy - 3), r * 0.09, Paint()..color = Colors.black);
    canvas.drawCircle(Offset(rightEyeTop.dx - 2, rightEyeTop.dy - 3), r * 0.09, Paint()..color = Colors.black);

    // Cute Bow Tie
    _drawBowTie(canvas, Offset(center.dx, center.dy + r * 0.52), r * 0.30, Colors.black87);
  }

  // 5. Heart Cool (Magenta heart creature wearing sunglasses)
  void _drawHeartCool(Canvas canvas, Offset center, double r, double time) {
    final heartPaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFF43F5E), Color(0xFFE11D48), Color(0xFF9F1239)],
      ).createShader(Rect.fromCircle(center: center, radius: r * 0.8));

    final path = Path();
    final d = r * 0.72;
    path.moveTo(center.dx, center.dy + d * 0.65);
    path.cubicTo(center.dx + d * 1.1, center.dy - d * 0.2, center.dx + d * 0.6, center.dy - d * 0.95, center.dx, center.dy - d * 0.35);
    path.cubicTo(center.dx - d * 0.6, center.dy - d * 0.95, center.dx - d * 1.1, center.dy - d * 0.2, center.dx, center.dy + d * 0.65);
    canvas.drawPath(path, heartPaint);

    // Sunglasses
    final glassesPaint = Paint()..color = const Color(0xFF0F172A);
    canvas.drawCircle(Offset(center.dx - r * 0.28, center.dy - r * 0.02), r * 0.18, glassesPaint);
    canvas.drawCircle(Offset(center.dx + r * 0.28, center.dy - r * 0.02), r * 0.18, glassesPaint);
    canvas.drawLine(
      Offset(center.dx - r * 0.12, center.dy - r * 0.02),
      Offset(center.dx + r * 0.12, center.dy - r * 0.02),
      Paint()..color = const Color(0xFF0F172A)..strokeWidth = 3,
    );
  }

  void _drawBowTie(Canvas canvas, Offset pos, double size, Color color) {
    final bowPaint = Paint()..color = color;
    final path = Path()
      ..moveTo(pos.dx - size / 2, pos.dy - size * 0.35)
      ..lineTo(pos.dx, pos.dy)
      ..lineTo(pos.dx - size / 2, pos.dy + size * 0.35)
      ..close()
      ..moveTo(pos.dx + size / 2, pos.dy - size * 0.35)
      ..lineTo(pos.dx, pos.dy)
      ..lineTo(pos.dx + size / 2, pos.dy + size * 0.35)
      ..close();
    canvas.drawPath(path, bowPaint);
    canvas.drawCircle(pos, size * 0.18, bowPaint);
  }

  // 6. Minimal GPT Dots
  void _drawGptDots(Canvas canvas, double cx, double cy, double baseRadius, double time) {
    const gptColors = [Color(0xFFFFFFFF), Color(0xFF38BDF8), Color(0xFFA855F7), Color(0xFFF43F5E)];
    const numDots = 4;
    for (int i = 0; i < numDots; i++) {
      final baseAngle = (i * (2 * math.pi) / numDots);
      final orbitRadius = baseRadius * 0.44 + math.sin(time * 2 + i) * (baseRadius * 0.04);
      final currentAngle = baseAngle + time * 0.8;
      final x = cx + math.cos(currentAngle) * orbitRadius;
      final y = cy + math.sin(currentAngle) * orbitRadius;
      final dotRadius = baseRadius * 0.22;
      canvas.drawCircle(Offset(x, y), dotRadius, Paint()..color = gptColors[i]);
    }
  }

  @override
  bool shouldRepaint(covariant _CompanionAvatarPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.state != state ||
        oldDelegate.type != type;
  }
}
