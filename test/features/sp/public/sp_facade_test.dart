import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/sp/domain/usecases/check_sp_wallet_setup_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_feature_gate_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/is_sp_scanning_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_network_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/is_sp_set_up_now_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/prepare_sp_payment_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/sync_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/revoke_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/send_sp_payment_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/validate_sp_amount_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/validate_sp_recipient_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/watch_sp_updates_usecase.dart';
import 'package:bb_mobile/features/sp/public/sp_facade.dart';
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

SpWallet _wallet() => SpWallet(
  spAddress: 'sp1qexample',
  balance: SpBalance(
    confirmedSat: Sats.fromInt(5000),
    totalUnifiedSat: Sats.fromInt(5000),
  ),
  isScanning: false,
);

void main() {
  late MockGetSpWalletUsecase getSpWallet;
  late MockIsSpScanningUsecase isScanning;
  late SpFacade facade;

  setUp(() {
    getSpWallet = MockGetSpWalletUsecase();
    isScanning = MockIsSpScanningUsecase();
    facade = SpFacade(
      getSpWalletUsecase: getSpWallet,
      isSpScanningUsecase: isScanning,
      checkSpWalletSetupUsecase: MockCheckSpWalletSetupUsecase(),
      isSpSetUpNowUsecase: MockIsSpSetUpNowUsecase(),
      getSpFeatureGateUsecase: MockGetSpFeatureGateUsecase(),
      revokeSpWalletUsecase: MockRevokeSpWalletUsecase(),
      watchSpUpdatesUsecase: MockWatchSpUpdatesUsecase(),
      syncSpWalletUsecase: MockSyncSpWalletUsecase(),
      validateSpRecipientUsecase: MockValidateSpRecipientUsecase(),
      validateSpAmountUsecase: MockValidateSpAmountUsecase(),
      getSpNetworkUsecase: MockGetSpNetworkUsecase(),
      prepareSpPaymentUsecase: MockPrepareSpPaymentUsecase(),
      sendSpPaymentUsecase: MockSendSpPaymentUsecase(),
    );
  });

  group('SpFacade.refresh', () {
    test('wraps the GetSpWalletUsecase snapshot as Ok', () async {
      final wallet = _wallet();
      when(() => getSpWallet.execute()).thenAnswer((_) async => Ok(wallet));

      final result = await facade.refresh();

      expect(result, isA<Ok<SpWallet?, SpFailure>>());
      expect((result as Ok<SpWallet?, SpFailure>).value, same(wallet));
      verify(() => getSpWallet.execute()).called(1);
    });

    test('forwards a use case failure unchanged', () async {
      const failure = SpSessionBusy('inner lock held');
      when(
        () => getSpWallet.execute(),
      ).thenAnswer((_) async => const Err<SpWallet?, SpFailure>(failure));

      final result = await facade.refresh();

      // No try/catch in the facade: the adapter is the one boundary that turns
      // a thrown FFI error into a failure, so this only forwards.
      expect((result as Err<SpWallet?, SpFailure>).failure, same(failure));
    });
  });

  group('SpFacade.isScanning', () {
    test('delegates to IsSpScanningUsecase', () {
      when(() => isScanning.execute()).thenReturn(true);

      expect(facade.isScanning, isTrue);
      verify(() => isScanning.execute()).called(1);
    });
  });
}
