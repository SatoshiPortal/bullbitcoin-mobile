import 'dart:math' as math;
import 'dart:ui';

import '../theme/payment_animation_palette.dart';

enum BullPaymentNetwork { bitcoin, lightning, liquid, ark }

enum BullPaymentPhase { initiated, sending, success, failed }

/// Renders the reference diagrams in the 336 × 696 canvas coordinate space.
class PaymentScenes {
  void paint(
    Canvas canvas,
    Size size, {
    required BullPaymentNetwork network,
    required BullPaymentPhase phase,
    required double elapsed,
    required double time,
    required double roll,
    required double springRoll,
    required PaymentAnimationPalette palette,
  }) {
    if (size.isEmpty) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawColor(palette.background, BlendMode.srcOver);
    final scale = math.min(size.width / 336, size.height / 696);
    canvas.translate(
      (size.width - 336 * scale) / 2,
      (size.height - 696 * scale) / 2,
    );
    canvas.scale(scale);
    final gx = math.sin(roll);
    final gy = math.cos(roll);
    _chrome(canvas, phase, gx, palette);
    switch (network) {
      case BullPaymentNetwork.bitcoin:
        _bitcoin(canvas, phase, elapsed, time, gx, gy, springRoll, palette);
      case BullPaymentNetwork.lightning:
        _lightning(canvas, phase, elapsed, gx, palette);
      case BullPaymentNetwork.liquid:
        _liquid(canvas, phase, elapsed, time, springRoll, palette);
      case BullPaymentNetwork.ark:
        _ark(canvas, phase, elapsed, time, gx, gy, springRoll, palette);
    }
    canvas.restore();
  }
}

double _progress(double v, double a, double b) =>
    ((v - a) / (b - a)).clamp(0.0, 1.0);
double _ease(double t) {
  t = t.clamp(0.0, 1.0);
  return t < .5 ? 2 * t * t : 1 - math.pow(-2 * t + 2, 2) / 2;
}

double _out(double t) => 1 - math.pow(1 - t.clamp(0.0, 1.0), 3).toDouble();
double _lerp(double a, double b, double t) => a + (b - a) * t;
Color _alpha(Color c, double a) => c.withValues(alpha: a.clamp(0.0, 1.0));
Paint _fill(Color c) => Paint()..color = c;
Paint _stroke(Color c, double width) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.butt
  ..strokeJoin = StrokeJoin.miter;
void _line(Canvas c, List<Offset> points, Color color, double width) {
  if (points.isEmpty) return;
  final path = Path()..moveTo(points.first.dx, points.first.dy);
  for (final p in points.skip(1)) {
    path.lineTo(p.dx, p.dy);
  }
  c.drawPath(path, _stroke(color, width));
}

void _text(
  Canvas c,
  String text,
  Offset at,
  Color color, {
  double size = 10,
  bool right = false,
}) {
  final builder =
      ParagraphBuilder(
          ParagraphStyle(
            fontFamily: 'League Spartan',
            fontSize: size,
            fontWeight: FontWeight.w700,
          ),
        )
        ..pushStyle(TextStyle(color: color))
        ..addText(text);
  final paragraph = builder.build()
    ..layout(const ParagraphConstraints(width: 200));
  c.drawParagraph(
    paragraph,
    Offset(at.dx - (right ? paragraph.longestLine : 0), at.dy - size),
  );
}

void _chrome(
  Canvas c,
  BullPaymentPhase phase,
  double gx,
  PaymentAnimationPalette p,
) {
  final grid = Path();
  for (var x = gx * 10; x < 336; x += 24) {
    grid.moveTo(x + .5, 0);
    grid.lineTo(x + .5, 696);
  }
  for (var y = 0.0; y < 696; y += 24) {
    grid.moveTo(0, y + .5);
    grid.lineTo(336, y + .5);
  }
  c.drawPath(grid, _stroke(_alpha(p.foreground, .045), 1));
  final corners = [
    (34.0, 170.0, 1.0, 1.0),
    (302.0, 170.0, -1.0, 1.0),
    (34.0, 470.0, 1.0, -1.0),
    (302.0, 470.0, -1.0, -1.0),
  ];
  for (var i = 0; i < corners.length; i++) {
    final (x, y, sx, sy) = corners[i];
    _line(
      c,
      [Offset(x, y + sy * 18), Offset(x, y), Offset(x + sx * 18, y)],
      i == 3 && phase == BullPaymentPhase.sending
          ? p.failure
          : _alpha(p.foreground, .55),
      2,
    );
  }
  _text(c, 'NODE // LOCAL', const Offset(34, 162), _alpha(p.gray, .9));
  _text(
    c,
    phase.name.toUpperCase(),
    const Offset(302, 162),
    _alpha(p.gray, .9),
    right: true,
  );
}

void _badge(
  Canvas c,
  BullPaymentPhase phase,
  double elapsed,
  double start,
  PaymentAnimationPalette p,
) {
  if (phase != BullPaymentPhase.success && phase != BullPaymentPhase.failed) {
    return;
  }
  final t = _progress(elapsed, start, start + .5);
  if (t <= 0) return;
  final a = _out(t), ok = phase == BullPaymentPhase.success;
  c.save();
  c.translate(168, 320);
  c.scale(_lerp(.94, 1, a));
  c.drawRect(
    const Rect.fromLTWH(-32, -32, 64, 64),
    _fill(_alpha(ok ? p.foreground : p.failure, a)),
  );
  final path = Path();
  if (ok) {
    path.moveTo(-14, 1);
    path.lineTo(-4, 11);
    path.lineTo(15, -10);
  } else {
    path.moveTo(-12, -12);
    path.lineTo(12, 12);
    path.moveTo(12, -12);
    path.lineTo(-12, 12);
  }
  final q = _progress(t, .25, .9);
  for (final metric in path.computeMetrics()) {
    c.drawPath(
      metric.extractPath(0, math.min(metric.length, 60 * q)),
      _stroke(_alpha(ok ? p.background : const Color(0xffffffff), a), 5)
        ..strokeCap = StrokeCap.square,
    );
  }
  c.restore();
}

void _bitcoin(
  Canvas c,
  BullPaymentPhase phase,
  double e,
  double time,
  double gx,
  double gy,
  double spring,
  PaymentAnimationPalette p,
) {
  final failed = phase == BullPaymentPhase.failed,
      success = phase == BullPaymentPhase.success;
  final fall = failed ? math.max(0.0, e - .6) : 0.0;
  final x = 168 + gx * 2600 / 18 + gx * 900 * fall * fall;
  final y = 320 + gy * 900 * fall * fall;
  final rot =
      .6 +
      time *
          (phase == BullPaymentPhase.sending
              ? .7
              : phase == BullPaymentPhase.initiated
              ? .15
              : success
              ? .7 * (1 - _progress(e, 0, 1))
              : .1);
  final rx = -.55 + spring * .3;
  Offset project(int i) {
    final vx = i < 4 ? -1.0 : 1.0,
        vy = i % 4 < 2 ? -1.0 : 1.0,
        vz = i.isEven ? -1.0 : 1.0;
    final xx = vx * math.cos(rot) + vz * math.sin(rot),
        z = -vx * math.sin(rot) + vz * math.cos(rot);
    return Offset(x + xx * 52, y + (vy * math.cos(rx) - z * math.sin(rx)) * 52);
  }

  if (phase == BullPaymentPhase.sending || success) {
    final ends = [
      const Offset(0, 250),
      const Offset(336, 230),
      const Offset(0, 420),
      const Offset(336, 410),
    ];
    for (var i = 0; i < ends.length; i++) {
      final end = ends[i], sign = end.dx == 0 ? -1.0 : 1.0;
      final a = Offset(x + sign * 52, y + (i < 2 ? -20 : 20));
      final mx = _lerp(a.dx, end.dx, .45);
      final pts = [
        a,
        Offset(mx, a.dy),
        Offset(mx + sign * (end.dy - a.dy).abs(), end.dy),
        end,
      ];
      _line(c, pts, _alpha(p.foreground, .22), 1);
      if (!success) {
        final seg = ((e * .8 + i * .27) % 1) * 3, j = seg.floor().clamp(0, 2);
        final point = Offset.lerp(pts[j], pts[j + 1], seg - j) ?? pts[j];
        c.drawRect(
          Rect.fromCenter(center: point, width: 6, height: 6),
          _fill(p.bitcoin),
        );
      }
    }
  }
  final grey = failed ? _progress(e, 0, .6) : 0.0, lineAlpha = .85 - grey * .5;
  final fill = success ? _ease(_progress(e, .2, 1.1)) * .92 : 0.0;
  for (final face in [(1, 3, 5, 1.0), (4, 5, 6, .75), (0, 1, 4, .55)]) {
    final a = project(face.$1),
        b = project(face.$2),
        d = project(face.$3),
        cc = b + d - a;
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(cc.dx, cc.dy)
      ..lineTo(d.dx, d.dy)
      ..close();
    if (fill > 0) c.drawPath(path, _fill(_alpha(p.foreground, fill * face.$4)));
    for (var k = 1; k < 3; k++) {
      final t = k / 3;
      _line(
        c,
        [Offset.lerp(a, b, t) ?? a, Offset.lerp(d, cc, t) ?? d],
        _alpha(p.foreground, lineAlpha * .55),
        1,
      );
      _line(
        c,
        [Offset.lerp(a, d, t) ?? a, Offset.lerp(b, cc, t) ?? b],
        _alpha(p.foreground, lineAlpha * .55),
        1,
      );
    }
  }
  final edges = [
    (0, 1),
    (0, 2),
    (0, 4),
    (1, 3),
    (1, 5),
    (2, 3),
    (2, 6),
    (3, 7),
    (4, 5),
    (4, 6),
    (5, 7),
    (6, 7),
  ];
  final draw = phase == BullPaymentPhase.initiated ? _ease(e / 1.4) : 1.0;
  for (var i = 0; i < edges.length; i++) {
    final a = project(edges[i].$1),
        b = project(edges[i].$2),
        t = (draw * 12 - i).clamp(0.0, 1.0);
    if (t > 0) {
      _line(
        c,
        [a, Offset.lerp(a, b, t) ?? a],
        _alpha(
          Color.lerp(p.foreground, p.gray, grey) ?? p.foreground,
          lineAlpha,
        ),
        1.5,
      );
    }
  }
  _badge(c, phase, e, success ? 1.1 : 1.5, p);
}

List<Offset> _trace(double gx) {
  final ox = gx * 14;
  return [
    Offset(168 + ox * .2, 520),
    Offset(168 + ox * .2, 450),
    Offset(98 + ox * .5, 380),
    Offset(98 + ox * .6, 300),
    Offset(208 + ox * .8, 240),
    Offset(208 + ox, 190),
  ];
}

double _length(List<Offset> points) {
  var length = 0.0;
  for (var i = 1; i < points.length; i++) {
    length += (points[i] - points[i - 1]).distance;
  }
  return length;
}

Offset _point(List<Offset> points, double distance) {
  for (var i = 1; i < points.length; i++) {
    final len = (points[i] - points[i - 1]).distance;
    if (distance <= len) {
      return Offset.lerp(points[i - 1], points[i], distance / len) ?? points[i];
    }
    distance -= len;
  }
  return points.last;
}

void _traceTo(
  Canvas c,
  List<Offset> points,
  double distance,
  Color color,
  double width,
) {
  final result = <Offset>[points.first];
  for (var i = 1; i < points.length; i++) {
    final len = (points[i] - points[i - 1]).distance;
    if (distance >= len) {
      result.add(points[i]);
      distance -= len;
    } else {
      result.add(
        Offset.lerp(points[i - 1], points[i], distance / len) ?? points[i],
      );
      break;
    }
  }
  _line(c, result, color, width);
}

void _lightning(
  Canvas c,
  BullPaymentPhase phase,
  double e,
  double gx,
  PaymentAnimationPalette p,
) {
  final points = _trace(gx), length = _length(points);
  final base = phase == BullPaymentPhase.initiated ? _ease(e / 1.5) : 1.0;
  final lit = phase == BullPaymentPhase.success
      ? _ease(_progress(e, 0, .9))
      : 0.0;
  final broken = phase == BullPaymentPhase.failed && e > .5;
  _line(
    c,
    [
      const Offset(40, 520),
      const Offset(40, 400),
      const Offset(90, 350),
      const Offset(90, 260),
    ],
    _alpha(p.foreground, .12),
    1,
  );
  _line(
    c,
    [const Offset(296, 500), const Offset(296, 330), const Offset(246, 280)],
    _alpha(p.foreground, .12),
    1,
  );
  _traceTo(
    c,
    points,
    broken ? _length(points.sublist(0, 4)) : length * base,
    _alpha(p.foreground, .28),
    2,
  );
  if (broken) {
    final tail = points.sublist(3),
        len = _length(tail),
        color = _alpha(p.gray, math.sin(e * 40) > 0 ? .25 : .08);
    for (var d = 0.0; d < len; d += 8) {
      _line(c, [_point(tail, d), _point(tail, math.min(d + 3, len))], color, 2);
    }
  }
  if (lit > 0) {
    _traceTo(c, points, length * lit, _alpha(p.foreground, .95), 2.5);
  }
  for (var i = 0; i < points.length; i++) {
    final rect = Rect.fromCenter(center: points[i], width: 10, height: 10);
    c.drawRect(rect, _fill(p.background));
    c.drawRect(
      rect,
      _stroke(
        broken && i == 3
            ? p.failure
            : _alpha(p.foreground, lit * 5 >= i && lit > 0 ? 1 : .6),
        1.5,
      ),
    );
  }
  if (phase == BullPaymentPhase.sending ||
      phase == BullPaymentPhase.initiated) {
    final n = phase == BullPaymentPhase.sending ? 3 : 1,
        speed = n == 3 ? .55 : .3;
    for (var k = 0; k < n; k++) {
      final d = ((e * speed + k / n) % 1) * length * base,
          a = _point(points, math.max(0, d - 26)),
          b = _point(points, d);
      if ((b - a).distance > 0) {
        c.drawLine(
          a,
          b,
          _stroke(p.lightning, 3)
            ..shader = Gradient.linear(a, b, [
              _alpha(p.lightning, 0),
              _alpha(p.lightning, .9),
            ]),
        );
      }
      c.drawRect(
        Rect.fromCenter(center: b, width: 6, height: 6),
        _fill(p.lightning),
      );
    }
  }
  _badge(c, phase, e, phase == BullPaymentPhase.success ? 1.0 : 1.4, p);
}

void _liquid(
  Canvas c,
  BullPaymentPhase phase,
  double e,
  double time,
  double spring,
  PaymentAnimationPalette p,
) {
  // The API carries no previous level; approximate the reference's spring from its initial pose.
  final target = switch (phase) {
    BullPaymentPhase.initiated => .22,
    BullPaymentPhase.sending => .46 + .03 * math.sin(e * 1.3),
    BullPaymentPhase.success => 1.0,
    BullPaymentPhase.failed => .04,
  };
  final initial = switch (phase) {
    BullPaymentPhase.initiated => .02,
    BullPaymentPhase.sending => .22,
    BullPaymentPhase.success || BullPaymentPhase.failed => .46,
  };
  final rate = phase == BullPaymentPhase.success
      ? 1 + e * 1.5
      : phase == BullPaymentPhase.failed
      ? 1.4
      : 1.6;
  final level = target + (initial - target) * math.exp(-e * rate);
  final ampTarget = phase == BullPaymentPhase.sending
      ? 5.0
      : phase == BullPaymentPhase.initiated
      ? 2.0
      : 1.0;
  final amp =
      ampTarget +
      ((phase == BullPaymentPhase.initiated ? 1.0 : 2.0) - ampTarget) *
          math.exp(-3 * e);
  final grey = phase == BullPaymentPhase.failed ? _progress(e, 0, 1) : 0.0;
  c.drawRect(
    const Rect.fromLTWH(70.5, 190.5, 196, 260),
    _stroke(_alpha(p.foreground, .5), 1.5),
  );
  for (var k = 0; k <= 4; k++) {
    final y = 450.0 - 260 * k / 4;
    c.drawRect(Rect.fromLTWH(62, y, 6, 1), _fill(_alpha(p.gray, .9)));
    _text(c, '${k * 25}', Offset(40, y + 3), _alpha(p.gray, .9));
  }
  c.save();
  c.clipRect(const Rect.fromLTWH(72, 192, 193, 257));
  c.translate(168, 450 - level * 260);
  c.rotate(spring);
  double surface(double x) =>
      amp * math.sin(x * .05 + time * 2) +
      amp * .5 * math.sin(x * .11 - time * 2.6);
  for (var y = 0.0; y < 520; y += 6) {
    final points = <Offset>[];
    for (var x = -200.0; x <= 200; x += 8) {
      points.add(Offset(x, y + (y < 18 ? surface(x) * (1 - y / 18) : 0)));
    }
    final color = y == 0
        ? (grey > 0
              ? _alpha(p.gray, .9 - grey * .4)
              : _alpha(p.foreground, .85))
        : (phase == BullPaymentPhase.success
              ? _alpha(p.foreground, _lerp(.35, .9, _progress(e, .6, 1.4)))
              : _alpha(grey > 0 ? p.gray : p.foreground, .35));
    _line(c, points, color, y == 0 ? 2 : 1);
  }
  if (phase == BullPaymentPhase.initiated ||
      phase == BullPaymentPhase.sending) {
    final points = <Offset>[];
    for (var x = -200.0; x <= 200; x += 8) {
      points.add(Offset(x, surface(x) - 3));
    }
    _line(c, points, _alpha(p.liquid, .9), 2);
  }
  c.restore();
  _text(
    c,
    '${(level.clamp(0.0, 1.0) * 100).round()}%',
    const Offset(266, 182),
    _alpha(p.foreground, .9),
    size: 12,
    right: true,
  );
  _badge(c, phase, e, phase == BullPaymentPhase.success ? 1.2 : 1.6, p);
}

void _ark(
  Canvas c,
  BullPaymentPhase phase,
  double e,
  double time,
  double gx,
  double gy,
  double spring,
  PaymentAnimationPalette p,
) {
  final cx = 168 + gx * 16, cy = 320 + (gy - 1) * 10;
  final lock = phase == BullPaymentPhase.success
      ? _ease(_progress(e, 0, 1))
      : 0.0;
  final draw = phase == BullPaymentPhase.initiated ? _ease(e / 1.4) : 1.0;
  final mult = phase == BullPaymentPhase.initiated
      ? .4
      : phase == BullPaymentPhase.sending
      ? 1.4
      : phase == BullPaymentPhase.failed
      ? .2
      : 1 - lock;
  final radii = [110.0, 78.0, 46.0],
      gaps = [6, 4, 3],
      initial = [0.0, 1.2, 2.4],
      velocities = [.5, -.35, .22];
  final angles = List.generate(
    3,
    (i) => _lerp(
      initial[i] + velocities[i] * mult * time,
      -math.pi / 2 + .09,
      lock,
    ),
  );
  for (var i = 0; i < 3; i++) {
    if (phase == BullPaymentPhase.failed && i == 0 && e > .5) continue;
    final opacity = (draw * 3 - i).clamp(0.0, 1.0), seg = 2 * math.pi / gaps[i];
    final color = phase == BullPaymentPhase.failed
        ? _alpha(p.gray, .6 * opacity)
        : _alpha(
            p.foreground,
            (.35 +
                    .5 *
                        (lock > 0
                            ? lock
                            : i == 2
                            ? .3
                            : 0)) *
                opacity,
          );
    for (var j = 0; j < gaps[i]; j++) {
      c.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: radii[i]),
        angles[i] + j * seg + .09,
        seg - .18,
        false,
        _stroke(color, i == 0 ? 1.5 : 2),
      );
    }
  }
  for (var k = 0; k < 48; k++) {
    final a = k / 48 * math.pi * 2, end = k % 4 == 0 ? 134 : 128;
    _line(
      c,
      [
        Offset(cx + math.cos(a) * 124, cy + math.sin(a) * 124),
        Offset(cx + math.cos(a) * end, cy + math.sin(a) * end),
      ],
      _alpha(p.foreground, .2),
      1,
    );
  }
  if (phase == BullPaymentPhase.initiated ||
      phase == BullPaymentPhase.sending) {
    final k = (e * .35) % 1,
        r = _lerp(110, 0, _ease(k)),
        a = angles[1] + k * 4,
        point = Offset(cx + math.cos(a) * r, cy + math.sin(a) * r);
    _line(c, [point, Offset(cx, cy)], _alpha(p.ark, .4), 1);
    c.drawRect(
      Rect.fromCenter(center: point, width: 6, height: 6),
      _fill(p.ark),
    );
  }
  final core = Rect.fromCenter(center: Offset(cx, cy), width: 20, height: 20);
  c.drawRect(
    core,
    _fill(lock > 0 ? _alpha(p.foreground, lock * .95) : p.background),
  );
  c.drawRect(core, _stroke(_alpha(p.foreground, .7), 1.5));
  if (phase == BullPaymentPhase.failed && e > .5) {
    final t = e - .5;
    for (var i = 0; i < 6; i++) {
      final a = angles[0] + (i + .5) * math.pi / 3,
          dx = gx * 450 * t * t + math.sin(i * 7) * 40 * t,
          dy = gy * 450 * t * t - 30 * t;
      c.save();
      c.translate(cx + dx, cy + dy);
      c.rotate(math.sin(i * 3) * t);
      c.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: 110),
        a - .42,
        .84,
        false,
        _stroke(_alpha(p.gray, .7), 1.5),
      );
      c.restore();
    }
  }
  _badge(c, phase, e, phase == BullPaymentPhase.success ? 1.1 : 1.6, p);
}
