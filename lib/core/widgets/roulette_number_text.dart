import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Dual-tone roulette/odometer number widget with vertical rolling reel animation.
class RouletteNumberText extends StatefulWidget {
  final double value;
  final String? prefix;
  final String? suffix;
  final int decimalDigits;
  final TextStyle? wholeStyle;
  final TextStyle? decimalStyle;
  final TextStyle? suffixStyle;
  final double decimalGap;
  final double suffixGap;
  final bool isHeader;
  final Duration duration;
  final Curve curve;
  final CrossAxisAlignment crossAxisAlignment;
  final bool thousandsSeparator;

  const RouletteNumberText({
    super.key,
    double? value,
    double? amount,
    this.prefix,
    this.suffix,
    this.decimalDigits = 3,
    TextStyle? wholeStyle,
    TextStyle? integerStyle,
    this.decimalStyle,
    this.suffixStyle,
    this.decimalGap = 0.0,
    this.suffixGap = 0.0,
    this.isHeader = false,
    this.duration = const Duration(milliseconds: 1200),
    this.curve = Curves.easeOutCubic,
    this.crossAxisAlignment = CrossAxisAlignment.end,
    this.thousandsSeparator = false,
  })  : value = value ?? amount ?? 0.0,
        wholeStyle = wholeStyle ?? integerStyle;

  @override
  State<RouletteNumberText> createState() => _RouletteNumberTextState();
}

class _RouletteNumberTextState extends State<RouletteNumberText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late double _previousValue;
  bool _isFirstMount = true;

  @override
  void initState() {
    super.initState();
    _previousValue = widget.value;
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    );

    if (widget.duration > Duration.zero) {
      _controller.forward().then((_) {
        if (mounted) {
          setState(() {
            _isFirstMount = false;
          });
        }
      });
    } else {
      _controller.value = 1.0;
      _isFirstMount = false;
    }
  }

  @override
  void didUpdateWidget(RouletteNumberText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _previousValue = oldWidget.value;
      _isFirstMount = false;
      if (widget.duration > Duration.zero) {
        _controller.reset();
        _controller.forward();
      } else {
        _controller.value = 1.0;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Size _measureCharSize(TextStyle style, BuildContext context) {
    final textScaler =
        MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling;
    final textPainter = TextPainter(
      text: TextSpan(text: '0', style: style),
      textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
      textScaler: textScaler,
    )..layout();
    final size = textPainter.size;
    return Size(
      size.width > 0 ? size.width : 14.0,
      size.height > 0 ? size.height : 26.0,
    );
  }

  List<int> _buildDigitSequence(int from, int to, int extraRotations) {
    final list = <int>[from];
    var current = from;
    int forwardSteps = (to - from) % 10;
    if (forwardSteps < 0) {
      forwardSteps += 10;
    }
    final totalSteps = forwardSteps + (extraRotations * 10);
    for (int step = 0; step < totalSteps; step++) {
      current = (current + 1) % 10;
      list.add(current);
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveWholeStyle = TextStyle(
      color: widget.isHeader ? AppColors.surfaceWhite : AppColors.darkForest,
      fontWeight: FontWeight.w700,
      fontSize: 22.0,
      fontFeatures: const [FontFeature.tabularFigures()],
    ).merge(widget.wholeStyle).copyWith(
      fontFeatures: [
        ...?widget.wholeStyle?.fontFeatures,
        const FontFeature.tabularFigures(),
      ],
    );

    final effectiveDecimalStyle = TextStyle(
      color: widget.isHeader ? AppColors.sandCream : AppColors.softSage,
      fontWeight: FontWeight.w500,
      fontSize: (effectiveWholeStyle.fontSize ?? 22.0) * 0.9,
      fontFeatures: const [FontFeature.tabularFigures()],
    ).merge(widget.decimalStyle).copyWith(
      fontFeatures: [
        ...?widget.decimalStyle?.fontFeatures,
        const FontFeature.tabularFigures(),
      ],
    );

    if (!widget.value.isFinite) {
      return Text('0.000', style: effectiveWholeStyle);
    }

    final isNegative = widget.value < 0;
    final effectivePrefix = widget.prefix ?? (isNegative ? '-' : '');
    final absCurrent = widget.value.abs();
    final absPrev = _previousValue.abs();

    final currentStr = absCurrent.toStringAsFixed(widget.decimalDigits);
    final prevStr = absPrev.toStringAsFixed(widget.decimalDigits);

    final currentParts = currentStr.split('.');
    final currentWhole = currentParts[0];
    final currentDecimals = currentParts.length > 1 ? currentParts[1] : '';

    final prevParts = prevStr.split('.');
    final prevWhole = prevParts[0];
    final prevDecimals = prevParts.length > 1 ? prevParts[1] : '';

    final wholeSize = _measureCharSize(effectiveWholeStyle, context);
    final decimalSize = _measureCharSize(effectiveDecimalStyle, context);

    final extraSpins = _isFirstMount && widget.duration > Duration.zero ? 1 : 0;

    // Build whole digit reels
    final paddedPrevWhole = prevWhole.length > currentWhole.length
        ? prevWhole.substring(prevWhole.length - currentWhole.length)
        : prevWhole.padLeft(currentWhole.length, '0');
    final wholeSequences = <List<int>>[];
    for (int i = 0; i < currentWhole.length; i++) {
      final start = _isFirstMount ? 0 : (int.tryParse(paddedPrevWhole[i]) ?? 0);
      final target = int.tryParse(currentWhole[i]) ?? 0;
      wholeSequences.add(_buildDigitSequence(start, target, extraSpins));
    }

    // Build decimal digit reels
    final decimalSequences = <List<int>>[];
    for (int j = 0; j < widget.decimalDigits; j++) {
      final start = _isFirstMount
          ? 0
          : (j < prevDecimals.length
              ? (int.tryParse(prevDecimals[j]) ?? 0)
              : 0);
      final target = j < currentDecimals.length
          ? (int.tryParse(currentDecimals[j]) ?? 0)
          : 0;
      decimalSequences.add(_buildDigitSequence(start, target, extraSpins));
    }

    String formattedWhole = currentWhole;
    if (widget.thousandsSeparator && currentWhole.length > 3) {
      formattedWhole = currentWhole.replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      );
    }

    final fullLabel = '$effectivePrefix$formattedWhole'
        '${widget.decimalDigits > 0 ? '.$currentDecimals' : ''}'
        '${widget.suffix ?? ''}';

    final wholeChildren = <Widget>[];
    for (int i = 0; i < wholeSequences.length; i++) {
      wholeChildren.add(
        _DigitReel(
          sequence: wholeSequences[i],
          animation: _animation,
          style: effectiveWholeStyle,
          height: wholeSize.height,
          width: wholeSize.width,
        ),
      );
      if (widget.thousandsSeparator) {
        final digitsRemaining = wholeSequences.length - 1 - i;
        if (digitsRemaining > 0 && digitsRemaining % 3 == 0) {
          wholeChildren.add(
            SizedBox(
              height: wholeSize.height,
              child: Center(
                child: Text(',', style: effectiveWholeStyle),
              ),
            ),
          );
        }
      }
    }

    final effectiveSuffixStyle =
        effectiveDecimalStyle.merge(widget.suffixStyle).copyWith(
      fontFeatures: [
        ...?widget.suffixStyle?.fontFeatures,
        const FontFeature.tabularFigures(),
      ],
    );

    final wholePainter = TextPainter(
      text: TextSpan(text: '0', style: effectiveWholeStyle),
      textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
      textScaler: MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling,
    )..layout();
    final wholeBaseline =
        wholePainter.computeDistanceToActualBaseline(TextBaseline.alphabetic);

    final decimalPainter = TextPainter(
      text: TextSpan(text: '0', style: effectiveDecimalStyle),
      textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
      textScaler: MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling,
    )..layout();
    final decimalBaseline =
        decimalPainter.computeDistanceToActualBaseline(TextBaseline.alphabetic);

    String displaySuffix = widget.suffix ?? '';
    if (widget.suffixGap > 0 && displaySuffix.startsWith(' ')) {
      displaySuffix = displaySuffix.trimLeft();
    }

    final suffixPainter = TextPainter(
      text: TextSpan(
          text: displaySuffix.isNotEmpty ? displaySuffix : 'DT',
          style: effectiveSuffixStyle),
      textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
      textScaler: MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling,
    )..layout();
    final suffixBaseline =
        suffixPainter.computeDistanceToActualBaseline(TextBaseline.alphabetic);

    final useBaseline =
        widget.crossAxisAlignment == CrossAxisAlignment.baseline ||
            widget.isHeader;
    final decimalTopOffset = useBaseline
        ? (wholeBaseline - decimalBaseline).clamp(0.0, wholeSize.height)
        : 0.0;
    final suffixTopOffset = useBaseline
        ? (wholeBaseline - suffixBaseline).clamp(0.0, wholeSize.height)
        : 0.0;

    return Semantics(
      label: fullLabel,
      value: fullLabel,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            useBaseline ? CrossAxisAlignment.start : widget.crossAxisAlignment,
        children: [
          if (effectivePrefix.isNotEmpty)
            Text(effectivePrefix, style: effectiveWholeStyle),
          ...wholeChildren,
          if (widget.decimalDigits > 0) ...[
            if (widget.decimalGap > 0) SizedBox(width: widget.decimalGap),
            Padding(
              padding: EdgeInsets.only(top: decimalTopOffset),
              child: SizedBox(
                height: decimalSize.height,
                child: Center(
                  child: Text('.', style: effectiveDecimalStyle),
                ),
              ),
            ),
            for (int j = 0; j < decimalSequences.length; j++)
              Padding(
                padding: EdgeInsets.only(top: decimalTopOffset),
                child: _DigitReel(
                  sequence: decimalSequences[j],
                  animation: _animation,
                  style: effectiveDecimalStyle,
                  height: decimalSize.height,
                  width: decimalSize.width,
                ),
              ),
          ],
          if (displaySuffix.isNotEmpty) ...[
            if (widget.suffixGap > 0) SizedBox(width: widget.suffixGap),
            Padding(
              padding: EdgeInsets.only(top: suffixTopOffset),
              child: SizedBox(
                height: decimalSize.height,
                child: Center(
                  child: Text(displaySuffix, style: effectiveSuffixStyle),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DigitReel extends StatelessWidget {
  final List<int> sequence;
  final Animation<double> animation;
  final TextStyle style;
  final double height;
  final double width;

  const _DigitReel({
    required this.sequence,
    required this.animation,
    required this.style,
    required this.height,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    if (sequence.length <= 1) {
      return SizedBox(
        height: height,
        width: width,
        child: Center(
          child: Text(
            '${sequence.first}',
            style: style,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final totalScrollDistance = (sequence.length - 1) * height;

    return SizedBox(
      height: height,
      width: width,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final offset = -animation.value * totalScrollDistance;
            return Transform.translate(
              offset: Offset(0, offset),
              child: child,
            );
          },
          child: OverflowBox(
            minWidth: width,
            maxWidth: width,
            minHeight: 0,
            maxHeight: double.infinity,
            alignment: Alignment.topCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: sequence.map((digit) {
                return SizedBox(
                  height: height,
                  width: width,
                  child: Center(
                    child: Text(
                      '$digit',
                      style: style,
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }).toList(growable: false),
            ),
          ),
        ),
      ),
    );
  }
}
