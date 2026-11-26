import 'dart:math' as math;
import 'dart:ui';

import '../../generated/l10n/bull_ui_localizations.dart';
import '../theme/payment_animation_palette.dart';
import 'bull_payment_progress.dart';
import 'payment_node_layout.dart';

/// The diagram played for a payment. [boltz] stages a swap through Boltz
/// (lockup, counter-lockup, claim); [payjoin] merges both parties' inputs.
///
/// [arkExit] draws an Ark unilateral exit: the round tree unrolls to the
/// chain, a timelock runs, then the claim lands on the base line.
enum BullPaymentNetwork {
  bitcoin,
  lightning,
  liquid,
  ark,
  boltz,
  payjoin,
  arkExit,
}

enum BullPaymentPhase { initiated, sending, success, failed }

/// Step progress as seen by the painter. Without caller steps ([tracked]
/// false) the scenes keep their decorative behaviour over three nominal steps.
class _Steps {
  final int count;
  final int done;
  final int? failed;
  final int? skipped;
  final BullPaymentRefund? refund;
  final List<String> labels;
  final bool tracked;
  final BullPaymentStepState currentState;

  const _Steps._(
    this.count,
    this.done,
    this.failed,
    this.skipped,
    this.refund,
    this.labels,
    this.tracked,
    this.currentState,
  );

  factory _Steps.of(
    BullPaymentPhase phase,
    int stepCount,
    int completed,
    int? failedAt,
    int? skippedAt,
    BullPaymentRefund? refund,
    List<String> labels,
    BullPaymentStepState currentState,
  ) {
    final tracked = stepCount > 0;
    final count = tracked ? stepCount : 3;
    final success = phase == BullPaymentPhase.success;
    final done = success
        ? count
        : tracked
        ? completed.clamp(0, count)
        : 0;
    // A failed step is marked in any phase: a swap whose funds are refundable
    // stays in progress but shows where it failed.
    final failed = failedAt != null
        ? failedAt.clamp(0, count - 1)
        : phase == BullPaymentPhase.failed
        ? done.clamp(0, count - 1)
        : null;
    final skipped = skippedAt == null || skippedAt >= count ? null : skippedAt;
    return _Steps._(
      count,
      done,
      failed,
      skipped,
      refund,
      labels,
      tracked,
      currentState,
    );
  }

  String label(int i) => i >= 0 && i < labels.length ? labels[i] : '';

  /// Role of node [i] for the scenes that draw one node per step.
  _NodeState node(int i, BullPaymentPhase phase) {
    if (failed == i) return _NodeState.failed;
    if (skipped == i) return _NodeState.skipped;
    // The terminal status is the only green one.
    if (tracked && phase == BullPaymentPhase.success && i == count - 1) {
      return _NodeState.confirmed;
    }
    if (i < done) return _NodeState.done;
    if (i == done && failed == null && phase != BullPaymentPhase.success) {
      return switch (currentState) {
        BullPaymentStepState.active => _NodeState.awaited,
        BullPaymentStepState.broadcast => _NodeState.broadcast,
        BullPaymentStepState.held => _NodeState.held,
      };
    }
    return _NodeState.later;
  }

  double get fraction => done / count;

  /// Whether stage [stage] (0-based) of [stages] equal stages is complete.
  bool reached(int stage, int stages) => done * stages >= (stage + 1) * count;

  /// Lit amount of stage [stage] of [stages], from 0 to 1.
  double stage(int stage, int stages) =>
      (fraction * stages - stage).clamp(0.0, 1.0);

  /// The stage of [stages] holding the failed step.
  int failedStage(int stages) {
    final index = failed;
    if (index == null) return 0;
    return (index * stages ~/ count).clamp(0, stages - 1);
  }
}

enum _NodeState {
  done,
  awaited,
  broadcast,
  held,
  confirmed,
  later,
  failed,
  skipped,
}

/// Texts the painter draws: the network descriptor (top left), the status tag
/// (top right) and the per-step labels. All translated by the caller.
class PaymentSceneText {
  final String descriptor;
  final String tag;
  final List<String> steps;

  const PaymentSceneText({
    this.descriptor = '',
    this.tag = '',
    this.steps = const [],
  });

  /// Resolves the descriptor and the status tag: a caller [descriptor]
  /// overrides the network's own (for example "EXCHANGE // ORDER" on a
  /// destination-network scene); the caller's [statusTag]
  /// when given, otherwise a direction-aware word for [phase] (Receiving,
  /// never Sending, when incoming).
  factory PaymentSceneText.resolve(
    BullUiLocalizations l10n, {
    required BullPaymentNetwork network,
    required BullPaymentPhase phase,
    required BullPaymentDirection direction,
    String? statusTag,
    String? descriptor,
    List<String> steps = const [],
  }) {
    final incoming = direction == BullPaymentDirection.incoming;
    final exiting = network == BullPaymentNetwork.arkExit;
    final fallback = switch (phase) {
      BullPaymentPhase.initiated => l10n.paymentTagPreparing,
      BullPaymentPhase.sending =>
        exiting
            ? l10n.paymentTagExiting
            : incoming
            ? l10n.paymentTagReceiving
            : l10n.paymentTagSending,
      BullPaymentPhase.success =>
        exiting
            ? l10n.paymentTagExited
            : incoming
            ? l10n.paymentTagReceived
            : l10n.paymentTagSent,
      BullPaymentPhase.failed => l10n.paymentTagFailed,
    };
    return PaymentSceneText(
      descriptor: descriptor != null && descriptor.isNotEmpty
          ? descriptor
          : switch (network) {
              BullPaymentNetwork.bitcoin => l10n.paymentNetworkBitcoin,
              BullPaymentNetwork.lightning => l10n.paymentNetworkLightning,
              BullPaymentNetwork.liquid => l10n.paymentNetworkLiquid,
              BullPaymentNetwork.ark => l10n.paymentNetworkArk,
              BullPaymentNetwork.arkExit => l10n.paymentNetworkArkExit,
              BullPaymentNetwork.boltz => l10n.paymentNetworkBoltz,
              BullPaymentNetwork.payjoin => l10n.paymentNetworkPayjoin,
            },
      tag: statusTag == null || statusTag.isEmpty ? fallback : statusTag,
      steps: steps,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PaymentSceneText &&
      other.descriptor == descriptor &&
      other.tag == tag &&
      other.steps.length == steps.length &&
      [for (var i = 0; i < steps.length; i++) steps[i] == other.steps[i]]
          .every((same) => same);

  @override
  int get hashCode => Object.hash(descriptor, tag, Object.hashAll(steps));
}

/// Set while painting the still (reduced-motion) pose: no travelling comets or
/// dots, whose frozen position would read as an unexplained mark.
bool _still = false;

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
    BullPaymentDirection direction = BullPaymentDirection.outgoing,
    int stepCount = 0,
    int completed = 0,
    int? failedAt,
    int? skippedAt,
    BullPaymentRefund? refund,
    BullPaymentStepState currentState = BullPaymentStepState.active,
    double? currentFraction,
    PaymentSceneText text = const PaymentSceneText(),
    bool reduced = false,
  }) {
    if (size.isEmpty) return;
    _still = reduced;
    final steps = _Steps.of(
      phase,
      stepCount,
      completed,
      failedAt,
      skippedAt,
      refund,
      text.steps,
      currentState,
    );
    final incoming = direction == BullPaymentDirection.incoming;
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
    _chrome(
      canvas,
      phase,
      gx,
      palette,
      text,
      alert:
          phase == BullPaymentPhase.failed &&
          steps.refund != BullPaymentRefund.done,
    );
    switch (network) {
      case BullPaymentNetwork.bitcoin:
        _bitcoin(
          canvas,
          phase,
          elapsed,
          time,
          gx,
          springRoll,
          palette,
          steps,
          incoming,
        );
      case BullPaymentNetwork.lightning:
        _lightning(canvas, phase, elapsed, gx, palette, steps, incoming);
      case BullPaymentNetwork.liquid:
        _liquid(
          canvas,
          phase,
          elapsed,
          time,
          springRoll,
          palette,
          steps,
          incoming,
        );
      case BullPaymentNetwork.ark:
        _ark(
          canvas,
          phase,
          elapsed,
          time,
          gx,
          gy,
          springRoll,
          palette,
          steps,
          incoming,
        );
      case BullPaymentNetwork.boltz:
        _boltz(canvas, phase, elapsed, time, gx, palette, steps, incoming);
      case BullPaymentNetwork.payjoin:
        _payjoin(canvas, phase, elapsed, time, gx, palette, steps, incoming);
      case BullPaymentNetwork.arkExit:
        _arkExit(
          canvas,
          phase,
          elapsed,
          time,
          gx,
          palette,
          steps,
          currentFraction,
        );
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

enum _Align { left, right, center }

void _text(
  Canvas c,
  String text,
  Offset at,
  Color color, {
  double size = 10,
  bool right = false,
  _Align align = _Align.left,
  double width = 120,
}) {
  if (text.isEmpty) return;
  final builder =
      ParagraphBuilder(
          ParagraphStyle(
            fontFamily: 'League Spartan',
            fontSize: size,
            fontWeight: FontWeight.w700,
            maxLines: 1,
            ellipsis: '…',
          ),
        )
        ..pushStyle(TextStyle(color: color))
        ..addText(text);
  final paragraph = builder.build()..layout(ParagraphConstraints(width: width));
  final mode = right ? _Align.right : align;
  final dx = switch (mode) {
    _Align.left => 0.0,
    _Align.right => paragraph.longestLine,
    _Align.center => paragraph.longestLine / 2,
  };
  c.drawParagraph(paragraph, Offset(at.dx - dx, at.dy - size));
}

/// A step node: done white, awaited a pulsing white outline, broadcast filled
/// orange, confirmed filled green, held a grey outline with a dot, later a
/// grey outline, failed red with a cross, skipped grey struck through.
void _node(
  Canvas c,
  Offset at,
  _NodeState state,
  PaymentAnimationPalette p,
  Color signal,
  double pulse, {
  double size = 10,
}) {
  final box = Rect.fromCenter(center: at, width: size, height: size);
  if (state == _NodeState.broadcast || state == _NodeState.confirmed) {
    final color = state == _NodeState.broadcast ? p.broadcast : p.success;
    c.drawRect(box, _fill(color));
    if (state == _NodeState.broadcast) {
      c.drawRect(box.inflate(3.5), _stroke(_alpha(color, pulse * .6), 1));
    }
    return;
  }
  c.drawRect(
    box,
    _fill(state == _NodeState.done ? p.foreground : p.background),
  );
  if (state == _NodeState.awaited) {
    c.drawRect(box.inflate(3.5), _stroke(_alpha(p.foreground, pulse * .5), 1));
  }
  if (state == _NodeState.held) {
    c.drawRect(
      Rect.fromCenter(center: at, width: 3, height: 3),
      _fill(_alpha(p.gray, .95)),
    );
  }
  c.drawRect(
    box,
    _stroke(switch (state) {
      _NodeState.done => p.foreground,
      _NodeState.awaited => _alpha(p.foreground, pulse),
      _NodeState.broadcast => p.broadcast,
      _NodeState.confirmed => p.success,
      _NodeState.later => _alpha(p.gray, .7),
      _NodeState.failed => p.failure,
      _NodeState.held || _NodeState.skipped => _alpha(p.gray, .9),
    }, state == _NodeState.awaited ? 2 : 1.5),
  );
  final half = size / 2 - 2;
  if (state == _NodeState.failed) {
    _line(
      c,
      [at + Offset(-half, -half), at + Offset(half, half)],
      p.failure,
      1.5,
    );
    _line(
      c,
      [at + Offset(half, -half), at + Offset(-half, half)],
      p.failure,
      1.5,
    );
  } else if (state == _NodeState.skipped) {
    _line(
      c,
      [
        at + Offset(-size / 2 - 3, size / 2 + 3),
        at + Offset(size / 2 + 3, -size / 2 - 3),
      ],
      _alpha(p.gray, .95),
      1.5,
    );
  }
}

/// Draws a label into a box chosen by the layout (see `payment_node_layout`).
void _labelBox(
  Canvas c,
  String label,
  Rect box,
  PaymentLabelSide side,
  _NodeState state,
  PaymentAnimationPalette p,
) {
  if (box.isEmpty) return;
  final color = switch (state) {
    _NodeState.done => _alpha(p.foreground, .95),
    _NodeState.broadcast => p.broadcast,
    _NodeState.confirmed => p.success,
    _NodeState.awaited || _NodeState.held || _NodeState.failed => p.foreground,
    _NodeState.later || _NodeState.skipped => _alpha(p.gray, .9),
  };
  final (x, align) = switch (side) {
    PaymentLabelSide.above ||
    PaymentLabelSide.below => (box.center.dx, _Align.center),
    PaymentLabelSide.right => (box.left, _Align.left),
    PaymentLabelSide.left => (box.right, _Align.right),
  };
  _text(
    c,
    label.toUpperCase(),
    Offset(x, box.bottom),
    color,
    size: 9,
    align: align,
    width: box.width + 2,
  );
}

void _chrome(
  Canvas c,
  BullPaymentPhase phase,
  double gx,
  PaymentAnimationPalette p,
  PaymentSceneText text, {
  required bool alert,
}) {
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
      i == 3 && alert ? p.failure : _alpha(p.foreground, .55),
      2,
    );
  }
  _text(
    c,
    text.descriptor.toUpperCase(),
    const Offset(34, 162),
    _alpha(p.gray, .9),
    width: 150,
  );
  _text(
    c,
    text.tag.toUpperCase(),
    const Offset(302, 162),
    _alpha(p.gray, .9),
    align: _Align.right,
    width: 130,
  );
}

enum _BadgeKind { ok, refund, fail }

/// A success is a green tick; a refunded swap a white return arrow (nothing
/// was lost); a failure with nothing to recover a red cross. A refund that is
/// still available is not terminal: no badge.
_BadgeKind? _badgeKind(BullPaymentPhase phase, _Steps s) => switch (phase) {
  BullPaymentPhase.success => _BadgeKind.ok,
  BullPaymentPhase.failed => switch (s.refund) {
    BullPaymentRefund.done => _BadgeKind.refund,
    BullPaymentRefund.available => null,
    null => _BadgeKind.fail,
  },
  _ => null,
};

/// Badge spots already solved, by scene and state.
final _badgeSpots = <String, ({Offset center, double size})>{};

/// The terminal badge, placed where it covers no node, label or stroke.
/// [ink] is evaluated once per [key]; [preferred] is where it would sit if
/// the diagram left the room.
void _badge(
  Canvas c,
  BullPaymentPhase phase,
  double elapsed,
  double start,
  PaymentAnimationPalette p,
  _Steps s, {
  required String key,
  required List<Rect> Function() ink,
  Offset preferred = const Offset(168, 320),
}) {
  final kind = _badgeKind(phase, s);
  if (kind == null) return;
  final t = _progress(elapsed, start, start + .5);
  if (t <= 0) return;
  final spot = _badgeSpots.putIfAbsent(
    '$key|${kind.name}',
    () => placePaymentBadge(ink(), preferred: preferred),
  );
  final a = _out(t), light = kind != _BadgeKind.fail;
  c.save();
  c.translate(spot.center.dx, spot.center.dy);
  c.scale(_lerp(.94, 1, a) * spot.size / 64);
  c.drawRect(
    const Rect.fromLTWH(-32, -32, 64, 64),
    _fill(
      _alpha(switch (kind) {
        _BadgeKind.ok => p.success,
        _BadgeKind.refund => p.foreground,
        _BadgeKind.fail => p.failure,
      }, a),
    ),
  );
  final path = Path();
  switch (kind) {
    case _BadgeKind.ok:
      path
        ..moveTo(-14, 1)
        ..lineTo(-4, 11)
        ..lineTo(15, -10);
    case _BadgeKind.refund:
      path
        ..moveTo(14, 12)
        ..lineTo(14, -6)
        ..lineTo(-12, -6)
        ..moveTo(-4, -14)
        ..lineTo(-12, -6)
        ..lineTo(-4, 2);
    case _BadgeKind.fail:
      path
        ..moveTo(-12, -12)
        ..lineTo(12, 12)
        ..moveTo(12, -12)
        ..lineTo(-12, 12);
  }
  final q = _progress(t, .25, .9);
  for (final metric in path.computeMetrics()) {
    c.drawPath(
      metric.extractPath(0, math.min(metric.length, 80 * q)),
      _stroke(_alpha(light ? p.background : const Color(0xffffffff), a), 5)
        ..strokeCap = StrokeCap.square,
    );
  }
  c.restore();
}

/// Short bar across a circuit's end: a terminal, not a step node.
void _terminalBar(Canvas c, List<Offset> points, bool atEnd, Color color) {
  final a = atEnd ? points.last : points.first;
  final b = atEnd ? points[points.length - 2] : points[1];
  final d = a - b;
  if (d.distance == 0) return;
  final n = Offset(-d.dy, d.dx) / d.distance;
  _line(c, [a - n * 9, a + n * 9], color, 3);
}

/// The step column shared by the scenes whose geometry cannot host labels:
/// a spine, one node per row and its label to the right. [leaders] are
/// dotted lines from a label to the drawing element it names.
void _drawColumn(
  Canvas c,
  PaymentNodeLayout layout,
  _Steps s,
  BullPaymentPhase phase,
  PaymentAnimationPalette p,
  Color signal,
  double pulse, {
  double size = 10,
  String Function(int)? labelOf,
  _NodeState Function(int)? stateOf,
  List<Offset>? leaders,
}) {
  if (layout.nodes.length > 1) {
    _line(
      c,
      [layout.nodes.first, layout.nodes.last],
      _alpha(p.foreground, .15),
      1,
    );
  }
  for (var k = 0; k < layout.nodes.length; k++) {
    final state = stateOf?.call(k) ?? s.node(k, phase);
    final box = layout.labels[k];
    if (leaders != null && !box.isEmpty) {
      final from = Offset(box.right + 6, leaders[k].dy);
      if (leaders[k].dx - from.dx > 10) {
        _dashed(
          c,
          [from, leaders[k]],
          0,
          leaders[k].dx - from.dx,
          _alpha(p.foreground, .22),
          1,
          2,
          4,
        );
      }
    }
    _node(c, layout.nodes[k], state, p, signal, pulse, size: size);
    _labelBox(
      c,
      labelOf?.call(k) ?? s.label(k),
      box,
      layout.sides[k],
      state,
      p,
    );
  }
}

/// A dashed stretch of [points] between the distances [from] and [to].
void _dashed(
  Canvas c,
  List<Offset> points,
  double from,
  double to,
  Color color,
  double width, [
  double on = 3,
  double off = 5,
]) {
  for (var d = from; d < to; d += on + off) {
    _line(
      c,
      [_point(points, d), _point(points, math.min(d + on, to))],
      color,
      width,
    );
  }
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

Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t) ?? a;

/// A short comet travelling along [points] between the distances [from] and
/// [to]; [phase] loops from 0 to 1.
void _signal(
  Canvas c,
  List<Offset> points,
  double from,
  double to,
  double phase,
  Color color,
) {
  final span = to - from;
  if (span <= 1 || _still) return;
  final d = from + (phase % 1) * span;
  final a = _point(points, math.max(from, d - 26)), b = _point(points, d);
  if ((b - a).distance > 0) {
    c.drawLine(
      a,
      b,
      _stroke(color, 3)
        ..shader = Gradient.linear(a, b, [_alpha(color, 0), _alpha(color, .9)]),
    );
  }
  c.drawRect(Rect.fromCenter(center: b, width: 6, height: 6), _fill(color));
}

/// A flow chevron on [points] at distance [d], pointing along the path.
void _chevron(Canvas c, List<Offset> points, double d, Color color) {
  final at = _point(points, d);
  final dir = _point(points, d + 2) - _point(points, math.max(0, d - 2));
  if (dir.distance == 0) return;
  final u = dir / dir.distance, n = Offset(-u.dy, u.dx);
  _line(c, [at - u * 3 + n * 4, at + u * 3, at - u * 3 - n * 4], color, 1.5);
}

/// A vector padlock (square-cut body, round shackle, keyhole), one stroke
/// weight. Closed and filled when [locked], open otherwise.
void _padlock(
  Canvas c,
  Offset o, {
  required bool locked,
  required Color color,
  required PaymentAnimationPalette p,
}) {
  final x0 = o.dx - 13, x1 = o.dx + 13, y0 = o.dy - 2, y1 = o.dy + 18;
  final body = Path()
    ..moveTo(x0, y0)
    ..lineTo(x1 - 4, y0)
    ..lineTo(x1, y0 + 4)
    ..lineTo(x1, y1)
    ..lineTo(x0 + 4, y1)
    ..lineTo(x0, y1 - 4)
    ..close();
  final lift = locked ? 0.0 : 6.0;
  final shackle = Path()
    ..moveTo(o.dx - 8, y0)
    ..lineTo(o.dx - 8, y0 - 6 - lift)
    ..arcTo(
      Rect.fromCircle(center: Offset(o.dx, y0 - 6 - lift), radius: 8),
      math.pi,
      math.pi,
      false,
    )
    ..lineTo(o.dx + 8, locked ? y0 : y0 - 6 - lift + 4);
  c.drawPath(body, _fill(locked ? color : p.background));
  c.drawPath(body, _stroke(color, 1.5));
  c.drawPath(shackle, _stroke(color, 1.5));
  final hole = locked ? p.background : color;
  c.drawCircle(Offset(o.dx, o.dy + 6), 2.2, _stroke(hole, 1.5));
  _line(c, [Offset(o.dx, o.dy + 8.5), Offset(o.dx, o.dy + 13)], hole, 1.5);
}

void _directionSignal(
  Canvas canvas,
  PaymentAnimationPalette palette,
  Color color,
  double elapsed,
  bool incoming,
) {
  const x = 316.0, top = 230.0, bottom = 410.0;
  final end = incoming ? bottom : top;
  _line(
    canvas,
    [const Offset(x, top), const Offset(x, bottom)],
    _alpha(palette.foreground, .35),
    1,
  );
  final tail = end + (incoming ? -7 : 7);
  _line(
    canvas,
    [Offset(x - 5, tail), Offset(x, end), Offset(x + 5, tail)],
    _alpha(color, .9),
    2,
  );
  if (_still) return;
  final y = _lerp(incoming ? top : bottom, end, (elapsed * .8) % 1);
  canvas.drawRect(
    Rect.fromCenter(center: Offset(x, y), width: 6, height: 6),
    _fill(color),
  );
}

/// Bitcoin: the same wireframe block for both directions, with a vertical
/// signal indicating whether value is sent or received.
/// The steps sit in a column at the left.
void _bitcoin(
  Canvas c,
  BullPaymentPhase phase,
  double e,
  double time,
  double gx,
  double spring,
  PaymentAnimationPalette p,
  _Steps s,
  bool incoming,
) {
  final failed = phase == BullPaymentPhase.failed,
      success = phase == BullPaymentPhase.success;
  final n = s.count;
  const centerX = bitcoinCubeCenterX, y = 320.0, rot = .6;
  final x =
      centerX +
      (gx * 30).clamp(-bitcoinCubeTravel, bitcoinCubeTravel).toDouble();
  _directionSignal(c, p, p.bitcoin, e, incoming);
  final rx = -.55 + spring * .3;
  Offset project(int i) {
    final vx = i < 4 ? -1.0 : 1.0,
        vy = i % 4 < 2 ? -1.0 : 1.0,
        vz = i.isEven ? -1.0 : 1.0;
    final xx = vx * math.cos(rot) + vz * math.sin(rot),
        z = -vx * math.sin(rot) + vz * math.cos(rot);
    return Offset(x + xx * 52, y + (vy * math.cos(rx) - z * math.sin(rx)) * 52);
  }

  final grey = failed ? _progress(e, 0, .6) : 0.0, lineAlpha = .85 - grey * .5;
  final fill = success
      ? _ease(_progress(e, .2, 1.1)) * .92
      : phase == BullPaymentPhase.sending && s.tracked
      ? s.fraction * .3
      : 0.0;
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
  const edges = [
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
  final layout = layoutBitcoin(count: n, labels: s.labels);
  if (s.tracked) {
    _drawColumn(
      c,
      layout,
      s,
      phase,
      p,
      p.bitcoin,
      .55 + .45 * math.sin(time * 5),
    );
  }
  _badge(
    c,
    phase,
    e,
    success ? 1.1 : 1.5,
    p,
    s,
    key: 'btc|$n|$incoming|${s.labels.join(',')}',
    ink: () => [
      for (final nd in layout.nodes)
        Rect.fromCenter(center: nd, width: 14, height: 14),
      for (final l in layout.labels)
        if (!l.isEmpty) l,
    ],
    preferred: const Offset(centerX, 320),
  );
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
  _Steps s,
  bool incoming,
) {
  final cx = arkCenterX + gx * 12, cy = 320 + (gy - 1) * 10;
  final lock = phase == BullPaymentPhase.success
      ? _ease(_progress(e, 0, 1))
      : s.tracked && s.reached(2, 3) && phase != BullPaymentPhase.failed
      ? 1.0
      : 0.0;
  final failStage = phase == BullPaymentPhase.failed ? s.failedStage(3) : -1;
  final draw = phase == BullPaymentPhase.initiated ? _ease(e / 1.4) : 1.0;
  final mult = phase == BullPaymentPhase.initiated
      ? .4
      : phase == BullPaymentPhase.sending
      ? 1.4
      : phase == BullPaymentPhase.failed
      ? .2
      : 1 - lock;
  const radii = arkRingRadii, gaps = [6, 4, 3];
  final initial = [0.0, 1.2, 2.4], velocities = [.5, -.35, .22];
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
    // With caller steps a ring is lit only once its own step is proven
    // (outer: submitted, middle: in round, core: settled); the ring awaiting
    // its step pulses in the network colour.
    final stepLit = s.tracked && s.reached(i, 3);
    final awaited = s.tracked && !stepLit && s.reached(i - 1, 3);
    final pulse = .55 + .45 * math.sin(time * 5);
    final color = phase == BullPaymentPhase.failed
        ? (i == failStage && s.tracked
              ? _alpha(p.failure, opacity)
              : _alpha(p.gray, (stepLit ? .9 : .6) * opacity))
        : s.tracked
        ? (stepLit
              ? _alpha(p.foreground, .95 * opacity)
              : awaited && phase == BullPaymentPhase.sending
              ? _alpha(p.ark, pulse * opacity)
              : _alpha(p.foreground, .25 * opacity))
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
    final a = k / 48 * math.pi * 2, end = (k % 4 == 0 ? 134 : 128) * arkScale;
    _line(
      c,
      [
        Offset(
          cx + math.cos(a) * arkTickRadius,
          cy + math.sin(a) * arkTickRadius,
        ),
        Offset(cx + math.cos(a) * end, cy + math.sin(a) * end),
      ],
      _alpha(p.foreground, .2),
      1,
    );
  }
  if (!_still &&
      (phase == BullPaymentPhase.initiated ||
          phase == BullPaymentPhase.sending)) {
    final k = (e * .35) % 1;
    if (incoming) {
      // Incoming: the payment drops from the top rim through the core, then
      // on toward the user at the bottom.
      const reach = 134.0 * arkScale;
      final lane = [Offset(cx, cy - reach), Offset(cx, cy + reach)];
      _line(c, lane, _alpha(p.foreground, .16), 1);
      c.drawRect(
        Rect.fromCenter(center: lane.last, width: 8, height: 8),
        _stroke(_alpha(p.foreground, .6), 1.5),
      );
      final point = Offset(cx, cy - reach + 2 * reach * _ease(k));
      _line(c, [Offset(cx, cy - reach), point], _alpha(p.ark, .4), 1);
      c.drawRect(
        Rect.fromCenter(center: point, width: 6, height: 6),
        _fill(p.ark),
      );
    } else {
      final r = _lerp(radii[0], 0, _ease(k)),
          a = angles[1] + k * 4,
          point = Offset(cx + math.cos(a) * r, cy + math.sin(a) * r);
      _line(c, [point, Offset(cx, cy)], _alpha(p.ark, .4), 1);
      c.drawRect(
        Rect.fromCenter(center: point, width: 6, height: 6),
        _fill(p.ark),
      );
    }
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
        Rect.fromCircle(center: Offset.zero, radius: radii[0]),
        a - .42,
        .84,
        false,
        _stroke(_alpha(p.gray, .7), 1.5),
      );
      c.restore();
    }
  }
  final layout = layoutArk(count: s.count, labels: s.labels, gx: gx);
  if (s.tracked) {
    final steps = [
      for (var k = 0; k < 3; k++) ((k + 1) * s.count / 3).ceil() - 1,
    ];
    final ringPulse = .55 + .45 * math.sin(time * 5);
    for (var k = 0; k < 3; k++) {
      // A tick on each ring's top shows its state; the column names it.
      final state = s.node(steps[k], phase);
      c.drawRect(
        Rect.fromCenter(center: layout.extra[k], width: 4, height: 4),
        _fill(switch (state) {
          _NodeState.done => p.foreground,
          _NodeState.failed => p.failure,
          _NodeState.awaited => _alpha(p.ark, ringPulse),
          _ => _alpha(p.gray, .7),
        }),
      );
    }
    _drawColumn(
      c,
      layout,
      s,
      phase,
      p,
      p.ark,
      ringPulse,
      size: 8,
      labelOf: (k) => layout.labels[k].isEmpty ? '' : s.label(steps[k]),
      stateOf: (k) => s.node(steps[k], phase),
      leaders: layout.extra,
    );
  }
  _badge(
    c,
    phase,
    e,
    phase == BullPaymentPhase.success ? 1.1 : 1.6,
    p,
    s,
    key: 'ark|${s.count}|$incoming|${s.labels.join(',')}',
    ink: () => [
      for (final nd in layout.nodes)
        Rect.fromCenter(center: nd, width: 14, height: 14),
      for (final l in layout.labels)
        if (!l.isEmpty) l,
    ],
    preferred: const Offset(arkCenterX, 320),
  );
}

/// Lightning: a circuit whose only squares are the real steps. Bends are
/// plain mitred corners; the two ends carry a terminal bar. Pulses and lit
/// steps run from the source end.
void _lightning(
  Canvas c,
  BullPaymentPhase phase,
  double e,
  double gx,
  PaymentAnimationPalette p,
  _Steps s,
  bool incoming,
) {
  final points = lightningTrace(incoming: incoming, gx: gx);
  final length = _length(points);
  final base = phase == BullPaymentPhase.initiated ? _ease(e / 1.5) : 1.0;
  final success = phase == BullPaymentPhase.success;
  final layout = layoutLightning(
    count: s.count,
    incoming: incoming,
    labels: s.labels,
    gx: gx,
  );
  final litTo = success
      ? length * _ease(_progress(e, 0, .9))
      : s.tracked && s.done > 0
      ? layout.distances[s.done - 1]
      : 0.0;
  final failedIndex = s.failed;
  final broken = phase == BullPaymentPhase.failed && e > .5;
  final breakAt = s.tracked && failedIndex != null
      ? layout.distances[failedIndex]
      : length * .5;
  if (broken) {
    _traceTo(c, points, breakAt, _alpha(p.foreground, .28), 2);
    _dashed(
      c,
      points,
      breakAt,
      length,
      _alpha(p.gray, math.sin(e * 40) > 0 ? .25 : .08),
      2,
    );
  } else {
    _traceTo(c, points, length * base, _alpha(p.foreground, .28), 2);
  }
  final lit = broken ? math.min(litTo, breakAt) : litTo;
  if (lit > 0) _traceTo(c, points, lit, _alpha(p.foreground, .95), 2.5);
  _terminalBar(
    c,
    points,
    false,
    lit > 0 || success ? _alpha(p.foreground, .95) : _alpha(p.gray, .75),
  );
  _terminalBar(
    c,
    points,
    true,
    success ? _alpha(p.foreground, .95) : _alpha(p.gray, .75),
  );
  if (s.tracked) {
    final pulse = .55 + .45 * math.sin(e * 5);
    for (var k = 0; k < s.count; k++) {
      final state = s.node(k, phase);
      _node(c, layout.nodes[k], state, p, p.lightning, pulse, size: 12);
      _labelBox(c, s.label(k), layout.labels[k], layout.sides[k], state, p);
    }
  }
  final remaining = length * base - lit;
  if ((phase == BullPaymentPhase.sending ||
          phase == BullPaymentPhase.initiated) &&
      remaining > 1 &&
      s.failed == null) {
    final n = phase == BullPaymentPhase.sending ? 3 : 1,
        speed = n == 3 ? .55 : .3;
    for (var k = 0; k < n; k++) {
      _signal(c, points, lit, lit + remaining, e * speed + k / n, p.lightning);
    }
  }
  _badge(
    c,
    phase,
    e,
    success ? 1.0 : 1.4,
    p,
    s,
    key: 'ln|${s.count}|$incoming|${s.labels.join(',')}',
    ink: () => layout.ink,
  );
}

/// Boltz swap: source rail (bottom-left) → HTLC padlock (centre) →
/// destination rail (top-right), one node per real step. A refund returns
/// from the padlock to the source: dashed red while it can be broadcast, solid
/// white once it has been. Mirrored through the centre when incoming.
void _boltz(
  Canvas c,
  BullPaymentPhase phase,
  double e,
  double time,
  double gx,
  PaymentAnimationPalette p,
  _Steps s,
  bool incoming,
) {
  final layout = layoutBoltz(
    count: s.count,
    incoming: incoming,
    labels: s.labels,
    refund: s.refund != null,
    gx: gx,
  );
  final pts = boltzPath(incoming: incoming, gx: gx);
  final length = _length(pts), n = s.count;
  double at(int i) => layout.distances[i];
  final base = phase == BullPaymentPhase.initiated ? _ease(e / 1.5) : 1.0;
  final success = phase == BullPaymentPhase.success;
  final failedIndex = s.failed;
  final broken = failedIndex != null && e > .5;
  final breakAt = failedIndex == null ? length : at(failedIndex);
  final litFull = success
      ? length * _ease(_progress(e, 0, .9))
      : s.done == 0
      ? 0.0
      : s.done >= n
      ? length
      : at(s.done - 1);
  final lit = broken ? math.min(litFull, breakAt) : litFull;
  final pulse = .55 + .45 * math.sin(time * 5);

  _traceTo(
    c,
    pts,
    broken ? breakAt : length * base,
    _alpha(p.foreground, .28),
    2,
  );
  if (broken) {
    _dashed(
      c,
      pts,
      breakAt,
      length,
      _alpha(p.gray, math.sin(e * 40) > 0 ? .25 : .08),
      2,
    );
  }
  if (lit > 0) _traceTo(c, pts, lit, _alpha(p.foreground, .95), 2.5);

  for (var k = 0; k < 2; k++) {
    final end = k == 0 ? pts.first : pts.last;
    final done = k == 0 ? s.done >= 1 : s.done >= n;
    final box = Rect.fromCenter(center: end, width: 16, height: 16);
    c.drawRect(box, _fill(p.background));
    c.drawRect(box, _stroke(_alpha(done ? p.foreground : p.gray, .8), 1.5));
    if (done) {
      c.drawRect(
        Rect.fromCenter(center: end, width: 6, height: 6),
        _fill(p.foreground),
      );
    }
  }

  final sailing =
      (phase == BullPaymentPhase.initiated ||
          phase == BullPaymentPhase.sending) &&
      s.skipped == null &&
      s.failed == null;
  if (sailing) {
    final target = s.tracked ? (s.done < n ? at(s.done) : lit) : length * base;
    final limit = math.min(target, length * base);
    _signal(c, pts, lit, limit, e * .6, p.boltz);
    if (!s.tracked) _signal(c, pts, lit, limit, e * .6 + .5, p.boltz);
  }

  for (var i = 0; i < n; i++) {
    final state = s.node(i, phase);
    if (i != layout.lockIndex) {
      _node(c, layout.nodes[i], state, p, p.boltz, pulse);
    }
    _labelBox(c, s.label(i), layout.labels[i], layout.sides[i], state, p);
  }
  if (s.refund case final refund?) {
    final back = boltzRefundPath(incoming: incoming, gx: gx);
    final settled = refund == BullPaymentRefund.done;
    final color = settled ? _alpha(p.foreground, .95) : p.failure;
    final backLength = _length(back);
    if (settled) {
      _traceTo(c, back, backLength, color, 2.5);
    } else {
      _dashed(c, back, (time * 24) % 8, backLength, color, 2.5, 4, 4);
    }
    _chevron(c, back, backLength - 3, color);
  }
  final lockLit = s.done * 2 >= n;
  final lockFailed = failedIndex != null && failedIndex == layout.lockIndex;
  final lockCurrent =
      layout.lockIndex >= 0 &&
      s.node(layout.lockIndex, phase) == _NodeState.awaited &&
      failedIndex == null;
  c.save();
  c.translate(pts[4].dx, 320);
  c.scale(boltzLockScale);
  _padlock(
    c,
    Offset.zero,
    locked: lockLit && !lockFailed,
    color: lockFailed
        ? p.failure
        : lockLit
        ? p.foreground
        : lockCurrent
        ? _alpha(p.boltz, pulse)
        : _alpha(p.gray, .85),
    p: p,
  );
  c.restore();
  _badge(
    c,
    phase,
    e,
    success ? 1.1 : 1.6,
    p,
    s,
    key: 'boltz|$n|$incoming|${s.refund?.name}|${s.labels.join(',')}',
    ink: () => layout.ink,
  );
}

/// Payjoin: the sender's input (network colour) and the receiver's input
/// (grey) converge in one wireframe transaction. Once merged every input and
/// the single output are the same white: nobody can tell who paid what.
void _payjoin(
  Canvas c,
  BullPaymentPhase phase,
  double e,
  double time,
  double gx,
  PaymentAnimationPalette p,
  _Steps s,
  bool incoming,
) {
  Offset m(Offset o) =>
      (incoming ? Offset(o.dx, 640 - o.dy) : o).translate(gx * 4, 0);
  final traces = payjoinTraces(incoming: incoming, gx: gx);
  final sender = traces.sender, receiver = traces.receiver;
  final output = traces.output;
  final base = phase == BullPaymentPhase.initiated ? _ease(e / 1.5) : 1.0;
  final success = phase == BullPaymentPhase.success;
  final a0 = s.stage(0, 3), a1 = s.stage(1, 3);
  final a2 = success ? _ease(_progress(e, 0, .9)) : s.stage(2, 3);
  final pulse = .55 + .45 * math.sin(time * 5);
  final senderColor = _mix(p.payjoin, p.foreground, a2);
  final receiverColor = _mix(p.gray, p.foreground, a2);

  for (final (trace, color, lit) in [
    (sender, senderColor, a0),
    (receiver, receiverColor, a1),
    (output, p.foreground, a2),
  ]) {
    final length = _length(trace);
    _traceTo(c, trace, length * base, _alpha(p.foreground, .28), 2);
    if (lit > 0) _traceTo(c, trace, length * lit, _alpha(color, .95), 2.5);
  }

  // The transaction: chamfered frame, input slots below, output slots above.
  final block = [
    m(const Offset(124, 256)),
    m(const Offset(202, 256)),
    m(const Offset(212, 266)),
    m(const Offset(212, 346)),
    m(const Offset(134, 346)),
    m(const Offset(124, 336)),
  ];
  final frame = Path()..moveTo(block.first.dx, block.first.dy);
  for (final o in block.skip(1)) {
    frame.lineTo(o.dx, o.dy);
  }
  frame.close();
  c.drawPath(frame, _fill(p.background));
  c.drawPath(
    frame,
    _stroke(_alpha(p.foreground, a1 >= 1 || a2 > 0 ? .95 : .55), 1.5),
  );
  _line(
    c,
    [m(const Offset(124, 301)), m(const Offset(212, 301))],
    _alpha(p.foreground, .25),
    1,
  );
  void slot(Offset center, Color color, bool filled) {
    final box = Rect.fromCenter(center: center, width: 14, height: 14);
    if (filled) c.drawRect(box, _fill(_alpha(color, .95)));
    c.drawRect(box, _stroke(_alpha(filled ? color : p.gray, .8), 1.5));
  }

  slot(m(const Offset(150, 324)), senderColor, a0 >= 1);
  slot(m(const Offset(186, 324)), receiverColor, a1 >= 1);
  slot(m(const Offset(150, 278)), p.foreground, a2 >= 1);
  slot(m(const Offset(186, 278)), p.foreground, a2 >= 1);

  for (final end in [sender.first, receiver.first, output.last]) {
    final box = Rect.fromCenter(center: end, width: 12, height: 12);
    c.drawRect(box, _fill(p.background));
    c.drawRect(box, _stroke(_alpha(p.gray, .8), 1.5));
  }
  final awaited = s.tracked ? s.done * 3 ~/ s.count : 0;
  if ((phase == BullPaymentPhase.initiated ||
          phase == BullPaymentPhase.sending) &&
      s.failed == null &&
      s.skipped == null) {
    final live = [
      (sender, p.payjoin, a0),
      (receiver, p.gray, a1),
      (output, p.foreground, a2),
    ];
    for (var i = 0; i < live.length; i++) {
      final (trace, color, lit) = live[i];
      final length = _length(trace);
      final on = s.tracked ? i == awaited && lit < 1 : i < 2 && lit < 1;
      if (on && length * base > length * lit) {
        _signal(c, trace, length * lit, length * base, e * .6 + i * .3, color);
      }
    }
  }
  final layout = layoutPayjoin(
    count: s.count,
    incoming: incoming,
    labels: s.labels,
    gx: gx,
  );
  if (s.tracked) {
    for (var i = 0; i < s.count; i++) {
      final state = s.node(i, phase);
      _node(
        c,
        layout.nodes[i],
        state,
        p,
        ((i + .5) / s.count * 3) < 1 ? p.payjoin : p.foreground,
        pulse,
        size: 12,
      );
      _labelBox(c, s.label(i), layout.labels[i], layout.sides[i], state, p);
    }
  }
  _badge(
    c,
    phase,
    e,
    success ? 1.1 : 1.6,
    p,
    s,
    key: 'pj|${s.count}|$incoming|${s.labels.join(',')}',
    ink: () => layout.ink,
  );
}

/// Liquid: a graduated gauge. With caller steps the level sits exactly at
/// completed/total and each step is a labelled tick; the scale carries no
/// number.
void _liquid(
  Canvas c,
  BullPaymentPhase phase,
  double e,
  double time,
  double spring,
  PaymentAnimationPalette p,
  _Steps s,
  bool incoming,
) {
  const gauge = liquidGauge;
  final target = switch (phase) {
    BullPaymentPhase.initiated => s.tracked ? s.fraction : .22,
    BullPaymentPhase.sending when s.tracked => s.fraction,
    BullPaymentPhase.sending => .5 + .03 * math.sin(e * 1.3),
    BullPaymentPhase.success => 1.0,
    BullPaymentPhase.failed => s.tracked ? s.fraction : .04,
  };
  // A tracked level is exact, never an animation from a guessed start.
  final initial = s.tracked
      ? (phase == BullPaymentPhase.success ? (s.count - 1) / s.count : target)
      : switch (phase) {
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
  c.drawRect(gauge.translate(.5, .5), _stroke(_alpha(p.foreground, .5), 1.5));
  final ticks = s.tracked ? s.count : 4;
  for (var k = 0; k <= ticks; k++) {
    final y = gauge.bottom - gauge.height * k / ticks;
    c.drawRect(
      Rect.fromLTWH(gauge.left - 8, y, 6, 1),
      _fill(_alpha(p.gray, .9)),
    );
  }
  final cx = (gauge.left + gauge.right) / 2;
  c.save();
  c.clipRect(
    Rect.fromLTRB(
      gauge.left + 2,
      gauge.top + 2,
      gauge.right - 1,
      gauge.bottom - 1,
    ),
  );
  c.translate(cx, gauge.bottom - level * gauge.height);
  c.rotate(spring);
  double surface(double x) =>
      amp * math.sin(x * .05 + time * 2) +
      amp * .5 * math.sin(x * .11 - time * 2.6);
  for (var y = 0.0; y < 520; y += 6) {
    final points = <Offset>[];
    for (var x = -100.0; x <= 100; x += 8) {
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
    for (var x = -100.0; x <= 100; x += 8) {
      points.add(Offset(x, surface(x) - 3));
    }
    _line(c, points, _alpha(p.liquid, .9), 2);
  }
  c.restore();
  _directionSignal(c, p, p.liquid, e, incoming);
  final layout = layoutLiquid(count: s.count, labels: s.labels);
  if (s.tracked) {
    _drawColumn(
      c,
      layout,
      s,
      phase,
      p,
      p.liquid,
      .55 + .45 * math.sin(time * 5),
      leaders: [for (final n in layout.nodes) Offset(gauge.left - 12, n.dy)],
    );
  }
  _badge(
    c,
    phase,
    e,
    phase == BullPaymentPhase.success ? 1.2 : 1.6,
    p,
    s,
    key: 'lq|${s.count}|$incoming|${s.labels.join(',')}',
    ink: () => [
      for (final n in layout.nodes)
        Rect.fromCenter(center: n, width: 14, height: 14),
      for (final l in layout.labels)
        if (!l.isEmpty) l,
    ],
    preferred: Offset(cx, 320),
  );
}

/// Ark unilateral exit: the rings open, the round tree unrolls down one
/// branch to the chain, a timelock gauge runs, then the claim lands on the
/// base line. [fraction] is the observed progress of the awaited stage; null
/// pulses indeterminately.
void _arkExit(
  Canvas c,
  BullPaymentPhase phase,
  double e,
  double time,
  double gx,
  PaymentAnimationPalette p,
  _Steps s,
  double? fraction,
) {
  Offset q(double x, double y) => Offset(x + gx * 6, y);
  const cx = arkExitCenterX, baseY = 440.0;
  final success = phase == BullPaymentPhase.success;
  final draw = phase == BullPaymentPhase.initiated ? _ease(e / 1.5) : 1.0;
  final pulse = .55 + .45 * math.sin(time * 5);
  _NodeState state(int k) => s.node(arkExitStep(k, s.count), phase);
  Color edge(int k, {double grey = .6}) => switch (state(k)) {
    _NodeState.done => p.foreground,
    _NodeState.confirmed => p.success,
    _NodeState.broadcast => _alpha(p.broadcast, pulse),
    _NodeState.awaited => _alpha(p.ark, pulse),
    _NodeState.failed => p.failure,
    _NodeState.held || _NodeState.skipped => _alpha(p.gray, .9),
    _NodeState.later => _alpha(p.gray, grey),
  };
  double lit(int k) => switch (state(k)) {
    _NodeState.done => 1.0,
    _NodeState.awaited => fraction ?? 0.0,
    _ => 0.0,
  };

  // The on-chain base line.
  _line(
    c,
    [const Offset(34, baseY), const Offset(302, baseY)],
    _alpha(p.foreground, success ? .95 : .5),
    1.5,
  );
  for (var x = 46.0; x <= 302; x += 12) {
    _line(
      c,
      [Offset(x, baseY), Offset(x, baseY + (x % 24 == 10 ? 6 : 3))],
      _alpha(p.foreground, .3),
      1,
    );
  }

  // Stage 0: the rings, opened once the exit exists.
  final opened = state(0) == _NodeState.done;
  const radii = [34.0, 24.0, 14.0], gaps = [6, 4, 3];
  final center = q(cx, 214);
  for (var i = 0; i < 3; i++) {
    final seg = 2 * math.pi / gaps[i], gap = opened ? .5 : .09;
    for (var j = 0; j < gaps[i]; j++) {
      c.drawArc(
        Rect.fromCircle(center: center, radius: radii[i]),
        (i.isEven ? 1 : -1) * time * .2 + j * seg + gap / 2,
        seg - gap,
        false,
        _stroke(
          opened
              ? _alpha(p.foreground, .9)
              : state(0) == _NodeState.failed
              ? p.failure
              : _alpha(p.gray, .5 * draw),
          i == 0 ? 1.5 : 2,
        ),
      );
    }
  }

  // The round tree, grey; one branch lights as it unrolls (stage 1).
  final tree = arkExitTree(gx: gx);
  for (final link in const [(0, 1), (0, 2), (1, 3), (1, 4), (2, 5), (2, 6)]) {
    _line(c, [tree[link.$1], tree[link.$2]], _alpha(p.foreground, .16), 1);
  }
  final branch = arkExitBranch(gx: gx), length = _length(branch);
  _traceTo(c, branch, length * draw, _alpha(p.foreground, .28), 2);
  final unrolled = length * lit(1);
  if (unrolled > 0) {
    _traceTo(c, branch, unrolled, _alpha(p.foreground, .95), 2.5);
  }
  // Tree boxes the branch passes through, with their vertex in the branch.
  const onBranch = {0: 1, 1: 2, 4: 3};
  for (var i = 0; i < tree.length; i++) {
    final box = Rect.fromCenter(center: tree[i], width: 10, height: 10);
    final vertex = onBranch[i];
    final lighted =
        vertex != null &&
        unrolled >= _length(branch.sublist(0, vertex + 1)) - .5;
    c.drawRect(box, _fill(lighted ? p.foreground : p.background));
    c.drawRect(
      box,
      _stroke(
        vertex == null
            ? _alpha(p.gray, .35)
            : (lighted ? p.foreground : edge(1, grey: .5)),
        1.2,
      ),
    );
  }
  if (state(1) == _NodeState.awaited && fraction == null) {
    _signal(c, branch, unrolled, length, e * .5, p.ark);
  }

  // Stage 2: the timelock gauge, a half arc filling with the elapsed delay.
  final gaugeCenter = q(cx, 376);
  final arc = Rect.fromCircle(center: gaugeCenter, radius: 28);
  _line(
    c,
    [gaugeCenter + const Offset(-32, 0), gaugeCenter + const Offset(32, 0)],
    _alpha(p.foreground, .25),
    1,
  );
  for (var i = 0; i <= 8; i++) {
    final a = math.pi + math.pi * i / 8;
    _line(
      c,
      [
        gaugeCenter + Offset(math.cos(a), math.sin(a)) * 31,
        gaugeCenter + Offset(math.cos(a), math.sin(a)) * (i.isEven ? 36 : 34),
      ],
      _alpha(p.foreground, .3),
      1,
    );
  }
  c.drawArc(
    arc,
    math.pi,
    math.pi,
    false,
    _stroke(
      state(2) == _NodeState.failed ? p.failure : _alpha(p.foreground, .28),
      2,
    ),
  );
  final filled = lit(2);
  if (filled > 0) {
    c.drawArc(
      arc,
      math.pi,
      math.pi * filled,
      false,
      _stroke(
        state(2) == _NodeState.done ? p.foreground : _alpha(p.ark, .95),
        3,
      ),
    );
  } else if (state(2) == _NodeState.awaited) {
    // Indeterminate: a short segment sweeps the arc.
    final at = math.pi + (math.pi - .5) * (.5 + .5 * math.sin(e * 2));
    c.drawArc(arc, at, .5, false, _stroke(_alpha(p.ark, pulse), 3));
  }

  // Stage 3: the claim, a wireframe block that lands on the base line.
  final landed = state(3) == _NodeState.done;
  final lift = landed ? 0.0 : 16 + (success ? 0 : 2 * math.sin(time * 3));
  final connectorLit = state(2) == _NodeState.done;
  _line(
    c,
    [gaugeCenter, q(cx, baseY - 36 - lift - 4)],
    _alpha(connectorLit ? p.foreground : p.gray, connectorLit ? .95 : .3),
    2,
  );
  final front = Rect.fromLTWH(cx - 18 + gx * 6, baseY - 36 - lift, 36, 36);
  const d = Offset(7, -7);
  final top = Path()
    ..moveTo(front.left, front.top)
    ..lineTo(front.left + d.dx, front.top + d.dy)
    ..lineTo(front.right + d.dx, front.top + d.dy)
    ..lineTo(front.right, front.top)
    ..close();
  final side = Path()
    ..moveTo(front.right, front.top)
    ..lineTo(front.right + d.dx, front.top + d.dy)
    ..lineTo(front.right + d.dx, front.bottom + d.dy)
    ..lineTo(front.right, front.bottom)
    ..close();
  final blockColor = edge(3, grey: .6);
  if (landed) {
    c.drawRect(front, _fill(_alpha(p.foreground, .92)));
    c.drawPath(top, _fill(_alpha(p.foreground, .7)));
    c.drawPath(side, _fill(_alpha(p.foreground, .5)));
  } else {
    c.drawRect(front, _fill(p.background));
  }
  c.drawRect(front, _stroke(blockColor, 1.5));
  c.drawPath(top, _stroke(blockColor, 1.5));
  c.drawPath(side, _stroke(blockColor, 1.5));

  // Step markers and labels.
  final layout = layoutArkExit(count: s.count, labels: s.labels, gx: gx);
  _drawColumn(
    c,
    layout,
    s,
    phase,
    p,
    p.ark,
    pulse,
    labelOf: (k) =>
        layout.labels[k].isEmpty ? '' : s.label(arkExitStep(k, s.count)),
    stateOf: state,
  );
  // The claim lands on the base line: the badge stays clear of the proof.
  _badge(
    c,
    phase,
    e,
    success ? 1.1 : 1.6,
    p,
    s,
    key: 'exit|${s.count}|${s.labels.join(',')}',
    ink: () => layout.ink,
  );
}
