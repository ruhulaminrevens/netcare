import 'dart:math' as math;

import 'package:flutter/material.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF0D1B2A) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: dark ? const Color(0xFF1D3448) : const Color(0xFFDCE8EC),
        ),
        boxShadow: dark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x100B2840),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
      ),
      child: child,
    );
  }
}

class MetricTile extends StatelessWidget {
  const MetricTile({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    this.color = const Color(0xFF31D6C4),
    super.key,
  });

  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(.13),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 3),
                RichText(
                  text: TextSpan(
                    style: DefaultTextStyle.of(context).style,
                    children: [
                      TextSpan(
                        text: value,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      TextSpan(
                        text: ' $unit',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    required this.label,
    required this.positive,
    super.key,
  });

  final String label;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final color = positive ? const Color(0xFF31D6C4) : const Color(0xFFFF6B6B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class SpeedGauge extends StatelessWidget {
  const SpeedGauge({
    required this.value,
    required this.label,
    required this.progress,
    this.running = false,
    super.key,
  });

  final double value;
  final String label;
  final double progress;
  final bool running;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      height: 210,
      child: CustomPaint(
        painter: _GaugePainter(
          progress: running ? progress : _displayProgress(value),
          background: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1B3043)
              : const Color(0xFFDDE9ED),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 42),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  running ? '${(progress * 100).round()}%' : value.toStringAsFixed(1),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -2,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  running ? label : 'Mbps',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _displayProgress(double speed) {
    if (speed <= 0) return .02;
    return (math.log(speed + 1) / math.log(1001)).clamp(0.03, 1);
  }
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter({required this.progress, required this.background});

  final double progress;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height * .67),
      radius: size.width * .38,
    );
    const start = math.pi * .82;
    const sweep = math.pi * 1.36;
    final basePaint = Paint()
      ..color = background
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 18;
    final activePaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF31D6C4), Color(0xFF35A7FF)],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 18;
    canvas.drawArc(rect, start, sweep, false, basePaint);
    canvas.drawArc(rect, start, sweep * progress.clamp(0, 1), false, activePaint);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.background != background;
}
