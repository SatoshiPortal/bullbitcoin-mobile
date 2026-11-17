import 'package:flutter_test/flutter_test.dart';
import 'package:onion/onion.dart';

void main() {
  const stage =
      '45%: connecting successfully; directory is fetching authority '
      'certificates (9/9)';

  TorStatus status({String stage = stage}) => TorStatus(
    fraction: 0.45,
    readyForTraffic: false,
    stage: stage,
    transport: TorTransport.direct,
  );

  test('carries the stage text Arti reported', () {
    expect(status().stage, stage);
  });

  test('distinguishes snapshots that differ only by stage', () {
    // Two snapshots at the same fraction can be at different stages; a
    // consumer deduplicating events with == must not drop the newer one.
    expect(status(), status());
    expect(status(), isNot(status(stage: '45%: handshaking with Tor relays')));
  });
}
