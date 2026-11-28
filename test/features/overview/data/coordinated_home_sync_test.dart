import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:overview/overview.dart';
import 'package:overview/setup.dart';
import 'package:sync/sync.dart';

class _Coordinator extends Mock
    implements SyncCoordinator<WalletKey, SyncFailure> {}

void main() {
  late _Coordinator coordinator;
  late CoordinatedHomeSync home;

  setUpAll(() => registerFallbackValue(SyncTrigger.automatic));

  setUp(() {
    coordinator = _Coordinator();
    home = CoordinatedHomeSync(coordinator);
  });

  for (final mixed in [false, true]) {
    test('busy classification preserves mixed failures: $mixed', () async {
      when(() => coordinator.sync(trigger: any(named: 'trigger'))).thenThrow(
        SyncCoordinatorException({
          SyncKind.bitcoin: const WalletSnapshotException(SyncBusyFailure()),
          if (mixed) SyncKind.liquid: Exception('connection'),
        }),
      );
      expect(
        await home.sync(trigger: SyncTrigger.automatic),
        mixed ? HomeSyncOutcome.failed : HomeSyncOutcome.busy,
      );
    });
  }

  test('completed pass forwards its trigger', () async {
    when(() => coordinator.sync(trigger: any(named: 'trigger')))
        .thenAnswer((_) async {});
    expect(
      await home.sync(trigger: SyncTrigger.user),
      HomeSyncOutcome.completed,
    );
    verify(() => coordinator.sync(trigger: SyncTrigger.user)).called(1);
  });

  test('coordinator exceptions map to the failed outcome', () async {
    for (final error in [
      Exception('electrum.blockstream.info:50002 handshake failed: cert'),
      SyncCoordinatorException({
        SyncKind.bitcoin: Exception('bdk: Descriptor(Key(InvalidKey))'),
      }),
    ]) {
      when(() => coordinator.sync(trigger: any(named: 'trigger')))
          .thenThrow(error);
      expect(
        await home.sync(trigger: SyncTrigger.automatic),
        HomeSyncOutcome.failed,
        reason: error.runtimeType.toString(),
      );
    }
  });
}
