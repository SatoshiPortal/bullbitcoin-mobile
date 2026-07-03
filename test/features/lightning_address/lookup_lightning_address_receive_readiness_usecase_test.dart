import 'package:bb_mobile/features/lightning_address/domain/lightning_address_error.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_registration.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_wallet.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/lookup_lightning_address_receive_readiness_usecase.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/lookup_wallet_owned_lightning_address_registration_usecase.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/prepare_lightning_address_wallet_usecase.dart';
import 'package:test/test.dart';

void main() {
  late _FakeLookupWalletOwnedLightningAddressRegistrationUsecase lookup;
  late _FakePrepareLightningAddressWalletUsecase prepareWallet;
  late LookupLightningAddressReceiveReadinessUsecase usecase;

  setUp(() {
    lookup = _FakeLookupWalletOwnedLightningAddressRegistrationUsecase();
    prepareWallet = _FakePrepareLightningAddressWalletUsecase();
    usecase = LookupLightningAddressReceiveReadinessUsecase(
      lookupRegistration: lookup,
      prepareWallet: prepareWallet,
    );
  });

  test('inactive registration does not prepare the receive wallet', () async {
    lookup.status = const LightningAddressStatus(nym: 'alice', active: false);

    final result = await usecase.execute();

    expect(lookup.executeCalls, 1);
    expect(prepareWallet.executeCalls, 0);
    expect(result.registration.nym, 'alice');
    expect(result.receiveReady, false);
  });

  test('active registration prepares the receive wallet', () async {
    lookup.status = const LightningAddressStatus(nym: 'alice', active: true);

    final result = await usecase.execute();

    expect(lookup.executeCalls, 1);
    expect(prepareWallet.executeCalls, 1);
    expect(result.registration.nym, 'alice');
    expect(result.receiveReady, true);
  });

  test('active registration reports local readiness failures', () async {
    lookup.status = const LightningAddressStatus(nym: 'alice', active: true);
    prepareWallet.error = LightningAddressException.localPreparationFailed(
      code: 'MetadataFailed',
      retryable: true,
    );

    final result = await usecase.execute();

    expect(result.registration.nym, 'alice');
    expect(result.registration.active, true);
    expect(result.receiveReady, false);
    expect(result.localSetupFailed, true);
    expect(result.localSetupRetryable, true);
  });

  test('active registration preserves non-retryable setup failures', () async {
    lookup.status = const LightningAddressStatus(nym: 'alice', active: true);
    prepareWallet.error = LightningAddressException.localPreparationFailed(
      code: 'ManifestConflict',
      retryable: false,
    );

    final result = await usecase.execute();

    expect(result.registration.active, true);
    expect(result.receiveReady, false);
    expect(result.localSetupFailed, true);
    expect(result.localSetupRetryable, false);
  });
}

class _FakeLookupWalletOwnedLightningAddressRegistrationUsecase
    implements LookupWalletOwnedLightningAddressRegistrationUsecase {
  int executeCalls = 0;
  LightningAddressStatus status = const LightningAddressStatus(
    nym: '',
    active: false,
  );

  @override
  Future<LightningAddressStatus> execute() async {
    executeCalls += 1;
    return status;
  }
}

class _FakePrepareLightningAddressWalletUsecase
    implements PrepareLightningAddressWalletUsecase {
  int executeCalls = 0;
  Object? error;

  @override
  Future<PreparedLightningAddressWallet> execute() async {
    executeCalls += 1;
    final error = this.error;
    if (error != null) throw error;
    return const PreparedLightningAddressWallet(
      walletId: 'la-wallet',
      ctDescriptor: 'ct-desc',
      created: false,
    );
  }
}
