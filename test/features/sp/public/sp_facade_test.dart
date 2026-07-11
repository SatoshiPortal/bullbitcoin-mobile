import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/usecases/check_sp_wallet_setup_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_feature_gate_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/is_sp_scanning_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/resync_sp_listener_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/revoke_sp_wallet_usecase.dart';
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

class MockResyncSpListenerUsecase extends Mock
    implements ResyncSpListenerUsecase {}

SpWallet _wallet() => SpWallet(
      spAddress: 'sp1qexample',
      balance: SpBalance(
        confirmedSat: BigInt.from(5000),
        totalUnifiedSat: BigInt.from(5000),
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
      getSpFeatureGateUsecase: MockGetSpFeatureGateUsecase(),
      revokeSpWalletUsecase: MockRevokeSpWalletUsecase(),
      watchSpUpdatesUsecase: MockWatchSpUpdatesUsecase(),
      resyncSpListenerUsecase: MockResyncSpListenerUsecase(),
    );
  });

  group('SpFacade.refresh', () {
    test('wraps the GetSpWalletUsecase snapshot as Ok', () async {
      final wallet = _wallet();
      when(() => getSpWallet.execute()).thenAnswer((_) async => wallet);

      final result = await facade.refresh();

      expect(result, isA<Ok<SpWallet?, SpFailure>>());
      expect((result as Ok<SpWallet?, SpFailure>).value, same(wallet));
      verify(() => getSpWallet.execute()).called(1);
    });

    test('maps a thrown error to Err', () async {
      when(() => getSpWallet.execute()).thenThrow(Exception('boom'));

      final result = await facade.refresh();

      expect(result, isA<Err<SpWallet?, SpFailure>>());
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
