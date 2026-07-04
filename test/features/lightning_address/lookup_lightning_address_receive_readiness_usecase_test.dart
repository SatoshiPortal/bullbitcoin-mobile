import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
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
  late _FakeGetWalletUsecase getWallet;
  late LookupLightningAddressReceiveReadinessUsecase usecase;

  setUp(() {
    lookup = _FakeLookupWalletOwnedLightningAddressRegistrationUsecase();
    prepareWallet = _FakePrepareLightningAddressWalletUsecase();
    getWallet = _FakeGetWalletUsecase();
    usecase = LookupLightningAddressReceiveReadinessUsecase(
      lookupRegistration: lookup,
      prepareWallet: prepareWallet,
      getWallet: getWallet,
    );
  });

  test('inactive registration does not prepare the receive wallet', () async {
    lookup.status = const LightningAddressStatus(nym: 'alice', active: false);

    final result = await usecase.execute();

    expect(lookup.executeCalls, 1);
    expect(prepareWallet.executeCalls, 0);
    expect(getWallet.executeCalls, 0);
    expect(result.registration.nym, 'alice');
    expect(result.receiveReady, false);
  });

  test('active registration prepares the receive wallet', () async {
    lookup.status = const LightningAddressStatus(nym: 'alice', active: true);
    getWallet.wallet = _wallet(autoSweepEnabled: true);

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
    expect(getWallet.executeCalls, 0);
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

  test('autosweep-enabled metadata confirms the autosweep claim', () async {
    lookup.status = const LightningAddressStatus(nym: 'alice', active: true);
    getWallet.wallet = _wallet(autoSweepEnabled: true);

    final result = await usecase.execute();

    expect(getWallet.walletIds, ['la-wallet']);
    expect(result.receiveReady, true);
    expect(result.autoSweepEnabled, true);
  });

  test(
    'autosweep-disabled metadata does not claim autosweep enabled',
    () async {
      // R2-D1b: defaults are applied only when missing, so a wallet the user
      // opted out of stays opted out. The readiness result must reflect the
      // actual metadata, not the intended default, so the copy never claims
      // autosweep on a wallet where it is off.
      lookup.status = const LightningAddressStatus(nym: 'alice', active: true);
      getWallet.wallet = _wallet(autoSweepEnabled: false);

      final result = await usecase.execute();

      expect(result.receiveReady, true);
      expect(result.autoSweepEnabled, false);
    },
  );

  test('unreadable wallet metadata softens the autosweep claim', () async {
    lookup.status = const LightningAddressStatus(nym: 'alice', active: true);
    getWallet.error = GetWalletException('read failed');

    final result = await usecase.execute();

    // A metadata read failure must not fail readiness - the receive wallet is
    // prepared - but it also must not let the copy over-claim autosweep.
    expect(result.receiveReady, true);
    expect(result.autoSweepEnabled, false);
  });
}

Wallet _wallet({required bool autoSweepEnabled}) {
  return Wallet(
    origin: 'la-wallet',
    label: 'la-wallet',
    network: Network.liquidMainnet,
    masterFingerprint: 'fingerprint',
    xpubFingerprint: 'xpub-fingerprint',
    scriptType: ScriptType.bip84,
    xpub: 'xpub',
    externalPublicDescriptor: 'external-desc',
    internalPublicDescriptor: 'internal-desc',
    signer: SignerEntity.local,
    signerDevice: null,
    balanceSat: BigInt.zero,
    autoSweepEnabled: autoSweepEnabled,
  );
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

class _FakeGetWalletUsecase implements GetWalletUsecase {
  int executeCalls = 0;
  final walletIds = <String>[];
  Wallet? wallet;
  Object? error;

  @override
  Future<Wallet?> execute(String walletId, {bool sync = false}) async {
    executeCalls += 1;
    walletIds.add(walletId);
    final error = this.error;
    if (error != null) throw error;
    return wallet;
  }
}
