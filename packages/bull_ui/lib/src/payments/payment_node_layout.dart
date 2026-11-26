import 'dart:math' as math;
import 'dart:ui';

/// The frame the diagrams live in (the four corner brackets), in the
/// 336 × 696 canvas space. Labels never leave it.
const paymentFrame = Rect.fromLTRB(34, 170, 302, 470);

const _labelHeight = 9.0;
const _nodeBox = 9.0;

/// The eight bracket legs, as thin boxes. Every label avoids them.
final List<Rect> paymentBrackets = [
  for (final (x, y, sx, sy) in const [
    (34.0, 170.0, 1.0, 1.0),
    (302.0, 170.0, -1.0, 1.0),
    (34.0, 470.0, 1.0, -1.0),
    (302.0, 470.0, -1.0, -1.0),
  ]) ...[
    Rect.fromLTRB(
      math.min(x, x + sx * 18) - 1,
      y - 1,
      math.max(x, x + sx * 18) + 1,
      y + 1,
    ),
    Rect.fromLTRB(
      x - 1,
      math.min(y, y + sy * 18) - 1,
      x + 1,
      math.max(y, y + sy * 18) + 1,
    ),
  ],
];

/// Where a label sits relative to its node.
enum PaymentLabelSide { above, below, left, right }

/// Estimated width of an uppercase label at the painter's 9 px bold face. The
/// painter and the layout tests use the same estimate.
double paymentLabelWidth(String text, {double max = 100}) =>
    math.min(max, text.length * 5.8);

double polylineLength(List<Offset> points) {
  var length = 0.0;
  for (var i = 1; i < points.length; i++) {
    length += (points[i] - points[i - 1]).distance;
  }
  return length;
}

Offset polylinePoint(List<Offset> points, double distance) {
  var d = distance;
  for (var i = 1; i < points.length; i++) {
    final len = (points[i] - points[i - 1]).distance;
    if (d <= len) {
      return Offset.lerp(points[i - 1], points[i], len == 0 ? 0 : d / len) ??
          points[i];
    }
    d -= len;
  }
  return points.last;
}

/// A drawn stroke as a chain of small boxes, so labels can be solved against
/// it.
List<Rect> strokeBoxes(
  List<Offset> points, {
  double step = 5,
  double size = 4,
}) {
  final length = polylineLength(points);
  return [
    for (var d = 0.0; d <= length; d += step)
      Rect.fromCenter(
        center: polylinePoint(points, d),
        width: size,
        height: size,
      ),
  ];
}

List<Offset> circlePoints(Offset center, double radius, {int segments = 48}) =>
    [
      for (var i = 0; i <= segments; i++)
        center +
            Offset(
                  math.cos(i / segments * math.pi * 2),
                  math.sin(i / segments * math.pi * 2),
                ) *
                radius,
    ];

/// Node centres, label boxes and everything the labels avoid.
class PaymentNodeLayout {
  /// Centre of each node (the padlock's centre for a lock node).
  final List<Offset> nodes;

  /// Distance of each node along the scene's main path, when it has one.
  final List<double> distances;

  /// Label box of each node, [Rect.zero] when its label is empty.
  final List<Rect> labels;
  final List<PaymentLabelSide> sides;

  /// Static scene shapes (padlock, transaction block, graphics) that labels
  /// must not cover.
  final List<Rect> obstacles;

  /// Drawn strokes (paths, rings, return traces) that labels must not cross.
  final List<List<Offset>> strokes;

  /// Index of the node drawn as the padlock, or -1.
  final int lockIndex;

  /// The padlock's bounding box, when there is one.
  final Rect? lockRect;

  /// Scene-specific anchor points (ring tops, leader targets).
  final List<Offset> extra;

  const PaymentNodeLayout({
    required this.nodes,
    required this.distances,
    required this.labels,
    required this.sides,
    required this.obstacles,
    this.strokes = const [],
    this.lockIndex = -1,
    this.lockRect,
    this.extra = const [],
  });

  /// Everything a terminal badge must keep clear of.
  List<Rect> get ink => [
    ...obstacles,
    for (final s in strokes) ...strokeBoxes(s),
    for (final n in nodes) Rect.fromCenter(center: n, width: 14, height: 14),
    for (final l in labels)
      if (!l.isEmpty) l,
  ];
}

Rect _labelRect(Offset anchor, PaymentLabelSide side, double w, double shift) {
  final double left, top;
  switch (side) {
    case PaymentLabelSide.above:
      left = anchor.dx - w / 2;
      top = anchor.dy - 12 - _labelHeight + shift;
    case PaymentLabelSide.below:
      left = anchor.dx - w / 2;
      top = anchor.dy + 16 + shift;
    case PaymentLabelSide.right:
      left = anchor.dx + 14;
      top = anchor.dy - _labelHeight / 2 + shift;
    case PaymentLabelSide.left:
      left = anchor.dx - 14 - w;
      top = anchor.dy - _labelHeight / 2 + shift;
  }
  return Rect.fromLTWH(
    left.clamp(paymentFrame.left, paymentFrame.right - w),
    top,
    w,
    _labelHeight,
  );
}

bool _clear(Rect r, List<Rect> blocked) =>
    r.left >= paymentFrame.left &&
    r.top >= paymentFrame.top &&
    r.right <= paymentFrame.right &&
    r.bottom <= paymentFrame.bottom &&
    !blocked.any((o) => r.inflate(1.57).overlaps(o));

/// Places one label per node: the preferred side first, then the others, each
/// at several vertical shifts, taking the first spot that stays inside the
/// frame and clear of every obstacle, bracket, node and earlier label. A label
/// that fits nowhere at full width is shortened (the painter ends it with an
/// ellipsis) rather than allowed to touch a stroke.
List<(Rect, PaymentLabelSide)> placePaymentLabels({
  required List<Offset> anchors,
  required List<String> labels,
  required List<List<PaymentLabelSide>> preferred,
  List<Rect> obstacles = const [],
  Set<int> skipNodeBox = const {},
  double maxWidth = 100,
}) {
  final blocked = [
    ...paymentBrackets,
    ...obstacles,
    for (var i = 0; i < anchors.length; i++)
      if (!skipNodeBox.contains(i))
        Rect.fromCenter(
          center: anchors[i],
          width: _nodeBox * 2,
          height: _nodeBox * 2,
        ),
  ];
  final placed = <(Rect, PaymentLabelSide)>[];
  for (var i = 0; i < anchors.length; i++) {
    final text = i < labels.length ? labels[i] : '';
    if (text.isEmpty) {
      placed.add((Rect.zero, PaymentLabelSide.below));
      continue;
    }
    final full = paymentLabelWidth(text, max: maxWidth);
    final order = [
      ...preferred[i],
      for (final s in PaymentLabelSide.values)
        if (!preferred[i].contains(s)) s,
    ];
    (Rect, PaymentLabelSide)? choice;
    search:
    for (final k in const [1.0, .82, .66, .5]) {
      for (final shift in const [0.0, 8.0, -8.0, 16.0, -16.0, 24.0, -24.0]) {
        for (final side in order) {
          final r = _labelRect(anchors[i], side, math.max(24, full * k), shift);
          if (_clear(r, [...blocked, for (final (p, _) in placed) p])) {
            choice = (r, side);
            break search;
          }
        }
      }
    }
    placed.add(
      choice ?? (_labelRect(anchors[i], order.first, full, 0), order.first),
    );
  }
  return placed;
}

PaymentNodeLayout _solve({
  required List<Offset> nodes,
  required List<double> distances,
  required List<String> labels,
  required List<List<PaymentLabelSide>> preferred,
  required List<Rect> obstacles,
  required List<List<Offset>> strokes,
  List<Offset>? anchors,
  Set<int> skipNodeBox = const {},
  int lockIndex = -1,
  Rect? lockRect,
  double maxWidth = 100,
  List<Offset> extra = const [],
}) {
  final placed = placePaymentLabels(
    anchors: anchors ?? nodes,
    labels: labels,
    preferred: preferred,
    obstacles: [...obstacles, for (final s in strokes) ...strokeBoxes(s)],
    skipNodeBox: skipNodeBox,
    maxWidth: maxWidth,
  );
  return PaymentNodeLayout(
    nodes: nodes,
    distances: distances,
    labels: [for (final (r, _) in placed) r],
    sides: [for (final (_, s) in placed) s],
    obstacles: obstacles,
    strokes: strokes,
    lockIndex: lockIndex,
    lockRect: lockRect,
    extra: extra,
  );
}

Offset _mirror180(Offset o) => Offset(336 - o.dx, 640 - o.dy);

// ------------------------------------------------------------ step column

/// Horizontal position of the step column used where the geometry cannot
/// host labels cleanly: nodes on a spine at the left of the frame, each label
/// to the right of its node.
const paymentColumnX = 44.0;

PaymentNodeLayout _column({
  required List<double> rows,
  required List<String> labels,
  required List<Rect> obstacles,
  required List<List<Offset>> strokes,
  List<Offset> extra = const [],
}) {
  final nodes = [for (final y in rows) Offset(paymentColumnX, y)];
  final layout = _solve(
    nodes: nodes,
    distances: const [],
    labels: labels,
    preferred: [
      for (var i = 0; i < rows.length; i++) [PaymentLabelSide.right],
    ],
    obstacles: obstacles,
    strokes: strokes,
    maxWidth: 88,
    extra: extra,
  );
  return layout;
}

// ---------------------------------------------------------------- Boltz

/// The padlock is drawn at this scale around its centre (168, 320).
const boltzLockScale = 1.45;

/// The padlock's bounding box: body, keyhole and the raised open shackle.
const boltzLockRect = Rect.fromLTRB(
  168 - 13 * boltzLockScale,
  320 - 22 * boltzLockScale,
  168 + 13 * boltzLockScale,
  320 + 18 * boltzLockScale,
);

const _boltzLeft = [
  Offset(58, 430),
  Offset(58, 392),
  Offset(116, 392),
  Offset(168, 340),
];

/// Source rail (bottom-left), diagonal to the padlock, diagonal to the
/// destination rail (top-right); a Z through the frame.
List<Offset> boltzPath({required bool incoming, double gx = 0}) {
  final right = [for (final o in _boltzLeft.reversed) _mirror180(o)];
  return [
    for (final o in [..._boltzLeft, ...right])
      (incoming ? _mirror180(o) : o).translate(gx * 4, 0),
  ];
}

/// The refund's return trace, from under the padlock back to the source.
List<Offset> boltzRefundPath({required bool incoming, double gx = 0}) => [
  for (final o in const [
    Offset(176, 350),
    Offset(116, 410),
    Offset(74, 410),
    Offset(74, 430),
    Offset(66, 430),
  ])
    (incoming ? _mirror180(o) : o).translate(gx * 4, 0),
];

double _distanceToRect(Offset o, Rect r) {
  final dx = math.max(math.max(r.left - o.dx, 0.0), o.dx - r.right);
  final dy = math.max(math.max(r.top - o.dy, 0.0), o.dy - r.bottom);
  return math.sqrt(dx * dx + dy * dy);
}

/// Lays out [count] nodes along the Boltz path. An odd count makes the
/// middle node the padlock itself, its label right beside it; the other nodes
/// are spread evenly over the two rails, never within 30 canvas units of the
/// padlock. Labels point toward the empty quadrants and avoid every stroke.
PaymentNodeLayout layoutBoltz({
  required int count,
  required bool incoming,
  required List<String> labels,
  bool refund = false,
  double gx = 0,
}) {
  final path = boltzPath(incoming: incoming, gx: gx);
  final length = polylineLength(path);
  final lockRect = boltzLockRect.shift(Offset(gx * 4, 0));
  var reach = 0.0;
  for (var d = 0.0; d <= length / 2; d += 1) {
    if (_distanceToRect(polylinePoint(path, d), lockRect) >= 30) reach = d;
  }
  final lockIndex = count.isOdd ? (count - 1) ~/ 2 : -1;
  final perSide = count ~/ 2;
  const lo = 24.0;
  double zone(int j) => lo + (reach - lo) * (j + .5) / perSide;
  final distances = <double>[
    for (var j = 0; j < perSide; j++) zone(j),
    if (lockIndex >= 0) length / 2,
    for (var j = perSide - 1; j >= 0; j--) length - zone(j),
  ];
  final nodes = [for (final d in distances) polylinePoint(path, d)];
  final strokes = [
    path,
    if (refund) boltzRefundPath(incoming: incoming, gx: gx),
  ];
  final obstacles = [
    lockRect.inflate(3),
    Rect.fromCenter(center: path.first, width: 20, height: 20),
    Rect.fromCenter(center: path.last, width: 20, height: 20),
  ];
  bool leftHalf(int i) => i < count / 2;
  return _solve(
    nodes: nodes,
    distances: distances,
    labels: labels,
    anchors: [
      for (var i = 0; i < count; i++)
        i == lockIndex ? Offset(lockRect.right - 6, 320) : nodes[i],
    ],
    preferred: [
      for (var i = 0; i < count; i++)
        i == lockIndex
            ? [PaymentLabelSide.right, PaymentLabelSide.left]
            : leftHalf(i) != incoming
            ? [PaymentLabelSide.above, PaymentLabelSide.below]
            : [PaymentLabelSide.below, PaymentLabelSide.above],
    ],
    obstacles: obstacles,
    strokes: strokes,
    skipNodeBox: {if (lockIndex >= 0) lockIndex},
    lockIndex: lockIndex,
    lockRect: lockRect,
  );
}

// ------------------------------------------------------------ Lightning

/// The circuit, ordered from the source end: bottom to top when paying, top
/// to bottom when receiving. Bends are plain mitred corners.
List<Offset> lightningTrace({required bool incoming, double gx = 0}) {
  final points = [
    for (final o in const [
      Offset(168, 452),
      Offset(168, 414),
      Offset(98, 366),
      Offset(98, 304),
      Offset(208, 238),
      Offset(208, 196),
    ])
      o.translate(gx * 8, 0),
  ];
  return incoming ? points.reversed.toList() : points;
}

PaymentNodeLayout layoutLightning({
  required int count,
  required bool incoming,
  required List<String> labels,
  double gx = 0,
}) {
  final path = lightningTrace(incoming: incoming, gx: gx);
  final length = polylineLength(path);
  final distances = [
    for (var k = 0; k < count; k++) length * (k + 1) / (count + 1),
  ];
  final nodes = [for (final d in distances) polylinePoint(path, d)];
  return _solve(
    nodes: nodes,
    distances: distances,
    labels: labels,
    preferred: [
      for (final n in nodes)
        n.dx < 150
            ? [PaymentLabelSide.left, PaymentLabelSide.right]
            : [PaymentLabelSide.right, PaymentLabelSide.left],
    ],
    obstacles: [
      Rect.fromCenter(center: path.first, width: 20, height: 20),
      Rect.fromCenter(center: path.last, width: 20, height: 20),
    ],
    strokes: [path],
  );
}

// ------------------------------------------------------------------ Ark

const arkCenterX = 198.0;
const arkScale = .76;
const arkRingRadii = [110 * arkScale, 78 * arkScale, 46 * arkScale];
const arkTickRadius = 124 * arkScale;

/// Rings at the right, a step column at the left; row k aligns with the top
/// of ring k, with a short leader to it.
PaymentNodeLayout layoutArk({
  required int count,
  required List<String> labels,
  double gx = 0,
}) {
  final cx = arkCenterX + gx * 12;
  final steps = [for (var k = 0; k < 3; k++) ((k + 1) * count / 3).ceil() - 1];
  final rows = [for (final r in arkRingRadii) 320 - r];
  final stageLabels = [
    for (var k = 0; k < 3; k++)
      k > 0 && steps[k] == steps[k - 1]
          ? ''
          : (steps[k] < labels.length ? labels[steps[k]] : ''),
  ];
  return _column(
    rows: rows,
    labels: stageLabels,
    obstacles: const [],
    strokes: [
      for (final r in [...arkRingRadii, arkTickRadius])
        circlePoints(Offset(cx, 320), r),
    ],
    extra: [for (final y in rows) Offset(cx, y)],
  );
}

// -------------------------------------------------------------- Payjoin

/// Sender input, receiver input and output traces, kept inside the frame
/// below the tag line; mirrored vertically when the payment is incoming.
({List<Offset> sender, List<Offset> receiver, List<Offset> output})
payjoinTraces({required bool incoming, double gx = 0}) {
  Offset m(Offset o) =>
      (incoming ? Offset(o.dx, 640 - o.dy) : o).translate(gx * 4, 0);
  return (
    sender: [
      for (final o in const [
        Offset(88, 436),
        Offset(88, 408),
        Offset(150, 346),
      ])
        m(o),
    ],
    receiver: [
      for (final o in const [
        Offset(248, 436),
        Offset(248, 408),
        Offset(186, 346),
      ])
        m(o),
    ],
    output: [
      for (final o in const [Offset(168, 256), Offset(168, 206)]) m(o),
    ],
  );
}

PaymentNodeLayout layoutPayjoin({
  required int count,
  required bool incoming,
  required List<String> labels,
  double gx = 0,
}) {
  final traces = payjoinTraces(incoming: incoming, gx: gx);
  final list = [traces.sender, traces.receiver, traces.output];
  final nodes = <Offset>[];
  final kinds = <int>[];
  for (var i = 0; i < count; i++) {
    final u = (i + .5) / count * 3;
    final k = u.floor().clamp(0, 2);
    nodes.add(polylinePoint(list[k], polylineLength(list[k]) * (u - k)));
    kinds.add(k);
  }
  final block = incoming
      ? const Rect.fromLTRB(124, 294, 212, 384)
      : const Rect.fromLTRB(124, 256, 212, 346);
  final obstacles = [
    block.shift(Offset(gx * 4, 0)).inflate(2),
    for (final t in list)
      Rect.fromCenter(center: t.first, width: 16, height: 16),
    Rect.fromCenter(center: traces.output.last, width: 16, height: 16),
  ];
  return _solve(
    nodes: nodes,
    distances: const [],
    labels: labels,
    preferred: [
      for (final k in kinds)
        k == 0
            ? [PaymentLabelSide.right, PaymentLabelSide.left]
            : k == 1
            ? [PaymentLabelSide.left, PaymentLabelSide.right]
            : [PaymentLabelSide.right, PaymentLabelSide.left],
    ],
    obstacles: obstacles,
    strokes: list,
  );
}

// -------------------------------------------------------------- Bitcoin

List<double> paymentColumnRows(int count) => [
  for (var i = 0; i < count; i++) 330 + (i - (count - 1) / 2) * 44,
];

/// Resting centre of the wireframe cube.
const bitcoinCubeCenterX = 206.0;

/// Half the cube's projected width (52 × (cos .6 + sin .6)), rounded up.
const bitcoinCubeHalfWidth = 73.0;

/// How far the tilt may slide the cube sideways. Bounded so that the cube
/// never reaches the step column, whatever the device roll.
const bitcoinCubeTravel = 10.0;

/// Everything the cube can cover, over its whole travel: labels stay out of
/// it, so they never move with the tilt.
const bitcoinCubeObstacle = Rect.fromLTRB(
  bitcoinCubeCenterX - bitcoinCubeTravel - bitcoinCubeHalfWidth,
  176,
  302,
  446,
);

/// The block and its traces fill the right of the frame; the step column
/// takes the left. A label that fits nowhere at full width is shortened.
PaymentNodeLayout layoutBitcoin({
  required int count,
  required List<String> labels,
}) => _column(
  rows: paymentColumnRows(count),
  labels: labels,
  obstacles: const [bitcoinCubeObstacle],
  strokes: const [],
);

// --------------------------------------------------------------- Liquid

const liquidGauge = Rect.fromLTRB(160, 190, 290, 450);

/// Row k sits at the level of step k's boundary on the gauge, so a proven
/// step is a level the liquid has reached.
PaymentNodeLayout layoutLiquid({
  required int count,
  required List<String> labels,
}) => _column(
  rows: [
    for (var k = 0; k < count; k++)
      math.max(
        liquidGauge.top + 4,
        liquidGauge.bottom - liquidGauge.height * (k + 1) / count,
      ),
  ],
  labels: labels,
  obstacles: [
    Rect.fromLTRB(
      liquidGauge.left - 10,
      liquidGauge.top - 4,
      302,
      liquidGauge.bottom + 4,
    ),
  ],
  strokes: const [],
);

// ------------------------------------------------------------- Ark exit

/// Horizontal centre of the exit diagram; the step markers form a column to
/// its left.
const arkExitCenterX = 204.0;
const arkExitMarkerY = [214.0, 300.0, 362.0, 424.0];

/// The four stages: rings opened, branch unrolled, timelock run, claim landed.
int arkExitStep(int stage, int count) => ((stage + 1) * count / 4).ceil() - 1;

/// The round tree: root, two children, four grandchildren (box centres).
List<Offset> arkExitTree({double gx = 0}) => [
  for (final o in const [
    Offset(204, 266),
    Offset(174, 292),
    Offset(234, 292),
    Offset(159, 318),
    Offset(189, 318),
    Offset(219, 318),
    Offset(249, 318),
  ])
    o.translate(gx * 6, 0),
];

/// The unrolled branch: from the rings, down through the tree, to the gauge.
List<Offset> arkExitBranch({double gx = 0}) => [
  for (final o in const [
    Offset(204, 248),
    Offset(204, 266),
    Offset(174, 292),
    Offset(189, 318),
    Offset(204, 334),
    Offset(204, 348),
  ])
    o.translate(gx * 6, 0),
];

PaymentNodeLayout layoutArkExit({
  required int count,
  required List<String> labels,
  double gx = 0,
}) {
  final stageLabels = <String>[];
  var previous = -1;
  for (var k = 0; k < 4; k++) {
    final step = arkExitStep(k, count);
    stageLabels.add(
      step != previous && step < labels.length ? labels[step] : '',
    );
    previous = step;
  }
  final shift = Offset(gx * 6, 0);
  final obstacles = [
    const Rect.fromLTRB(166, 176, 242, 252).shift(shift),
    for (final o in arkExitTree(gx: gx))
      Rect.fromCenter(center: o, width: 16, height: 16),
    const Rect.fromLTRB(170, 342, 238, 380).shift(shift),
    const Rect.fromLTRB(180, 380, 236, 442).shift(shift),
    const Rect.fromLTRB(34, 436, 302, 446),
  ];
  return _column(
    rows: arkExitMarkerY,
    labels: stageLabels,
    obstacles: obstacles,
    strokes: [
      arkExitBranch(gx: gx),
      circlePoints(Offset(204 + gx * 6, 214), 34),
    ],
  );
}

// ---------------------------------------------------------------- Badge

/// Where the terminal badge goes: the spot nearest [preferred] that keeps at
/// least 8 canvas units from every [ink] box, at the largest of 64, 52 and
/// 44 units that has one. A badge never covers a node, a label or a stroke.
({Offset center, double size}) placePaymentBadge(
  List<Rect> ink, {
  Offset preferred = const Offset(168, 320),
}) {
  for (final size in const [64.0, 52.0, 44.0]) {
    final half = size / 2 + 4;
    Offset? best;
    var bestScore = double.infinity;
    for (
      var y = paymentFrame.top + half;
      y <= paymentFrame.bottom - half;
      y += 6
    ) {
      for (
        var x = paymentFrame.left + half;
        x <= paymentFrame.right - half;
        x += 6
      ) {
        final r = Rect.fromCenter(
          center: Offset(x, y),
          width: size,
          height: size,
        );
        var clear = true;
        for (final o in ink) {
          final dx = math.max(
            math.max(o.left - r.right, r.left - o.right),
            0.0,
          );
          final dy = math.max(
            math.max(o.top - r.bottom, r.top - o.bottom),
            0.0,
          );
          if (math.sqrt(dx * dx + dy * dy) < 8) {
            clear = false;
            break;
          }
        }
        if (!clear) continue;
        final score = (Offset(x, y) - preferred).distance;
        if (score < bestScore) {
          bestScore = score;
          best = Offset(x, y);
        }
      }
    }
    if (best != null) return (center: best, size: size);
  }
  return (center: preferred, size: 44);
}
