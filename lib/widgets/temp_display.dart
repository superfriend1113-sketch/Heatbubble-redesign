import 'package:flutter/material.dart';
import '../services/unit_service.dart';

class TempDisplay extends StatefulWidget {
  final double temperature;
  final Color color;

  const TempDisplay({
    super.key,
    required this.temperature,
    required this.color,
  });

  @override
  State<TempDisplay> createState() => _TempDisplayState();
}

class _TempDisplayState extends State<TempDisplay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: UnitService.instance,
      builder: (context, _) {
        final us = UnitService.instance;
        final displayTemp = us.convert(widget.temperature);
        return Center(
          child: _AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  final tempFontSize = (w * 0.29).clamp(72.0, 110.0);
                  final degFontSize = (tempFontSize * 0.33).clamp(24.0, 36.0);

                  return Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: OverflowBox(
                          maxWidth: 300,
                          maxHeight: 300,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: widget.color.withAlpha(
                                    (30 * _pulseAnimation.value).round(),
                                  ),
                                  blurRadius: 120,
                                  spreadRadius: 50,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: displayTemp, end: displayTemp),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          final formatted = value.toStringAsFixed(1);
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                formatted,
                                style: TextStyle(
                                  color: widget.color,
                                  fontSize: tempFontSize,
                                  fontWeight: FontWeight.w200,
                                  letterSpacing: -3,
                                  height: 1.0,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Text(
                                  us.symbol,
                                  style: TextStyle(
                                    color: widget.color,
                                    fontSize: degFontSize,
                                    fontWeight: FontWeight.w300,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext context, Widget? child) builder;

  const _AnimatedBuilder({
    required Animation<double> animation,
    required this.builder,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    return builder(context, null);
  }
}
