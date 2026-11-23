import 'dart:async';

import 'package:primitives/primitives.dart';
import 'package:silent/src/domain/usecases/check_sp_wallet_setup_usecase.dart';
import 'package:silent/src/domain/usecases/get_sp_feature_gate_usecase.dart';
import 'package:silent/src/domain/usecases/get_sp_wallet_usecase.dart';
import 'package:silent/src/domain/usecases/is_sp_scanning_usecase.dart';
import 'package:silent/src/domain/usecases/get_sp_network_usecase.dart';
import 'package:silent/src/domain/usecases/is_sp_set_up_now_usecase.dart';
import 'package:silent/src/domain/usecases/prepare_sp_payment_usecase.dart';
import 'package:silent/src/domain/usecases/sync_sp_wallet_usecase.dart';
import 'package:silent/src/domain/usecases/revoke_sp_wallet_usecase.dart';
import 'package:silent/src/domain/usecases/send_sp_payment_usecase.dart';
import 'package:silent/src/domain/usecases/validate_sp_amount_usecase.dart';
import 'package:silent/src/domain/usecases/validate_sp_recipient_usecase.dart';
import 'package:silent/src/domain/usecases/watch_sp_updates_usecase.dart';
import 'package:silent/src/silent.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetSpWalletUsecase extends Mock implements GetSpWalletUsecase {}

class MockIsSpScanningUsecase extends Mock implements IsSpScanningUsecase {}

class MockCheckSpWalletSetupUsecase extends Mock
    implements CheckSpWalletSetupUsecase {}

class MockGetSpFeatureGateUsecase extends Mock
    implements GetSpFeatureGateUsecase {}

class MockRevokeSpWalletUsecase extends Mock implements RevokeSpWalletUsecase {}

class MockWatchSpUpdatesUsecase extends Mock implements WatchSpUpdatesUsecase {}

class MockSyncSpWalletUsecase extends Mock implements SyncSpWalletUsecase {}

class MockIsSpSetUpNowUsecase extends Mock implements IsSpSetUpNowUsecase {}

class MockGetSpNetworkUsecase extends Mock implements GetSpNetworkUsecase {}

class MockValidateSpAmountUsecase extends Mock
    implements ValidateSpAmountUsecase {}

class MockValidateSpRecipientUsecase extends Mock
    implements ValidateSpRecipientUsecase {}

class MockPrepareSpPaymentUsecase extends Mock
    implements PrepareSpPaymentUsecase {}

class MockSendSpPaymentUsecase extends Mock implements SendSpPaymentUsecase {}

SilentWallet _wallet() => SilentWallet(
  spAddress: 'sp1qexample',
  balance: SilentBalance(
    confirmedSat: Sats.fromInt(5000),
    totalUnifiedSat: Sats.fromInt(5000),
  ),
  isScanning: false,
);

void main() {
  late MockGetSpWalletUsecase getSpWallet;
  late MockIsSpScanningUsecase isScanning;
  late MockGetSpFeatureGateUsecase featureGate;
  late MockWatchSpUpdatesUsecase updates;
  late Silent facade;

  setUp(() {
    getSpWallet = MockGetSpWalletUsecase();
    isScanning = MockIsSpScanningUsecase();
    featureGate = MockGetSpFeatureGateUsecase();
    updates = MockWatchSpUpdatesUsecase();
    facade = SilentCapability(
      getSpWalletUsecase: getSpWallet,
      isSpScanningUsecase: isScanning,
      checkSpWalletSetupUsecase: MockCheckSpWalletSetupUsecase(),
      isSpSetUpNowUsecase: MockIsSpSetUpNowUsecase(),
      getSpFeatureGateUsecase: featureGate,
      revokeSpWalletUsecase: MockRevokeSpWalletUsecase(),
      watchSpUpdatesUsecase: updates,
      syncSpWalletUsecase: MockSyncSpWalletUsecase(),
      validateSpRecipientUsecase: MockValidateSpRecipientUsecase(),
      validateSpAmountUsecase: MockValidateSpAmountUsecase(),
      getSpNetworkUsecase: MockGetSpNetworkUsecase(),
      prepareSpPaymentUsecase: MockPrepareSpPaymentUsecase(),
      sendSpPaymentUsecase: MockSendSpPaymentUsecase(),
    );
  });

  group('Silent.refresh', () {
    test('wraps the GetSpWalletUsecase snapshot as Ok', () async {
      final wallet = _wallet();
      when(() => getSpWallet.execute()).thenAnswer((_) async => Ok(wallet));

      final result = await facade.refresh();

      expect(result, isA<Ok<SilentWallet?, SilentFailure>>());
      expect((result as Ok<SilentWallet?, SilentFailure>).value, same(wallet));
      verify(() => getSpWallet.execute()).called(1);
    });

    test('forwards a use case failure unchanged', () async {
      const failure = SilentSessionBusy('inner lock held');
      when(() => getSpWallet.execute()).thenAnswer(
        (_) async => const Err<SilentWallet?, SilentFailure>(failure),
      );

      final result = await facade.refresh();

      // No try/catch in the facade: the adapter is the one boundary that turns
      // a thrown FFI error into a failure, so this only forwards.
      expect(
        (result as Err<SilentWallet?, SilentFailure>).failure,
        same(failure),
      );
    });
  });

  group('Silent.isScanning', () {
    test('delegates to IsSpScanningUsecase', () {
      when(() => isScanning.execute()).thenReturn(true);

      expect(facade.isScanning, isTrue);
      verify(() => isScanning.execute()).called(1);
    });
  });

  test(
    'feature gate forwards a typed failure instead of reporting disabled',
    () async {
      const failure = SilentUnexpected('preferences unavailable');
      when(() => featureGate.check(allowUnconfigured: true))
          .thenAnswer((_) async => const Err(failure));
      expect(await facade.isFeatureEnabled(), isA<Err<bool, SilentFailure>>());
    },
  );

  test(
    'updates preserve broadcast delivery and model recoverable errors',
    () async {
      final source = StreamController<SilentUpdate>.broadcast();
      when(updates.execute).thenAnswer((_) => source.stream);
      final observed = facade.watchUpdates();
      expect(observed.isBroadcast, isTrue);
      final events = [
        isA<Ok<SilentUpdate, SilentFailure>>(),
        isA<Err<SilentUpdate, SilentFailure>>(),
        isA<Ok<SilentUpdate, SilentFailure>>(),
        emitsDone,
      ];
      final first = expectLater(observed, emitsInOrder(events));
      final second = expectLater(observed, emitsInOrder(events));
      source
        ..add(const SilentSetupChanged())
        ..addError(Exception('foreign stream error'))
        ..add(const SilentSetupChanged());
      await source.close();
      await Future.wait([first, second]);
    },
  );
}
