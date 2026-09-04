import 'package:bull_logger/bull_logger.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_tor/tor.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

final class _Wallets implements RecoverBullWalletRepository {
  @override
  Future<List<RecoverBullWallet>> getWallets({
    bool onlyBitcoin = false,
    bool onlyDefaults = false,
    RecoverBullNetwork? network,
  }) async => const [];
}

final class _Seeds implements RecoverBullSeedPort {
  @override
  Future<RecoverBullSeedMaterial> getSeed(String masterFingerprint) async =>
      RecoverBullSeedMaterial(bytes: const [1], mnemonicWords: const ['word']);
}

final class _DefaultWallets implements RecoverBullDefaultWalletsPort {
  @override
  Future<List<RecoverBullWallet>> execute({
    required List<String> mnemonicWords,
  }) async => const [];
}

final class _Settings implements RecoverBullSettingsPort {
  @override
  Future<RecoverBullTorSettings> fetch() async =>
      const RecoverBullTorSettings(useTorProxy: false, torProxyPort: 9050);
}

final class _Lifecycle implements RecoverBullLifecyclePort {
  @override
  Future<void> markStored() async {}

  @override
  Future<void> markVerified() async {}
}

final class _Monitoring implements RecoverBullAttemptMonitoringController {
  @override
  Stream<List<RecoverBullAttemptAlert>> get alerts => const Stream.empty();

  @override
  bool get enabled => false;

  @override
  Future<void> acknowledge(RecoverBullAttemptAlert alert) async {}

  @override
  Future<List<RecoverBullAttemptAlert>> check() async => const [];

  @override
  Future<List<RecoverBullAttemptAlert>> checkOnColdLaunch() async => const [];

  @override
  Future<void> setEnabled(bool enabled) async {}

  @override
  Future<RecoverBullMonitoringStatus> status() async =>
      const RecoverBullMonitoringStatus(
        enabled: false,
        monitoredCount: 0,
        lastSuccessfulCheck: null,
      );
}

void main() {
  test('barrel exposes the supported semantic API', () {
    _compilePublicApi();
  });
}

void _compilePublicApi() {
  const config = RecoverBullConfig(databasePath: 'unused');
  void timing(String phase, int durationMilliseconds, String outcome) {}
  final RecoverBullTiming timingType = timing;
  final status = const RecoverBullStatus.initial();
  final unavailable = const RecoverBullStatus.unavailable();
  final lifecycle = RecoverBullLifecycle();
  final serverSettings = RecoverBullServerSettings(
    server: Uri.parse('https://example.com'),
    permissionGranted: false,
  );
  const result = RecoverBullRecoveryResult(restored: false);
  final alerts = RecoverBullAttemptAlertKind.values
      .map(RecoverBullAttemptAlert.new)
      .toList();
  final controller = _Monitoring();
  final warningWidget = RecoverBullAttemptAlertWarnings(controller: controller);

  final networks = [RecoverBullNetwork.mainnet, RecoverBullNetwork.testnet];
  final health = [
    RecoverBullHealth.online,
    RecoverBullHealth.offline,
    RecoverBullHealth.timeout,
  ];
  final flows = [
    RecoverBullFlow.secureVault,
    RecoverBullFlow.recoverVault,
    RecoverBullFlow.testVault,
    RecoverBullFlow.viewVaultKey,
    RecoverBullFlow.settings,
  ];
  final routes = RecoverBullRoute.values;
  final driveRoutes = RecoverBullGoogleDriveRoute.values;
  final EncryptedVault Function({required String file}) vaultConstructor =
      EncryptedVault.new;
  final extra = RecoverBullFlowsExtra(flow: RecoverBullFlow.recoverVault);
  final localizations = RecoverBullLocalizations.supportedLocales;
  final delegate = RecoverBullLocalizations.delegate;
  final defaultUrl = recoverBullDefaultServerUrl;

  final walletRepository = _Wallets();
  final seedPort = _Seeds();
  final defaultWalletsPort = _DefaultWallets();
  final settingsPort = _Settings();
  final lifecyclePort = _Lifecycle();
  final wallet = const RecoverBullWallet(
    id: 'id',
    masterFingerprint: 'fingerprint',
    network: RecoverBullNetwork.mainnet,
    isPhysicalBackupTested: false,
  );
  final seedMaterial = RecoverBullSeedMaterial(
    bytes: const [1],
    mnemonicWords: const ['word'],
  );
  const network = RecoverBullNetwork.mainnet;
  const torSettings = RecoverBullTorSettings(
    useTorProxy: false,
    torProxyPort: 9050,
  );

  Future<RecoverBullFeature> Function({
    required RecoverBullConfig config,
    required RecoverBullWalletRepository wallets,
    required RecoverBullSeedPort seeds,
    required RecoverBullDefaultWalletsPort defaultWallets,
    required RecoverBullSettingsPort settings,
    required Tor tor,
    required LogSink log,
    RecoverBullTiming? timing,
    Future<void> Function()? onWalletUpdated,
  })
  create = RecoverBullFeature.create;
  void open(BuildContext context) =>
      openRecoverBullFlow(context, flow: RecoverBullFlow.recoverVault);

  void compileFeature(RecoverBullFeature feature) {
    Future<RecoverBullRecoveryResult> Function({
      required String encryptedBackup,
      required String password,
    })
    recoverBackup = feature.recoverBackup;
    Future<bool> Function() ensureTorReady = feature.ensureTorReady;
    Future<RecoverBullHealth> Function() checkService = feature.checkService;
    Future<RecoverBullStatus> Function() readStatus = feature.status;
    Future<RecoverBullServerSettings> Function() readSettings =
        feature.serverSettings;
    Future<void> Function(Uri) setServer = feature.setServer;
    Future<void> Function(bool) setPermission = feature.setPermission;
    Future<void> Function() markStored = feature.markBackupStored;
    Future<void> Function() markVerified = feature.markBackupVerified;
    List<RouteBase> routes = feature.routes;
    RecoverBullAttemptMonitoringController monitoring =
        feature.attemptMonitoring;
    recoverBackup;
    ensureTorReady;
    checkService;
    readStatus;
    readSettings;
    setServer;
    setPermission;
    markStored;
    markVerified;
    routes;
    monitoring;
  }

  config;
  timing;
  timingType;
  status;
  unavailable;
  lifecycle;
  serverSettings;
  result;
  alerts;
  warningWidget;
  networks;
  health;
  flows;
  routes;
  driveRoutes;
  vaultConstructor;
  extra;
  localizations;
  delegate;
  defaultUrl;
  walletRepository;
  seedPort;
  defaultWalletsPort;
  settingsPort;
  lifecyclePort;
  wallet;
  seedMaterial;
  network;
  torSettings;
  create;
  open;
  compileFeature;
}
