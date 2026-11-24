import 'package:background_tasks/background_tasks.dart';
import 'package:background_tasks/wallet_jobs.dart' show WalletPaymentObserver;
import 'package:bull_ark/ark_wallet_setup.dart';
import 'package:bull_recoverbull/storage.dart' show RecoverBullWalletProperties;
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:notifications/payment_store.dart';
import 'package:overview/setup.dart' show OverviewSynchronization;
import 'package:path_provider/path_provider.dart';
import 'package:preferences/preferences.dart';
import 'package:provisioning/provisioning.dart';
import 'package:secrets/custody.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/storage.dart';
import 'package:settings/settings.dart' show LanguageExtension;
import 'package:signers/storage.dart' show SignerDevices;
import 'package:sync/inventory.dart';
import 'package:sync/storage.dart' show SyncFreshness;
import 'package:sync/sync.dart';
import 'package:sync/write.dart';

/// Composes the native wallet runtime, account provisioning and custody
/// references from their owners' published entry points.
void registerNativeRuntime(
  GetIt locator, {
  required OverviewSynchronization Function() overview,
}) {
  locator.registerLazySingleton<BroadcastObservationFollowUp>(
    () => BroadcastObservationFollowUp(
      spendStatus: (id) => locator<WalletNativeRuntime>().spendStatusOf(id),
      pollWallet: (id, {required isActive}) =>
          overview().coordinator.pollWallet(id, isActive: isActive),
    ),
    dispose: (followUp) => followUp.dispose(),
  );
  locator.registerLazySingleton<WalletProvisioning>(() {
    final native = locator<WalletNativeRuntime>();
    return WalletProvisioning.open(
      inventory: locator<SecretsInventory>(),
      native: native,
      resume: native.resumeProvisioning,
      properties: [
        locator<SignerDevices>(),
        locator<SyncFreshness>(),
        locator<RecoverBullWalletProperties>(),
      ],
    );
  });
  locator.registerLazySingleton<DefaultWalletRepair>(
    () =>
        DefaultWalletRepair(locator<Secrets>(), locator<WalletProvisioning>()),
  );
  locator.registerFactory<DefaultWalletProvisioning>(
    () => DefaultWalletProvisioning(
      secrets: locator<Secrets>(),
      inventory: locator<SecretsInventory>(),
      environment: locator<ActiveEnvironmentReader>(),
      accounts: locator<WalletProvisioning>(),
    ),
  );

  locator.registerLazySingleton<WalletNativeRuntime>(
    () => WalletNativeRuntime.open(
      catalog: locator<WalletCatalogPort>(),
      reserved: locator<ReservedAddressPort>(),
      inputReservations: locator<InputReservationPort>(),
      deleteCatalogEntry: SecretsWalletCatalog.removal(
        locator<SecretsInventory>(),
      ),
      sync: locator<ElectrumSync>(),
      documentsDirectory: () async =>
          (await getApplicationDocumentsDirectory()).path,
      freezes: locator<FreezeStorePort>(),
      connections: locator<WalletConnectionPort>(),
      broadcastObservation: locator<BroadcastObservationFollowUp>(),
      fundingReservations: locator.isRegistered<SqliteArkFundingReservations>()
          ? locator<SqliteArkFundingReservations>()
          : null,
    ),
  );

  locator.registerLazySingleton<WalletCatalogPort>(
    () => SecretsWalletCatalog.foreground(locator<SecretsInventory>()),
  );
  locator.registerLazySingleton<ElectrumSync>(
    () => ElectrumSync(
      readRevision: (key) => locator<WalletNativeRuntime>().readRevision(key),
      connections: locator<WalletConnectionPort>(),
      collectIncoming: backgroundSyncAvailable,
      onCompletion: backgroundSyncAvailable
          ? locator<WalletPaymentObserver>().recordCompletion
          : null,
      documentsDirectory: () async =>
          (await getApplicationDocumentsDirectory()).path,
    ),
  );
  if (backgroundSyncAvailable) {
    locator.registerLazySingleton<PaymentNotificationStore>(
      () => PaymentNotificationStore(
        () async => (await getApplicationDocumentsDirectory()).path,
        () async {
          final settings = (await locator<Preferences>().fetch()).fold(
            (value) => value,
            (_) => throw Exception('Preferences read failed'),
          );
          return PaymentNotifications.gateway(settings.language?.locale);
        },
      ),
      dispose: (store) => store.close(),
    );
    locator.registerLazySingleton<WalletPaymentObserver>(
      () => WalletPaymentObserver.foreground(
        locator<PaymentNotificationStore>().open,
        isForeground: () =>
            WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
      ),
    );
  }
  locator.registerLazySingleton<ForegroundWalletSynchronization>(
    () => ForegroundWalletSynchronization(
      locator<ElectrumSync>(),
      native: locator<WalletNativeRuntime>(),
    ),
  );
  locator.registerLazySingleton<ParentCustodyAdmissionPort>(
    () => SqliteParentCustodyAdmission(
      directory: () async => (await getApplicationDocumentsDirectory()).path,
      mayCreate: true,
    ),
  );
  locator.registerLazySingleton<SeedReferences>(() {
    final references = SeedReferences(
      locator<SecretsInventory>(),
      admission: locator<ParentCustodyAdmissionPort>(),
    );
    // Ark funding holds keep their source seed referenced.
    if (locator.isRegistered<SqliteArkFundingReservations>()) {
      references.register(locator<SqliteArkFundingReservations>());
    } else {
      references.register(
        UnavailableArkFundingReferences(locator<ArkInstallationState>()),
      );
    }
    return references;
  });
}
