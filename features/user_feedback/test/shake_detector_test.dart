import 'package:flutter_test/flutter_test.dart';
import 'package:user_feedback/src/shake_detector.dart';

void main() {
  final start = DateTime(2026, 11, 24, 12);
  DateTime at(int ms) => start.add(Duration(milliseconds: ms));

  bool strong(ShakeDetector detector, int ms) =>
      detector.add(x: 20, y: 0, z: 0, at: at(ms));

  test('three strong jolts within the window make one shake', () {
    final detector = ShakeDetector();

    expect(strong(detector, 0), isFalse);
    expect(strong(detector, 200), isFalse);
    expect(strong(detector, 400), isTrue);
  });

  test('gentle movement never counts', () {
    final detector = ShakeDetector();

    for (var ms = 0; ms < 2000; ms += 50) {
      expect(detector.add(x: 5, y: 5, z: 5, at: at(ms)), isFalse);
    }
  });

  test('jolts spread wider than the window do not add up', () {
    final detector = ShakeDetector();

    expect(strong(detector, 0), isFalse);
    expect(strong(detector, 900), isFalse);
    expect(strong(detector, 1800), isFalse);
  });

  test('a shake is followed by a cooldown, then can fire again', () {
    final detector = ShakeDetector();
    strong(detector, 0);
    strong(detector, 100);
    expect(strong(detector, 200), isTrue);

    // Still shaking during the cooldown: ignored.
    for (var ms = 300; ms < 3200; ms += 100) {
      expect(strong(detector, ms), isFalse);
    }

    strong(detector, 3300);
    strong(detector, 3400);
    expect(strong(detector, 3500), isTrue);
  });
}
