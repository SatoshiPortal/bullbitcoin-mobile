import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/keychain_recovery/public/keychain_recovery_facade.dart';
import 'package:bb_mobile/features/lightning_address/public/lightning_address_facade.dart';
import 'package:bb_mobile/features/payment_page/public/payment_page_facade.dart';
import 'package:bb_mobile/features/pos/public/pos_facade.dart';
import 'package:bb_mobile/features/remote_keychain_recovery/domain/recover_remote_keychain_manifest_usecase.dart';
import 'package:bb_mobile/features/remote_keychain_recovery/domain/remote_keychain_recovery_result.dart';
import 'package:bb_mobile/features/remote_keychain_recovery/domain/usecases/heal_recovered_products_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  late _ManifestFacade manifest;
  late _RecoveryFacade recovery;
  late _LightningAddressFacade lightningAddress;
  late _PaymentPageFacade paymentPage;
  late _PosFacade pos;
  late HealRecoveredProductsUsecase heal;
  late RecoverRemoteKeychainManifestUsecase usecase;

  setUp(() {
    manifest = _ManifestFacade();
    recovery = _RecoveryFacade();
    lightningAddress = _LightningAddressFacade();
    paymentPage = _PaymentPageFacade();
    pos = _PosFacade();
    heal = HealRecoveredProductsUsecase(lightningAddress, paymentPage, pos);
    usecase = RecoverRemoteKeychainManifestUsecase(
      manifest: manifest,
      recovery: recovery,
      healRecoveredProducts: heal,
    );
  });

  test(
    'absence completes recovery without attempting wallet restore',
    () async {
      when(manifest.fetchRemoteImportPlan).thenAnswer(
        (_) async => const KeychainManifestRemoteImportResult.absent(),
      );

      final result = await usecase.execute();

      expect(result.status, RemoteKeychainRecoveryStatus.noBackup);
      verifyNoMoreInteractions(recovery);
    },
  );

  test('modeled service failures remain non-fatal outcomes', () async {
    when(manifest.fetchRemoteImportPlan).thenAnswer(
      (_) async => const KeychainManifestRemoteImportResult.unavailable(),
    );

    final result = await usecase.execute();

    expect(result.status, RemoteKeychainRecoveryStatus.unavailable);
  });

  test('unexpected local failures are not mislabeled as service outages', () {
    when(manifest.fetchRemoteImportPlan).thenThrow(StateError('database'));

    expect(usecase.execute(), throwsStateError);
  });

  test(
    'automatically heals products flagged by a successful restore',
    () async {
      final plan = KeychainManifestImportPlan(
        parentFingerprint: 'fedcba98',
        entries: [],
      );
      const intent = KeychainRecoveryWalletIntent(
        entryId: "fedcba98:39'/0'/12'/101'",
        reservationId: 'lightning_address_wallet_seed',
        bip85DerivationPath: "39'/0'/12'/101'",
        walletId: 'lightning-wallet',
        childSeedFingerprint: '0123abcd',
        network: Network.liquidMainnet,
        scriptType: ScriptType.bip84,
      );
      when(manifest.fetchRemoteImportPlan).thenAnswer(
        (_) async => KeychainManifestRemoteImportResult.success(plan),
      );
      when(() => recovery.restoreWallets(plan)).thenAnswer(
        (_) async => const KeychainRecoveryResult(
          walletOutcomes: [
            KeychainRecoveryWalletRestoreOutcome(
              intent: intent,
              status: KeychainRecoveryWalletRestoreStatus
                  .requiresProductReactivation,
              materializedWalletId: 'lightning-wallet',
              wasCreated: true,
            ),
          ],
        ),
      );

      final result = await usecase.execute();

      expect(result.status, RemoteKeychainRecoveryStatus.restored);
      expect(result.createdWalletIds, ['lightning-wallet']);
      expect(lightningAddress.ensureCalls, 1);
      expect(
        result.healOutcome?.lightningAddress?.liveness,
        LightningAddressRegistrationLiveness.live,
      );
    },
  );

  test(
    'does not report an existing reactivated wallet as newly created',
    () async {
      final plan = KeychainManifestImportPlan(
        parentFingerprint: 'fedcba98',
        entries: [],
      );
      const intent = KeychainRecoveryWalletIntent(
        entryId: "fedcba98:39'/0'/12'/101'",
        reservationId: 'lightning_address_wallet_seed',
        bip85DerivationPath: "39'/0'/12'/101'",
        walletId: 'lightning-wallet',
        childSeedFingerprint: '0123abcd',
        network: Network.liquidMainnet,
        scriptType: ScriptType.bip84,
      );
      when(manifest.fetchRemoteImportPlan).thenAnswer(
        (_) async => KeychainManifestRemoteImportResult.success(plan),
      );
      when(() => recovery.restoreWallets(plan)).thenAnswer(
        (_) async => const KeychainRecoveryResult(
          walletOutcomes: [
            KeychainRecoveryWalletRestoreOutcome(
              intent: intent,
              status: KeychainRecoveryWalletRestoreStatus
                  .requiresProductReactivation,
              materializedWalletId: 'lightning-wallet',
              wasCreated: false,
            ),
          ],
        ),
      );

      final result = await usecase.execute();

      expect(result.createdWalletIds, isEmpty);
    },
  );
}

final class _ManifestFacade extends Mock implements KeychainManifestFacade {}

final class _RecoveryFacade extends Mock implements KeychainRecoveryFacade {}

final class _PaymentPageFacade extends Mock implements PaymentPageFacade {}

final class _PosFacade extends Mock implements PosFacade {}

final class _LightningAddressFacade implements LightningAddressFacade {
  int ensureCalls = 0;

  @override
  Future<LightningAddressHealOutcome> ensureRegistrationLive() async {
    ensureCalls += 1;
    return const LightningAddressHealOutcome(
      liveness: LightningAddressRegistrationLiveness.live,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
