/// Live Board proof over the composed app against a running regtest stack.
///
/// Skipped unless BULL_ARK_LIVE_BOARD_DIR, BULL_ARK_LIVE_URL,
/// BULL_ARK_LIVE_ESPLORA_URL and BULL_ARK_LIVE_BOARD_PHASE are set. The
/// directory must be private (mode 0700): it keeps the app database, the
/// parent's RecoverBull vault and its key in separate mode 0600 files
/// (written and verified before any address is shown), and the Board
/// operation identity across phases. The keystore itself lives in memory and
/// each later phase restores the parent from the vault. Output is public
/// facts only.
///
/// Phases, each run once and in order:
/// - setup: create the default regtest wallets and print the address to fund.
/// - board: enable Ark, prepare and confirm one Board; never repeated.
/// - confirm: confirm the prepared Board BULL_ARK_LIVE_BOARD_OPERATION once.
/// - observe: synchronize Ark and print the VTXOs and balance.
library;

import 'package:electrum/testing.dart';

import 'package:mempool/testing.dart';

import 'dart:convert';
import 'dart:io';

import 'package:preferences/preferences.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/wallet/data/wallet_repository.dart';
import 'package:bb_mobile/features/wallet/data/ark_foreground_host.dart';
import 'package:bb_mobile/features/wallet/data/wallet_metadata_datasource.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/features/address_view/domain/usecases/get_receive_address_usecase.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/native_libraries.dart';
import 'package:bull_ark/ark_setup.dart' show ArkPreferencesRepository;
import 'package:bull_ark/bull_ark.dart';
import 'package:bull_tor/tor_adapter.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Writes [content] to a new private file, never replacing an existing one.
void _writePrivate(File file, String content) {
  if (file.existsSync()) throw StateError('${file.path} already exists');
  file.createSync();
  Process.runSync('chmod', ['600', file.path]);
  _requireMode(file, '600');
  file.writeAsStringSync(content, flush: true);
}

void _requireMode(FileSystemEntity entity, String mode) {
  final stat = entity.statSync();
  final actual = (stat.mode & 0x1ff).toRadixString(8);
  if (actual != mode) {
    throw StateError('${entity.path} must have mode $mode, has $actual');
  }
}

class _Paths extends PathProviderPlatform {
  final String path;
  _Paths(this.path);
  @override
  Future<String> getApplicationDocumentsPath() async => path;
  @override
  Future<String> getTemporaryPath() async => path;
  @override
  Future<String> getApplicationSupportPath() async => path;
}

class _NativeTor implements TorNativeInitializer {
  @override
  Future<void> initialize() async {}
}

/// Ark On/Off preference kept in the private directory across phases.
class _FilePreferences implements ArkPreferencesRepository {
  final File file;
  _FilePreferences(this.file);
  Map<String, dynamic> _read() => file.existsSync()
      ? jsonDecode(file.readAsStringSync()) as Map<String, dynamic>
      : {};
  @override
  Future<Result<bool, ArkFailure>> isEnabled(ArkAccountId account) async =>
      Ok(_read()['$account'] == true);
  @override
  Future<Result<void, ArkFailure>> setEnabled(
    ArkAccountId account,
    bool enabled,
  ) async {
    file.writeAsStringSync(
      jsonEncode({..._read(), '$account': enabled}),
      flush: true,
    );
    return const Ok(null);
  }
}

T _ok<T>(Result<T, Failure> result, String step) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => throw StateError('$step: $failure'),
};

void _report(String line) {
  // ignore: avoid_print
  print('ark-board-live: $line');
}

void main() {
  final environment = Platform.environment;
  final root = environment['BULL_ARK_LIVE_BOARD_DIR'];
  final arkUrl = environment['BULL_ARK_LIVE_URL'];
  final esploraUrl = environment['BULL_ARK_LIVE_ESPLORA_URL'];
  final phase = environment['BULL_ARK_LIVE_BOARD_PHASE'];
  final skip =
      root == null || arkUrl == null || esploraUrl == null || phase == null
      ? 'live regtest Board proof not configured'
      : null;

  test(
    'Board on-chain BTC into Ark through the composed app',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      // Real Electrum, Esplora and Ark endpoints, not the test HTTP mock.
      HttpOverrides.global = null;
      final directory = Directory(root!);
      _requireMode(directory, '700');
      final vaultFile = File('${directory.path}/parent.vault');
      final keyFile = File('${directory.path}/parent.vault-key');
      final appDirectory = Directory('${directory.path}/app')..createSync();
      Process.runSync('chmod', ['700', appDirectory.path]);
      _requireMode(appDirectory, '700');
      PathProviderPlatform.instance = _Paths(appDirectory.path);
      FakeSecureStoragePlatform().install();
      SharedPreferences.setMockInitialValues({});

      await initFlutterRustBridgeDependencies();
      locator.registerSingleton<TorNativeInitializer>(_NativeTor());
      final database = SqliteDatabase(
        NativeDatabase(File('${appDirectory.path}/bull.sqlite')),
      );
      await AppLocator.setup(
        locator,
        database,
        openElectrum: (readPreferences, tor) async => Ok(
          createElectrumForTesting(
            database: database,
            readPreferences: readPreferences,
            tor: tor,
          ),
        ),
        openMempool: (tor, http) async => Ok(
          createMempoolForTesting(database: database, tor: tor, torHttp: http),
        ),
        payjoinDatabasePath: '${appDirectory.path}/payjoin.sqlite',
        startPayjoinRecovery: false,
        startOrderSwapWatcher: false,
        startAutoswapWatcher: false,
        arkFundingDatabasePath: '${appDirectory.path}/ark-funding.sqlite',
        initializeArkFunding: true,
      );
      final settings = locator<Preferences>();
      _ok(await settings.setIsSuperuser(true), 'superuser');
      _ok(await settings.setIsDevMode(true), 'developer mode');
      _ok(await settings.setEnvironment(Environment.regtest), 'environment');
      final secrets = locator<Secrets>();

      final wallets = await locator<WalletMetadataDatasource>().fetchAll();
      final bitcoin = wallets.where(
        (w) => w.networkCode == 'bitcoinRegtest' && w.isDefault,
      );

      if (phase == 'setup') {
        if (bitcoin.isNotEmpty ||
            vaultFile.existsSync() ||
            keyFile.existsSync()) {
          throw StateError('setup already ran in this directory');
        }
        final parent = _ok(await secrets.generate(), 'generate parent');
        final sealed = _ok(await parent.backup.recoverbull(), 'seal parent');
        _writePrivate(vaultFile, sealed.vault.json);
        _writePrivate(keyFile, sealed.key.hex);
        // The parent is recoverable from the private files before any
        // address is published for funding.
        final recovered = _ok(
          await secrets.recoverbull.fingerprint(
            vault: EncryptedVault(json: vaultFile.readAsStringSync()),
            key: VaultKey(keyFile.readAsStringSync()),
          ),
          'verify recovery',
        );
        expect(recovered, parent.id);
        _ok(
          await locator<CreateDefaultWalletsUsecase>().execute(
            secret: parent,
            expectedNetwork: NetworkEnv.regtest,
          ),
          'create wallets',
        );
        final source = (await locator<WalletMetadataDatasource>().fetchAll())
            .singleWhere(
              (w) => w.networkCode == 'bitcoinRegtest' && w.isDefault,
            );
        final address = await locator<GetReceiveAddressUsecase>().execute(
          walletId: source.id,
          generateNew: true,
        );
        _report(
          'source wallet=${source.id} fingerprint=${source.masterFingerprint} '
          'network=${source.networkCode} address=${address.address}',
        );
        await locator.reset();
        return;
      }

      final source = bitcoin.single;
      final restored = _ok(
        await secrets.recoverbull.restore(
          vault: EncryptedVault(json: vaultFile.readAsStringSync()),
          key: VaultKey(keyFile.readAsStringSync()),
        ),
        'restore parent',
      );
      expect(restored.secret.id.hex, source.masterFingerprint);
      await ArkForegroundHost.setup(
        locator,
        arkUrl: Uri.parse(arkUrl!),
        primaryEsploraUrl: Uri.parse(esploraUrl!),
        initializeNew: true,
        preferences: _FilePreferences(
          File('${directory.path}/ark-preferences.json'),
        ),
      );
      final host = locator<ArkForegroundHost>();
      final runtime = _ok(await host.current(), 'open Ark');
      final account = runtime.account;
      final facade = runtime.feature.facade;
      final config = ArkAccountConfig(
        id: account,
        arkUrl: Uri.parse(arkUrl),
        primaryEsploraUrl: Uri.parse(esploraUrl),
      );
      _report(
        'source wallet=${source.id} fingerprint=${source.masterFingerprint} '
        'ark parent=${account.parent.hex} server=${account.serverIdentity}',
      );
      if (!_ok(await facade.isEnabled(account), 'enabled')) {
        _ok(
          await facade.enable(config, privacyDisclosureAccepted: true),
          'enable',
        );
      }

      final operationFile = File('${directory.path}/board-operation.json');
      if (phase == 'board') {
        if (operationFile.existsSync()) {
          throw StateError('a Board was already prepared; reconcile only');
        }
        // As the account screen does: a Board quote needs a fresh snapshot.
        _report(
          'synchronize=${await facade.synchronize(account, renew: false)}',
        );
        final fresh = _ok(await facade.read(account), 'read before Board');
        if (fresh.stale || fresh.recovery != ArkRecoveryStatus.complete) {
          throw StateError('Ark snapshot not fresh before Board');
        }
        final prepared = _ok(
          await facade.prepareBoard(config, Sats.fromInt(20000)),
          'prepare',
        );
        operationFile.writeAsStringSync(
          jsonEncode({'operationId': prepared.operationId}),
          flush: true,
        );
        _report(
          'prepared operation=${prepared.operationId} '
          'funding=${prepared.fundingAmount} minerFee=${prepared.minerFee} '
          'arkFee=${prepared.arkFee} net=${prepared.net} '
          'feeRate=${prepared.feeRate} txid=${prepared.unsignedTxid} '
          'expiry=${prepared.expiryHeight}',
        );
        // Source BTC left after this Board, apart from Bark's own reserve.
        final before = await locator<WalletRepository>().getWalletBalances(
          walletId: source.id,
        );
        final sourceAfter = before.confirmedSat - prepared.sourceDebit.value;
        _report(
          'source confirmed=${before.confirmedSat} '
          'debit=${prepared.sourceDebit} sourceAfterBoard=$sourceAfter',
        );
        if (sourceAfter < BigInt.from(10000)) {
          throw StateError('source reserve after Board below 10000 sat');
        }
        final review = _ok(
          await facade.reviewBoard(account, prepared.operationId),
          'review',
        );
        final operation = await facade.confirmBoard(account, review);
        _report('confirm result=$operation');
        _ok(operation, 'confirm');
      } else if (phase == 'confirm') {
        // Confirms an already prepared Board once, as the review screen does.
        final operationId = environment['BULL_ARK_LIVE_BOARD_OPERATION'];
        final confirmFile = File('${directory.path}/board-confirm.json');
        if (operationId == null) throw StateError('operation id required');
        if (confirmFile.existsSync()) {
          throw StateError('this Board was already confirmed; reconcile only');
        }
        _report(
          'synchronize=${await facade.synchronize(account, renew: false)}',
        );
        final review = _ok(
          await facade.reviewBoard(account, operationId),
          'review',
        );
        final prepared = review.details;
        _report(
          'review operation=${prepared.operationId} '
          'funding=${prepared.fundingAmount} minerFee=${prepared.minerFee} '
          'arkFee=${prepared.arkFee} net=${prepared.net} '
          'feeRate=${prepared.feeRate} txid=${prepared.unsignedTxid} '
          'expiry=${prepared.expiryHeight}',
        );
        final before = await locator<WalletRepository>().getWalletBalances(
          walletId: source.id,
        );
        final sourceAfter = before.confirmedSat - prepared.sourceDebit.value;
        _report(
          'source confirmed=${before.confirmedSat} '
          'debit=${prepared.sourceDebit} sourceAfterBoard=$sourceAfter',
        );
        if (sourceAfter < BigInt.from(10000)) {
          throw StateError('source reserve after Board below 10000 sat');
        }
        _writePrivate(confirmFile, jsonEncode({'operationId': operationId}));
        final operation = await facade.confirmBoard(account, review);
        _report(
          'confirm result=${switch (operation) {
            Ok(:final value) => 'Ok ${value.id} ${value.status}',
            Err(:final failure) => 'Err ${failure.runtimeType}',
          }}',
        );
        _ok(operation, 'confirm');
      } else if (phase == 'observe') {
        final synchronized = await facade.synchronize(account, renew: false);
        _report('synchronize=$synchronized');
      } else {
        throw StateError('unknown phase $phase');
      }

      final snapshot = _ok(await facade.read(account), 'read');
      final balances = await locator<WalletRepository>().getWalletBalances(
        walletId: source.id,
      );
      _report(
        'source BTC wallet (last sync) confirmed=${balances.confirmedSat} '
        'pending=${balances.trustedPendingSat + balances.untrustedPendingSat}',
      );
      _report(
        'ark spendable=${snapshot.spendable} pending=${snapshot.pending} '
        'barkNativeReserve=${snapshot.confirmedReserve} '
        'tip=${snapshot.tipHeight} '
        'boards=${snapshot.pendingBoards.length} '
        'vtxos=${snapshot.vtxos.map((v) => '${v.amount}/${v.state}').toList()}',
      );
      await locator.reset();
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
