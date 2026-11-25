import 'dart:math' as math;
import 'dart:ui';

import 'package:bull_ui/src/payments/payment_node_layout.dart';
import 'package:flutter_test/flutter_test.dart';

const _long = ['Lockup sent', 'Boltz lockup', 'Claim broadcast', 'Completed'];
const _longer = [
  'Original received',
  'Proposal sent',
  'Proposal received',
  'Payout in progress',
];

/// Whether [stroke] passes through [box], sampled every 2 canvas units.
bool _crosses(List<Offset> stroke, Rect box) {
  final length = polylineLength(stroke);
  for (var d = 0.0; d <= length; d += 2) {
    if (box.contains(polylinePoint(stroke, d))) return true;
  }
  return false;
}

/// Every label stays in the frame and clear of the brackets, every drawn
/// stroke, every obstacle, every node and every other label.
void _expectClean(PaymentNodeLayout layout, String reason) {
  final boxes = [
    for (final r in layout.labels)
      if (!r.isEmpty) r,
  ];
  for (var i = 0; i < boxes.length; i++) {
    final r = boxes[i];
    expect(paymentFrame.contains(r.topLeft), isTrue, reason: '$reason $r');
    expect(paymentFrame.contains(r.bottomRight), isTrue, reason: '$reason $r');
    for (final b in paymentBrackets) {
      expect(r.overlaps(b), isFalse, reason: '$reason label $r vs bracket $b');
    }
    for (final o in layout.obstacles) {
      expect(r.overlaps(o), isFalse, reason: '$reason label $r vs obstacle $o');
    }
    for (final s in layout.strokes) {
      expect(_crosses(s, r), isFalse, reason: '$reason label $r crossed');
    }
    for (var j = 0; j < layout.nodes.length; j++) {
      if (j == layout.lockIndex) continue;
      final node = Rect.fromCenter(
        center: layout.nodes[j],
        width: 12,
        height: 12,
      );
      expect(r.overlaps(node), isFalse, reason: '$reason label $r vs node $j');
    }
    for (var j = i + 1; j < boxes.length; j++) {
      expect(
        r.inflate(1).overlaps(boxes[j]),
        isFalse,
        reason: '$reason labels $r and ${boxes[j]}',
      );
    }
  }
}

void main() {
  for (final incoming in [false, true]) {
    for (final n in [2, 3, 4]) {
      final labels = _long.take(n).toList();
      final longer = _longer.take(n).toList();
      for (final refund in [false, true]) {
        test('boltz $n nodes incoming=$incoming refund=$refund', () {
          final layout = layoutBoltz(
            count: n,
            incoming: incoming,
            labels: labels,
            refund: refund,
          );
          expect(layout.nodes, hasLength(n));
          _expectClean(layout, 'boltz');
          final lock = layout.lockRect;
          expect(lock, isNotNull);
          for (var i = 0; i < n; i++) {
            if (i == layout.lockIndex || lock == null) continue;
            final o = layout.nodes[i];
            final dx = math.max(
              math.max(lock.left - o.dx, 0.0),
              o.dx - lock.right,
            );
            final dy = math.max(
              math.max(lock.top - o.dy, 0.0),
              o.dy - lock.bottom,
            );
            expect(
              math.sqrt(dx * dx + dy * dy),
              greaterThanOrEqualTo(28),
              reason: 'node $i too close to the padlock',
            );
          }
          for (var i = 1; i < n; i++) {
            expect(layout.distances[i], greaterThan(layout.distances[i - 1]));
          }
          if (lock != null && layout.lockIndex >= 0) {
            // The padlock's own label sits beside it, attached to it.
            final label = layout.labels[layout.lockIndex];
            expect(label.isEmpty, isFalse);
            final gap = math.max(
              label.left - lock.right,
              lock.left - label.right,
            );
            expect(gap, inInclusiveRange(0, 16), reason: 'lock label gap');
            expect((label.center.dy - 320).abs(), lessThan(30));
          }
        });
      }
      test('lightning $n nodes incoming=$incoming', () {
        _expectClean(
          layoutLightning(count: n, incoming: incoming, labels: labels),
          'lightning',
        );
      });
      test('payjoin $n nodes incoming=$incoming', () {
        _expectClean(
          layoutPayjoin(count: n, incoming: incoming, labels: longer),
          'payjoin',
        );
      });
      test('ark $n nodes', () {
        _expectClean(layoutArk(count: n, labels: labels), 'ark');
      });
      test('bitcoin $n nodes', () {
        _expectClean(layoutBitcoin(count: n, labels: labels), 'bitcoin');
      });
      test('liquid $n nodes', () {
        _expectClean(layoutLiquid(count: n, labels: labels), 'liquid');
      });
    }
  }

  for (final n in [2, 3, 4]) {
    test('ark exit $n nodes', () {
      final layout = layoutArkExit(count: n, labels: _long.take(n).toList());
      expect(layout.nodes, hasLength(4));
      _expectClean(layout, 'ark exit');
    });
  }

  test('the odd count puts the padlock on the middle node', () {
    expect(layoutBoltz(count: 3, incoming: false, labels: _long).lockIndex, 1);
    expect(layoutBoltz(count: 4, incoming: false, labels: _long).lockIndex, -1);
  });

  test('the Lightning circuit stays inside the frame', () {
    for (final incoming in [false, true]) {
      for (final o in lightningTrace(incoming: incoming)) {
        expect(paymentFrame.inflate(0).contains(o), isTrue, reason: '$o');
      }
    }
  });

  group('terminal badge', () {
    for (final incoming in [false, true]) {
      for (final n in [2, 3, 4]) {
        test('keeps clear of every node, label and stroke ($n, $incoming)', () {
          final layouts = {
            'bitcoin': layoutBitcoin(count: n, labels: _long.take(n).toList()),
            'liquid': layoutLiquid(count: n, labels: _long.take(n).toList()),
            'ark': layoutArk(count: n, labels: _long.take(n).toList()),
            'exit': layoutArkExit(count: n, labels: _long.take(n).toList()),
            'boltz': layoutBoltz(
              count: n,
              incoming: incoming,
              labels: _long.take(n).toList(),
              refund: true,
            ),
            'lightning': layoutLightning(
              count: n,
              incoming: incoming,
              labels: _long.take(n).toList(),
            ),
            'payjoin': layoutPayjoin(
              count: n,
              incoming: incoming,
              labels: _longer.take(n).toList(),
            ),
          };
          for (final entry in layouts.entries) {
            final spot = placePaymentBadge(entry.value.ink);
            final box = Rect.fromCenter(
              center: spot.center,
              width: spot.size,
              height: spot.size,
            );
            expect(
              paymentFrame.contains(box.topLeft) &&
                  paymentFrame.contains(box.bottomRight),
              isTrue,
              reason: '${entry.key} $box',
            );
            for (final label in entry.value.labels) {
              expect(
                box.overlaps(label),
                isFalse,
                reason: '${entry.key} label',
              );
            }
            for (final node in entry.value.nodes) {
              expect(box.contains(node), isFalse, reason: '${entry.key} node');
            }
            for (final stroke in entry.value.strokes) {
              expect(
                _crosses(stroke, box),
                isFalse,
                reason: '${entry.key} stroke',
              );
            }
          }
        });
      }
    }
  });
}
