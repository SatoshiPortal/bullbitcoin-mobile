import 'package:ark/ark.dart';
import 'package:ark/src/data/ark_codec.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

void main() {
  final account = ArkAccountId(
    parent: Fingerprint('12345678'),
    network: BitcoinNetwork.regtest,
    serverIdentity: 'codec-fixture',
  );
  ArkSnapshot snapshot({ArkExitPhase? phase, int? height}) => ArkSnapshot(
    account: account,
    revision: 7,
    observedAt: DateTime.utc(2026, 11, 19),
    stale: false,
    tipHeight: 620,
    serverInfo: const ArkServerInfo(
      publicKey: 'public-server-key',
      serverUri: null,
      vtxoExitDelta: 144,
      htlcSendExpiryDelta: 72,
      htlcExpiryDelta: 36,
      roundNonceCount: 5,
    ),
    exitDetails: [
      ArkExit(
        id: 'public-vtxo',
        amount: Sats.fromInt(60000),
        status: ArkExitStatus.pending,
        phase: phase,
        confirmedHeight: height,
        claimableHeight: 744,
      ),
    ],
  );

  for (final phase in ArkExitPhase.values) {
    test(
      'display phase $phase round-trips without changing admission status',
      () {
        final decoded = snapshotFromJson(
          snapshotToJson(snapshot(phase: phase, height: 600)),
        );
        final exit = decoded.exitDetails.single;
        expect(exit.phase, phase);
        expect(exit.confirmedHeight, 600);
        expect(exit.claimableHeight, 744);
        expect(exit.status, ArkExitStatus.pending);
        expect(decoded.revision, 7);
      },
    );
  }

  test(
    'legacy and unknown presentation phases preserve the financial snapshot',
    () {
      final value = snapshotToJson(snapshot());
      final exit =
          (value['exitDetails'] as List).single as Map<String, Object?>;
      exit.remove('phase');
      exit.remove('confirmedHeight');
      final server = value['server'] as Map<String, Object?>;
      for (final key in [
        'exitDelta',
        'htlcSendDelta',
        'htlcDelta',
        'roundNonces',
      ]) {
        server.remove(key);
      }
      final legacy = snapshotFromJson(value);
      expect(legacy.exitDetails.single.phase, isNull);
      expect(legacy.exitDetails.single.confirmedHeight, isNull);
      expect(legacy.exitDetails.single.status, ArkExitStatus.pending);
      expect(legacy.serverInfo?.vtxoExitDelta, isNull);
      exit['phase'] = 'future-native-phase';
      expect(snapshotFromJson(value).exitDetails.single.phase, isNull);
    },
  );

  test(
    'server endpoint provenance is optional and malformed values stay unknown',
    () {
      final value = snapshotToJson(snapshot());
      final server = value['server'] as Map<String, Object?>;
      for (final invalid in [
        null,
        3,
        'relative-path',
        'file:///tmp/server',
        'https://user:password@example.test',
        'https://example.test/#fragment',
      ]) {
        server['serverUri'] = invalid;
        expect(snapshotFromJson(value).serverInfo?.serverUri, isNull);
      }
      server['serverUri'] = 'http://127.0.0.1:3535';
      expect(
        snapshotFromJson(value).serverInfo?.serverUri,
        Uri.parse('http://127.0.0.1:3535'),
      );
    },
  );

  test(
    'native server display facts survive storage without a countdown or status',
    () {
      final value = snapshotToJson(snapshot());
      final info = snapshotFromJson(value).serverInfo;
      expect(info?.vtxoExitDelta, 144);
      expect(info?.htlcSendExpiryDelta, 72);
      expect(info?.htlcExpiryDelta, 36);
      expect(info?.roundNonceCount, 5);
      expect(
        (value['server'] as Map).containsKey('nextRoundStartTime'),
        isFalse,
      );
    },
  );
}
