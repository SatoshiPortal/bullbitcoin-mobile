import 'package:bb_mobile/core/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_client_port.dart';
import 'package:bb_mobile/features/get_paid_settings/public/get_paid_settings_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/lightning_address/public/lightning_address_facade.dart';
import 'package:bb_mobile/features/payment_page/public/payment_page_facade.dart';
import 'package:bb_mobile/features/pos/public/pos_facade.dart';
import 'package:bb_mobile/features/remote_keychain_recovery/public/remote_keychain_recovery_facade.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/fake_bullnym_client.dart';

// SPEC-POS-01 - the fake-backed Point of Sale lifecycle round-trip.
//
// AUTHORED-BUT-CI-ONLY (flagged deviation, same rationale as SPEC-PP-01 /
// get_paid_backup_roundtrip_test.dart): excluded from the aggregated L1 suite
// (tool/gen_all_test.dart skip set) because the live app-startup timers/blocs
// make an app-process run non-deterministic. The deterministic gates for this
// feature are the L0 usecase/cubit suites; this file is retained for a
// dedicated CI job with a per-test fake-backed harness.

const _nym = 'alice';
const _mnemonicWords = <String>[
  'zoo',
  'zoo',
  'zoo',
  'zoo',
  'zoo',
  'zoo',
  'zoo',
  'zoo',
  'zoo',
  'zoo',
  'zoo',
  'wrong',
];

Future<void> main({bool isInitialized = false}) async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (!isInitialized) await Bull.init();

  test('provision -> backup -> recover restores wallet 103, and the '
      'DG-3 heal classifies the POS read-only', () async {
    final bullnym = FakeBullnymClient();
    await locator.unregister<BullnymClientPort>();
    locator.registerLazySingleton<BullnymClientPort>(() => bullnym);
    await locator<CreateDefaultWalletsUsecase>().execute(
      mnemonicWords: _mnemonicWords,
    );

    // Register the nym (creates wallet 101) then provision the POS (derives +
    // records wallet 103 and saves the row with descriptor + kind=pos).
    await locator<LightningAddressFacade>().registerWalletOwned(nym: _nym);
    final created = await locator<PosFacade>().provision(
      const PosProvisionCommand(label: 'My Till', displayCurrency: 'CAD'),
    );
    expect(created.nym, _nym);
    expect(created.isActive, isTrue);
    expect(created.terminalUrl, endsWith('/$_nym/pos'));
    final savedRequest = bullnym.saveDonationPageCalls.single;
    expect(savedRequest.ctDescriptor, isNotEmpty);
    expect(savedRequest.kind, 'pos');
    expect(savedRequest.enabled, isTrue);
    final writesAfterCreate = bullnym.totalDonationWriteCalls;

    await locator<GetPaidSettingsFacade>().setAutomatedBackupEnabled(true);
    await locator<KeychainManifestFacade>().backupNow();
    final recovered = await locator<RemoteKeychainRecoveryFacade>().recover();
    expect(recovered.status, RemoteKeychainRecoveryStatus.restored);
    expect(recovered.restoredCount, greaterThan(0));
    expect(recovered.healOutcome?.pos?.liveness, PosLiveness.live);

    // The DG-3 heal is read-only: recovery must not have written to the POS.
    expect(bullnym.totalDonationWriteCalls, writesAfterCreate);

    bullnym.posMode = FakePosMode.normal;
    final live = await locator<PosFacade>().ensurePosLive();
    expect(live.liveness, PosLiveness.live);

    bullnym.posMode = FakePosMode.archived;
    final archived = await locator<PosFacade>().ensurePosLive();
    expect(archived.liveness, PosLiveness.archivedByUser);

    bullnym.posMode = FakePosMode.missing;
    final missing = await locator<PosFacade>().ensurePosLive();
    expect(missing.liveness, PosLiveness.needsReactivation);

    expect(bullnym.totalDonationWriteCalls, writesAfterCreate);
  });

  test(
    'coexistence: a Donation Page (102) and a POS (103) under one nym are '
    'independent - provisioning/healing one never touches the other',
    () async {
      final bullnym = FakeBullnymClient();
      await locator.unregister<BullnymClientPort>();
      locator.registerLazySingleton<BullnymClientPort>(() => bullnym);
      await locator<CreateDefaultWalletsUsecase>().execute(
        mnemonicWords: _mnemonicWords,
      );

      await locator<LightningAddressFacade>().registerWalletOwned(nym: _nym);

      final page = await locator<PaymentPageFacade>().save(
        const SavePaymentPageCommand(
          header: 'Tip me',
          description: 'Support my work',
          displayCurrency: 'CAD',
        ),
      );
      expect(page.isActive, isTrue);

      await locator<PosFacade>().provision(
        const PosProvisionCommand(label: 'My Till', displayCurrency: 'CAD'),
      );

      final foundPage = await locator<PaymentPageFacade>().find(nym: _nym);
      final foundPos = await locator<PosFacade>().find(nym: _nym);
      expect(foundPage, isNotNull);
      expect(foundPos, isNotNull);
      expect(foundPage!.header, 'Tip me');
      expect(foundPos!.label, 'My Till');
      expect(foundPage.isActive, isTrue);
      expect(foundPos.isActive, isTrue);

      await locator<PosFacade>().archive();
      final pageAfterPosArchive = await locator<PaymentPageFacade>().find(
        nym: _nym,
      );
      expect(pageAfterPosArchive, isNotNull);
      expect(pageAfterPosArchive!.isActive, isTrue);
    },
  );
}
