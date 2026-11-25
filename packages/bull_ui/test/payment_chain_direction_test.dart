import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bull_ui/src/payments/bull_payment_progress.dart';
import 'package:bull_ui/src/payments/payment_scenes.dart';
import 'package:bull_ui/src/theme/payment_animation_palette.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Uint8List> paint(
    BullPaymentNetwork network,
    BullPaymentDirection direction,
    BullPaymentPhase phase, {
    double elapsed = 3,
    double time = 0,
    BullPaymentRefund? refund,
  }) async {
    final recorder = ui.PictureRecorder();
    PaymentScenes().paint(
      ui.Canvas(recorder),
      const ui.Size(336, 696),
      network: network,
      direction: direction,
      phase: phase,
      elapsed: elapsed,
      time: time,
      roll: 0,
      springRoll: 0,
      palette: PaymentAnimationPalette.standard,
      stepCount: 2,
      completed: phase == BullPaymentPhase.success ? 2 : 1,
      refund: refund,
      reduced: true,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(336, 696);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    picture.dispose();
    if (bytes == null) throw StateError('Could not read scene pixels');
    return bytes.buffer.asUint8List();
  }

  int coloredPixels(Uint8List bytes, int top, int bottom) {
    var count = 0;
    for (var y = top; y < bottom; y++) {
      for (var x = 308; x < 325; x++) {
        final i = (y * 336 + x) * 4;
        final red = bytes[i], green = bytes[i + 1], blue = bytes[i + 2];
        if ((red - green).abs() > 30 || (green - blue).abs() > 30) count++;
      }
    }
    return count;
  }

  for (final network in [
    BullPaymentNetwork.bitcoin,
    BullPaymentNetwork.liquid,
  ]) {
    for (final phase in [BullPaymentPhase.sending, BullPaymentPhase.success]) {
      test(
        '$network $phase shares a scene with a static direction cue',
        () async {
          final send = await paint(
            network,
            BullPaymentDirection.outgoing,
            phase,
          );
          final receive = await paint(
            network,
            BullPaymentDirection.incoming,
            phase,
          );
          expect(
            coloredPixels(send, 226, 241),
            greaterThan(coloredPixels(receive, 226, 241)),
          );
          expect(
            coloredPixels(receive, 400, 415),
            greaterThan(coloredPixels(send, 400, 415)),
          );
          var different = false;
          for (var y = 0; y < 696; y++) {
            for (var x = 0; x < 306; x++) {
              final i = (y * 336 + x) * 4;
              if (send[i] != receive[i] ||
                  send[i + 1] != receive[i + 1] ||
                  send[i + 2] != receive[i + 2]) {
                different = true;
                break;
              }
            }
            if (different) break;
          }
          expect(
            different,
            isFalse,
            reason: 'only the direction cue may differ',
          );
        },
      );
    }
  }

  test('Bitcoin block remains fixed after confirmation and failure', () async {
    for (final direction in BullPaymentDirection.values) {
      final failed = await paint(
        BullPaymentNetwork.bitcoin,
        direction,
        BullPaymentPhase.failed,
        time: 40,
      );
      final laterFailed = await paint(
        BullPaymentNetwork.bitcoin,
        direction,
        BullPaymentPhase.failed,
        elapsed: 9,
        time: 90,
      );
      final confirmed = await paint(
        BullPaymentNetwork.bitcoin,
        direction,
        BullPaymentPhase.success,
        time: 20,
      );
      final laterConfirmed = await paint(
        BullPaymentNetwork.bitcoin,
        direction,
        BullPaymentPhase.success,
        elapsed: 9,
        time: 90,
      );
      for (var y = 245; y < 395; y++) {
        for (var x = 150; x < 260; x++) {
          final i = (y * 336 + x) * 4;
          for (var channel = 0; channel < 4; channel++) {
            expect(failed[i + channel], laterFailed[i + channel]);
            expect(confirmed[i + channel], laterConfirmed[i + channel]);
          }
        }
      }
    }
  });

  test('only success paints the green terminal badge', () async {
    int greenPixels(Uint8List bytes) {
      var count = 0;
      for (var y = 170; y < 470; y++) {
        for (var x = 34; x < 302; x++) {
          final i = (y * 336 + x) * 4;
          if (bytes[i] < 90 && bytes[i + 1] > 180 && bytes[i + 2] < 110) {
            count++;
          }
        }
      }
      return count;
    }

    final success = await paint(
      BullPaymentNetwork.bitcoin,
      BullPaymentDirection.incoming,
      BullPaymentPhase.success,
    );
    final failure = await paint(
      BullPaymentNetwork.bitcoin,
      BullPaymentDirection.incoming,
      BullPaymentPhase.failed,
    );
    final refunded = await paint(
      BullPaymentNetwork.bitcoin,
      BullPaymentDirection.incoming,
      BullPaymentPhase.failed,
      refund: BullPaymentRefund.done,
    );
    final refundable = await paint(
      BullPaymentNetwork.bitcoin,
      BullPaymentDirection.incoming,
      BullPaymentPhase.failed,
      refund: BullPaymentRefund.available,
    );
    expect(greenPixels(success), greaterThan(100));
    expect(greenPixels(failure), 0);
    expect(greenPixels(refunded), 0);
    expect(greenPixels(refundable), 0);
  });
}
