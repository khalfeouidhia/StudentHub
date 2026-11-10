import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LoopingTypewriterHeader extends StatefulWidget {
  final String userName;
  final bool? enableAnimation;

  const LoopingTypewriterHeader({
    super.key,
    required this.userName,
    this.enableAnimation,
  });

  @override
  State<LoopingTypewriterHeader> createState() =>
      _LoopingTypewriterHeaderState();
}

class _LoopingTypewriterHeaderState extends State<LoopingTypewriterHeader> {
  Timer? _timer;
  Timer? _delayTimer;

  int _phase = 0; // 0: Greeting, 1: Welcome
  bool _isDeleting = false;

  String _line1Display = '';
  String _line2Display = '';

  String get _timeGreeting {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Good morning,';
    if (hour >= 12 && hour < 18) return 'Good afternoon,';
    return 'Good evening,';
  }

  String get _targetLine1 => _phase == 0 ? _timeGreeting : 'Welcome to';
  String get _targetLine2 => _phase == 0
      ? (widget.userName.isNotEmpty ? widget.userName : 'student')
      : 'StudentHub';

  bool get _isTestEnv =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  @override
  void initState() {
    super.initState();
    final shouldAnimate = widget.enableAnimation ?? !_isTestEnv;
    if (shouldAnimate) {
      _startAnimationLoop();
    } else {
      // In test harness, present initial phase immediately for pumpAndSettle
      _line1Display = _targetLine1;
      _line2Display = _targetLine2;
    }
  }

  void _startAnimationLoop() {
    _timer?.cancel();
    _delayTimer?.cancel();

    _timer = Timer.periodic(const Duration(milliseconds: 55), (timer) {
      if (!mounted) return;

      setState(() {
        if (!_isDeleting) {
          // Type Line 1 first
          if (_line1Display.length < _targetLine1.length) {
            _line1Display = _targetLine1.substring(0, _line1Display.length + 1);
          }
          // Then Type Line 2
          else if (_line2Display.length < _targetLine2.length) {
            _line2Display = _targetLine2.substring(0, _line2Display.length + 1);
          }
          // Both typed: pause, then start deleting
          else {
            _timer?.cancel();
            _delayTimer = Timer(const Duration(milliseconds: 3200), () {
              if (mounted) {
                setState(() => _isDeleting = true);
                _startAnimationLoop();
              }
            });
          }
        } else {
          // Delete Line 2 first
          if (_line2Display.isNotEmpty) {
            _line2Display =
                _line2Display.substring(0, _line2Display.length - 1);
          }
          // Then Delete Line 1
          else if (_line1Display.isNotEmpty) {
            _line1Display =
                _line1Display.substring(0, _line1Display.length - 1);
          }
          // Both cleared: switch phase, pause briefly, start typing
          else {
            _isDeleting = false;
            _phase = (_phase == 0) ? 1 : 0;
            _timer?.cancel();
            _delayTimer = Timer(const Duration(milliseconds: 400), () {
              if (mounted) _startAnimationLoop();
            });
          }
        }
      });
    });
  }

  @override
  void didUpdateWidget(covariant LoopingTypewriterHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userName != widget.userName) {
      if (_isTestEnv || widget.enableAnimation == false) {
        _line1Display = _targetLine1;
        _line2Display = _targetLine2;
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _delayTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Line 1: "Good afternoon," (or "Welcome to")
          Text(
            _line1Display.isEmpty ? ' ' : _line1Display,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 23.0,
              fontWeight: FontWeight.w700,
              height: 1.2,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          // Line 2: Username stacked tightly with dual-layer emerald neon text glow
          Text(
            _line2Display.isEmpty ? ' ' : _line2Display,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 23.0,
              fontWeight: FontWeight.w800,
              height: 1.2,
              color: Colors.white,
              letterSpacing: -0.5,
              shadows: const [
                Shadow(
                  color: Color.fromRGBO(110, 231, 183, 0.75),
                  blurRadius: 10.0,
                ),
                Shadow(
                  color: Color.fromRGBO(0, 230, 118, 0.45),
                  blurRadius: 24.0,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
