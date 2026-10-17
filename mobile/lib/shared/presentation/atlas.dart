import 'package:flutter/material.dart';
import 'package:wanderplan/shared/presentation/theme/app_theme.dart';

/// The same schematic route drawn by frontend/src/components/atlas-art.tsx.
/// This is decorative artwork, never a geographical map.
class AtlasRouteArt extends StatelessWidget {
  const AtlasRouteArt({super.key});
  @override
  Widget build(BuildContext context) =>
      const ExcludeSemantics(child: CustomPaint(painter: _RoutePainter()));
}

class _RoutePainter extends CustomPainter {
  const _RoutePainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    // Match SVG preserveAspectRatio=xMidYMid slice.
    final scale = (size.width / 600).clamp(size.height / 300, double.infinity);
    canvas.translate(
      (size.width - 600 * scale) / 2,
      (size.height - 300 * scale) / 2,
    );
    canvas.scale(scale);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8
      ..color = Colors.white.withValues(alpha: .17);
    for (var i = 0; i < 6; i++) {
      canvas.drawPath(
        Path()
          ..moveTo(330 + i * 22, -40)
          ..cubicTo(170 + i * 20, 70, 650 - i * 14, 120, 420 + i * 12, 330),
        line,
      );
    }
    for (var i = 0; i < 3; i++) {
      canvas.drawPath(
        Path()
          ..moveTo(-40, 80 + i * 24)
          ..cubicTo(80, -10 + i * 28, 130, 240 + i * 16, 300, 300 + i * 20),
        line,
      );
    }
    for (final point in [
      const Offset(440, 45),
      const Offset(540, 245),
      const Offset(100, 40),
    ]) {
      canvas.drawLine(
        point - const Offset(12, 0),
        point + const Offset(12, 0),
        line,
      );
      canvas.drawLine(
        point - const Offset(0, 12),
        point + const Offset(0, 12),
        line,
      );
    }
    final route = Path()
      ..moveTo(310, 235)
      ..cubicTo(290, 175, 427, 199, 423, 140)
      ..cubicTo(419, 81, 480, 64, 520, 78);
    line
      ..strokeWidth = 1.4
      ..color = Colors.white.withValues(alpha: .65);
    for (final metric in route.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 11) {
        canvas.drawPath(
          metric.extractPath(d, (d + 5).clamp(0, metric.length)),
          line,
        );
      }
    }
    canvas.drawCircle(
      const Offset(310, 235),
      5,
      Paint()..color = Colors.white.withValues(alpha: .75),
    );
    canvas.drawCircle(
      const Offset(423, 140),
      4,
      Paint()..color = Colors.white.withValues(alpha: .75),
    );
    canvas.drawCircle(
      const Offset(520, 78),
      11,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0xFFECB394),
    );
    canvas.drawCircle(
      const Offset(520, 78),
      4,
      Paint()..color = const Color(0xFFECB394),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AtlasBrand extends StatelessWidget {
  const AtlasBrand({super.key});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        width: 27,
        height: 33,
        child: CustomPaint(
          painter: _MarkPainter(context.colors.ink, context.colors.accent),
        ),
      ),
      const SizedBox(width: 8),
      Flexible(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            'WanderPlan',
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              fontFamily: 'DM Sans',
              fontSize: 21,
              fontWeight: FontWeight.w600,
              letterSpacing: -1,
              color: context.colors.ink,
            ),
          ),
        ),
      ),
    ],
  );
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter(this.ink, this.accent);
  final Color ink, accent;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 34, size.height / 40);
    final p = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(const Rect.fromLTRB(3, 4, 31, 36), p);
    for (final x in [9.0, 25.0]) {
      canvas.drawLine(Offset(x, 0), Offset(x, 8), p);
      canvas.drawLine(Offset(x, 32), Offset(x, 40), p);
    }
    canvas.drawPath(
      Path()
        ..moveTo(10, 27)
        ..lineTo(15, 13)
        ..lineTo(18, 23)
        ..lineTo(24, 10),
      p,
    );
    canvas.drawCircle(const Offset(24, 10), 2.5, Paint()..color = accent);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MarkPainter old) =>
      old.ink != ink || old.accent != accent;
}

class FolioDivider extends StatelessWidget {
  const FolioDivider({super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 1,
    child: CustomPaint(painter: _Perforation(context.colors.line)),
  );
}

class _Perforation extends CustomPainter {
  const _Perforation(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 7) {
      canvas.drawLine(Offset(x, 0), Offset((x + 3).clamp(0, size.width), 0), p);
    }
  }

  @override
  bool shouldRepaint(covariant _Perforation old) => old.color != color;
}
