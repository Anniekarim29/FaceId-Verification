import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Status cycle ────────────────────────────────────────────────────────────
enum _ScanStatus { scanning, analyzing, verified }

extension _StatusLabel on _ScanStatus {
  String get label {
    switch (this) {
      case _ScanStatus.scanning:
        return 'Scanning';
      case _ScanStatus.analyzing:
        return 'Analyzing Biometric Data';
      case _ScanStatus.verified:
        return 'Identity Verified';
    }
  }

  String get subtitle {
    switch (this) {
      case _ScanStatus.scanning:
        return 'Look directly at your device';
      case _ScanStatus.analyzing:
        return 'Processing facial geometry…';
      case _ScanStatus.verified:
        return 'Authentication successful';
    }
  }
}

// ─── Palette ─────────────────────────────────────────────────────────────────
class _Palette {
  static const bg = Color(0xFF08101F);
  static const surface = Color(0xFF0D1828);
  static const ringPrimary = Color(0xFF3A6FBF);
  static const ringAccent = Color(0xFF5B9BD5);
  static const scanLine = Color(0xFF7EB8E8);
  static const textPrimary = Color(0xFFE8EEF7);
  static const textSecondary = Color(0xFF7A99C2);
  static const buttonBg = Color(0xFF152235);
  static const buttonBorder = Color(0xFF2A4A72);
  static const successGreen = Color(0xFF34B87A);
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class FaceScanScreen extends StatefulWidget {
  const FaceScanScreen({super.key});

  @override
  State<FaceScanScreen> createState() => _FaceScanScreenState();
}

class _FaceScanScreenState extends State<FaceScanScreen>
    with TickerProviderStateMixin {
  // Rotation for the outer dashed ring
  late final AnimationController _rotateCtrl;
  // Scan-line sweep inside the circle
  late final AnimationController _scanCtrl;
  // Subtle pulse on the main ring
  late final AnimationController _pulseCtrl;
  // Button press scale
  late final AnimationController _buttonCtrl;
  // Success circle expand + fade
  late final AnimationController _successCtrl;
  // Eyes motion (looking around)
  late final AnimationController _eyesCtrl;

  _ScanStatus _status = _ScanStatus.scanning;
  bool _verified = false;
  bool _scanning = false; // prevents double-tap

  @override
  void initState() {
    super.initState();

    _rotateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _scanCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);

    _buttonCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.93,
      upperBound: 1.0,
    )..value = 1.0;

    _successCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _eyesCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _rotateCtrl.dispose();
    _scanCtrl.dispose();
    _pulseCtrl.dispose();
    _buttonCtrl.dispose();
    _successCtrl.dispose();
    _eyesCtrl.dispose();
    super.dispose();
  }

  // ─── Verify flow ────────────────────────────────────────────────────────
  Future<void> _startVerification() async {
    if (_scanning) return;
    setState(() {
      _scanning = true;
      _status = _ScanStatus.scanning;
      _verified = false;
    });
    _successCtrl.reset();

    // Step 1: Scanning → Analyzing
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;
    setState(() => _status = _ScanStatus.analyzing);

    // Step 2: Analyzing → Verified
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;
    setState(() {
      _status = _ScanStatus.verified;
      _verified = true;
    });
    await _successCtrl.forward();

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    // Reset to idle
    setState(() {
      _status = _ScanStatus.scanning;
      _verified = false;
      _scanning = false;
    });
    _successCtrl.reset();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // Limit ring size to prevent overflow on shorter screens
    final ringSize = math.min(size.width * 0.72, size.height * 0.45);

    return Scaffold(
      backgroundColor: _Palette.bg,
      body: Stack(
        children: [
          // ── subtle radial background glow (no neon, just depth) ──────────
          Positioned(
            top: -size.height * 0.15,
            left: size.width / 2 - size.width * 0.55,
            child: Container(
              width: size.width * 1.1,
              height: size.width * 1.1,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF1A3A6B).withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: SizedBox(
              width: size.width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                const SizedBox(height: 24),

                // ── Time & Date ─────────────────────────────────────────────
                _TimeBlock(),

                const SizedBox(height: 40),

                // ── Circle scanner ──────────────────────────────────────────
                SizedBox(
                  width: ringSize,
                  height: ringSize,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outermost pulse ring
                      AnimatedBuilder(
                        animation: _pulseCtrl,
                        builder: (_, __) {
                          final scale = 1.0 + _pulseCtrl.value * 0.025;
                          return Transform.scale(
                            scale: scale,
                            child: Container(
                              width: ringSize,
                              height: ringSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _Palette.ringPrimary
                                      .withValues(alpha: 0.15 + _pulseCtrl.value * 0.07),
                                  width: 1,
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      // Mid static ring
                      Container(
                        width: ringSize * 0.88,
                        height: ringSize * 0.88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _Palette.ringPrimary.withValues(alpha: 0.28),
                            width: 1.5,
                          ),
                        ),
                      ),

                      // Rotating dashed accent ring
                      AnimatedBuilder(
                        animation: _rotateCtrl,
                        builder: (_, __) {
                          return Transform.rotate(
                            angle: _rotateCtrl.value * 2 * math.pi,
                            child: CustomPaint(
                              size: Size(ringSize * 0.88, ringSize * 0.88),
                              painter: _DashedRingPainter(
                                color: _Palette.ringAccent.withValues(alpha: 0.55),
                                strokeWidth: 1.2,
                                dashCount: 48,
                                gapRatio: 0.5,
                              ),
                            ),
                          );
                        },
                      ),

                      // Inner filled circle (matte surface)
                      Container(
                        width: ringSize * 0.72,
                        height: ringSize * 0.72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _Palette.surface,
                          boxShadow: [
                            BoxShadow(
                              color: _Palette.ringPrimary.withValues(alpha: 0.08),
                              blurRadius: 32,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                      ),

                      // Scan line sweeping vertically
                      ClipOval(
                        child: SizedBox(
                          width: ringSize * 0.72,
                          height: ringSize * 0.72,
                          child: AnimatedBuilder(
                            animation: _scanCtrl,
                            builder: (_, __) {
                              final t = _scanCtrl.value;
                              // Ease in-out bounce
                              final y = (t < 0.5
                                  ? 2 * t * t
                                  : -1 + (4 - 2 * t) * t);
                              final topOffset =
                                  (ringSize * 0.72) * y - 1;
                              return Stack(
                                children: [
                                  Positioned(
                                    top: topOffset,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      height: 1.5,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.transparent,
                                            _Palette.scanLine
                                                .withValues(alpha: 0.6),
                                            _Palette.scanLine
                                                .withValues(alpha: 0.9),
                                            _Palette.scanLine
                                                .withValues(alpha: 0.6),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),

                      // Face frame corners
                      CustomPaint(
                        size: Size(ringSize * 0.38, ringSize * 0.38),
                        painter: _FaceFramePainter(
                          color: _Palette.ringAccent.withValues(alpha: 0.9),
                        ),
                      ),

                      // Success overlay
                      if (_verified)
                        _SuccessOverlay(
                          controller: _successCtrl,
                          size: ringSize * 0.72,
                        ),

                      // FaceID Icon in center
                      if (!_verified)
                        AnimatedBuilder(
                          animation: _eyesCtrl,
                          builder: (_, __) {
                            return _FaceIdIcon(
                              size: ringSize * 0.32,
                              animation: _eyesCtrl.value,
                              status: _status,
                            );
                          },
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 36),

                // ── Status text ─────────────────────────────────────────────
                _StatusText(status: _status),

                const Spacer(),

                // ── Verify button ───────────────────────────────────────────
                GestureDetector(
                  onTapDown: (_) => _buttonCtrl.reverse(),
                  onTapUp: (_) {
                    _buttonCtrl.forward();
                    _startVerification();
                  },
                  onTapCancel: () => _buttonCtrl.forward(),
                  child: ScaleTransition(
                    scale: _buttonCtrl,
                    child: _VerifyButton(scanning: _scanning, verified: _verified),
                  ),
                ),

                const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Time block ───────────────────────────────────────────────────────────────
class _TimeBlock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final days = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday'
    ];
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    final dateStr =
        '${days[now.weekday % 7]}, ${months[now.month - 1]} ${now.day}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '$hour:$minute',
          style: GoogleFonts.outfit(
            fontSize: 72,
            fontWeight: FontWeight.w400,
            letterSpacing: -2,
            color: _Palette.textPrimary,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          dateStr,
          style: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
            color: _Palette.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ─── Status text with AnimatedSwitcher ────────────────────────────────────────
class _StatusText extends StatelessWidget {
  const _StatusText({required this.status});
  final _ScanStatus status;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, anim) {
            final slide = Tween<Offset>(
              begin: const Offset(0, 0.3),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut));
            return FadeTransition(
              opacity: anim,
              child: SlideTransition(position: slide, child: child),
            );
          },
          child: Text(
            status.label,
            key: ValueKey(status.label),
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color: status == _ScanStatus.verified
                  ? _Palette.successGreen
                  : _Palette.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: Text(
            status.subtitle,
            key: ValueKey(status.subtitle),
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
              color: _Palette.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Verify button ────────────────────────────────────────────────────────────
class _VerifyButton extends StatelessWidget {
  const _VerifyButton({required this.scanning, required this.verified});
  final bool scanning;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      width: 200,
      decoration: BoxDecoration(
        color: _Palette.buttonBg,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: verified ? _Palette.successGreen.withValues(alpha: 0.5) : _Palette.buttonBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            verified
                ? Icons.check_rounded
                : scanning
                    ? Icons.face_retouching_natural
                    : Icons.face_retouching_natural,
            color: verified ? _Palette.successGreen : _Palette.textSecondary,
            size: 18,
          ),
          const SizedBox(width: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              verified ? 'Verified' : scanning ? 'Verifying…' : 'Verify Identity',
              key: ValueKey('$verified-$scanning'),
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                color: verified ? _Palette.successGreen : _Palette.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Success overlay animation ────────────────────────────────────────────────
class _SuccessOverlay extends StatelessWidget {
  const _SuccessOverlay({
    required this.controller,
    required this.size,
  });
  final AnimationController controller;
  final double size;

  @override
  Widget build(BuildContext context) {
    final expandAnim = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    final checkAnim = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
    );

    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        return ClipOval(
          child: Container(
            width: size,
            height: size,
            color: Colors.transparent,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Expanding fill circle
                Transform.scale(
                  scale: expandAnim.value,
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _Palette.successGreen.withValues(alpha: 0.18),
                    ),
                  ),
                ),
                // Checkmark
                Opacity(
                  opacity: checkAnim.value.clamp(0.0, 1.0),
                  child: Icon(
                    Icons.check_rounded,
                    color: _Palette.successGreen,
                    size: size * 0.32,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Custom Painters ──────────────────────────────────────────────────────────

/// Dashed ring painter for the rotating accent ring
class _DashedRingPainter extends CustomPainter {
  const _DashedRingPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashCount,
    required this.gapRatio,
  });

  final Color color;
  final double strokeWidth;
  final int dashCount;
  final double gapRatio; // fraction of arc that is gap

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final totalAngle = 2 * math.pi;
    final dashAngle = totalAngle / dashCount * (1 - gapRatio);
    final gapAngle = totalAngle / dashCount * gapRatio;

    double startAngle = 0;
    for (int i = 0; i < dashCount; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        dashAngle,
        false,
        paint,
      );
      startAngle += dashAngle + gapAngle;
    }
  }

  @override
  bool shouldRepaint(_DashedRingPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}

/// Face frame corners painter
class _FaceFramePainter extends CustomPainter {
  const _FaceFramePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final cornerLen = size.width * 0.28;
    final r = 6.0;

    // Top-left
    canvas.drawLine(Offset(r, 0), Offset(cornerLen, 0), paint);
    canvas.drawLine(Offset(0, r), Offset(0, cornerLen), paint);

    // Top-right
    canvas.drawLine(Offset(size.width - cornerLen, 0), Offset(size.width - r, 0), paint);
    canvas.drawLine(Offset(size.width, r), Offset(size.width, cornerLen), paint);

    // Bottom-left
    canvas.drawLine(Offset(0, size.height - cornerLen), Offset(0, size.height - r), paint);
    canvas.drawLine(Offset(r, size.height), Offset(cornerLen, size.height), paint);

    // Bottom-right
    canvas.drawLine(
        Offset(size.width, size.height - cornerLen), Offset(size.width, size.height - r), paint);
    canvas.drawLine(
        Offset(size.width - cornerLen, size.height), Offset(size.width - r, size.height), paint);
  }

  @override
  bool shouldRepaint(_FaceFramePainter old) => old.color != color;
}

/// ─── FaceID Icon Widget ───────────────────────────────────────────────────────
class _FaceIdIcon extends StatelessWidget {
  const _FaceIdIcon({
    required this.size,
    required this.animation,
    required this.status,
  });

  final double size;
  final double animation;
  final _ScanStatus status;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _FaceIdPainter(
        color: _Palette.textSecondary.withValues(alpha: 0.8),
        animation: animation,
        isAnalyzing: status == _ScanStatus.analyzing,
      ),
    );
  }
}

class _FaceIdPainter extends CustomPainter {
  _FaceIdPainter({
    required this.color,
    required this.animation,
    required this.isAnalyzing,
  });

  final Color color;
  final double animation;
  final bool isAnalyzing;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.06
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;
    final r = w * 0.25; // corner radius for the face box

    // 1. Draw rounded face box
    final faceRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h),
      Radius.circular(r),
    );
    canvas.drawRRect(faceRect, paint);

    // 2. Draw Nose (J shape)
    final nosePath = Path()
      ..moveTo(w * 0.5, h * 0.35)
      ..lineTo(w * 0.5, h * 0.6)
      ..arcToPoint(
        Offset(w * 0.4, h * 0.65),
        radius: Radius.circular(w * 0.1),
        clockwise: false,
      );
    canvas.drawPath(nosePath, paint);

    // 3. Draw Eyes (Motion)
    // We'll calculate an offset based on animation
    // Look left (0.2), center (0.4), right (0.6), center (0.8)
    double eyeOffsetX = 0;
    double eyeOffsetY = 0;

    if (!isAnalyzing) {
      if (animation < 0.25) {
        eyeOffsetX = math.sin(animation * 4 * math.pi) * (w * 0.05);
      } else if (animation > 0.5 && animation < 0.75) {
        eyeOffsetY = math.sin((animation - 0.5) * 4 * math.pi) * (w * 0.03);
      }
    } else {
      // Analyzing: fast subtle vibration
      eyeOffsetX = math.sin(animation * 20 * math.pi) * (w * 0.02);
    }

    final eyePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final eyeW = w * 0.08;
    final eyeH = h * 0.22;
    final eyeY = h * 0.35;

    // Left eye
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(w * 0.3 + eyeOffsetX, eyeY + eyeOffsetY),
          width: eyeW,
          height: eyeH,
        ),
        Radius.circular(eyeW / 2),
      ),
      eyePaint,
    );

    // Right eye
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(w * 0.7 + eyeOffsetX, eyeY + eyeOffsetY),
          width: eyeW,
          height: eyeH,
        ),
        Radius.circular(eyeW / 2),
      ),
      eyePaint,
    );

    // 4. Draw Smile / Bottom Curve
    final smilePath = Path()
      ..moveTo(w * 0.25, h * 0.75)
      ..quadraticBezierTo(w * 0.5, h * 0.9, w * 0.75, h * 0.75);
    canvas.drawPath(smilePath, paint);
  }

  @override
  bool shouldRepaint(_FaceIdPainter old) =>
      old.animation != animation || old.isAnalyzing != isAnalyzing;
}
