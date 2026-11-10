import 'package:flutter/material.dart';
import '../../features/home/widgets/looping_typewriter_header.dart';

/// Premium glowing typewriter greeting widget integrating LoopingTypewriterHeader.
class GlowingTypewriterGreeting extends StatelessWidget {
  final String userName;
  final bool? enableAnimation;

  const GlowingTypewriterGreeting({
    super.key,
    required this.userName,
    this.enableAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return LoopingTypewriterHeader(
      userName: userName,
      enableAnimation: enableAnimation,
    );
  }
}
