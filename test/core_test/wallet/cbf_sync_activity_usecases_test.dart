import 'package:bb_mobile/core/wallet/domain/cbf_sync_activity_port.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/await_cbf_sync_inactive_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_cbf_sync_active_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory fake standing in for a real [CbfSyncActivityPort]
/// implementation. These usecases are pure delegation, so the fake only
/// needs to record calls and let the test script the return value.
class _FakeCbfSyncActivityPort implements CbfSyncActivityPort {
  String? isActiveCalledWith;
  bool isActiveResult = false;

  String? waitUntilInactiveCalledWith;

  @override
  bool isActive({required String walletId}) {
    isActiveCalledWith = walletId;
    return isActiveResult;
  }

  @override
  Future<void> waitUntilInactive({required String walletId}) {
    waitUntilInactiveCalledWith = walletId;
    return Future.value();
  }
}

void main() {
  late _FakeCbfSyncActivityPort fakePort;

  setUp(() {
    fakePort = _FakeCbfSyncActivityPort();
  });

  test(
    'CheckCbfSyncActiveUsecase forwards the walletId and result unchanged',
    () {
      fakePort.isActiveResult = true;
      final usecase = CheckCbfSyncActiveUsecase(cbfSyncActivityPort: fakePort);

      final result = usecase.execute(walletId: 'wallet-1');

      expect(fakePort.isActiveCalledWith, 'wallet-1');
      expect(result, isTrue);
    },
  );

  test('AwaitCbfSyncInactiveUsecase forwards the walletId and resolves once '
      'the port does', () async {
    final usecase = AwaitCbfSyncInactiveUsecase(cbfSyncActivityPort: fakePort);

    await usecase.execute(walletId: 'wallet-2');

    expect(fakePort.waitUntilInactiveCalledWith, 'wallet-2');
  });
}
