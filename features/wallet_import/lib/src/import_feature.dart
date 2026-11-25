import 'package:bip39_mnemonic/bip39_mnemonic.dart' show Language;
import 'package:electrum/setup.dart' show ElectrumServersPort;
import 'package:go_router/go_router.dart' show GoRoute, RouteBase;
import 'package:material_ui/material_ui.dart' show BuildContext, ImageProvider;
import 'package:meta/meta.dart';
import 'package:preferences/preferences.dart' show Preferences;
import 'package:primitives/primitives.dart'
    show Err, NetworkEnv, Ok, Result, ScriptType;
import 'package:secrets/secrets.dart'
    show ParentCustodyAdmissionPort, Secrets, WalletInventory;
import 'package:wallet_import/src/domain/check_wallet_status_usecase.dart';
import 'package:wallet_import/src/domain/import_failure.dart';
import 'package:provisioning/provisioning.dart' show WalletProvisioning;
import 'package:wallet_import/src/domain/mnemonic/check_duplicate_mnemonic_usecase.dart';
import 'package:wallet_import/src/domain/mnemonic/import_wallet_usecase.dart';
import 'package:wallet_import/src/domain/scan_mnemonic_usecase.dart';
import 'package:wallet_import/src/domain/watch_only/import_watch_only_descriptor_usecase.dart';
import 'package:wallet_import/src/domain/watch_only/import_watch_only_xpub_usecase.dart';
import 'package:wallet_import/src/domain/watch_only/parse_watch_only_input_usecase.dart';
import 'package:wallet_import/src/domain/watch_only/read_watch_only_network_usecase.dart';
import 'package:wallet_import/src/import_navigation.dart';
import 'package:wallet_import/src/presentation/mnemonic/cubit.dart';
import 'package:wallet_import/src/presentation/watch_only/import_watch_only_cubit.dart';
import 'package:wallet_import/src/ui/coldcard_routes.dart';
import 'package:wallet_import/src/ui/import_wallet_page.dart';
import 'package:wallet_import/src/ui/mnemonic/mnemonic_routes.dart';
import 'package:wallet_import/src/ui/qr_device_routes.dart';
import 'package:wallet_import/src/ui/watch_only/watch_only_routes.dart';

class ImportFeature {
  final List<RouteBase> routes;
  final ScanMnemonicUsecase _scan;

  ImportFeature._(this.routes, this._scan);

  static ImportFeature mount({
    required Preferences preferences,
    required ElectrumServersPort servers,
    required Secrets secrets,
    required WalletInventory inventory,
    required ParentCustodyAdmissionPort admission,
    required WalletProvisioning accounts,
    required NetworkEnv? Function(BuildContext) networkOf,
    required void Function(BuildContext) onImported,
    required void Function(BuildContext) onExit,
    required ImageProvider<Object> qrIllustration,
  }) {
    final scan = ScanMnemonicUsecase(
      checkWalletStatus: CheckWalletStatusUsecase(
        preferences,
        servers,
        secrets,
      ),
    );
    final duplicate = CheckDuplicateMnemonicUsecase(
      secrets: secrets,
      inventory: inventory,
      settings: preferences,
    );
    final mnemonic = ImportWalletUsecase(
      checkDuplicateMnemonicUsecase: duplicate,
      secrets: secrets,
      settingsRepository: preferences,
      provision: accounts.importMnemonic,
      admission: admission,
    );
    final descriptor = ImportWatchOnlyDescriptorUsecase(accounts);
    final xpub = ImportWatchOnlyXpubUsecase(accounts);
    final parse = ParseWatchOnlyInputUsecase();
    final readNetwork = ReadWatchOnlyNetworkUsecase(preferences);

    return ImportFeature._(
      List.unmodifiable([
        GoRoute(
          name: ImportNavigation.homeName,
          path: ImportNavigation.homePath,
          builder: (_, _) => ImportWalletPage(networkOf: networkOf),
        ),
        ImportMnemonicRouter.route(
          createCubit: () => ImportMnemonicCubit(
            importWalletUsecase: mnemonic,
            scanMnemonic:
                ({
                  required words,
                  required language,
                  required passphrase,
                  required scriptTypes,
                }) => _scanUpdates(
                  scan,
                  words: words,
                  language: language,
                  passphrase: passphrase,
                  scriptTypes: scriptTypes,
                ),
            checkDuplicateMnemonicUsecase: duplicate,
          ),
          onImported: onImported,
          onExit: onExit,
        ),
        ImportWatchOnlyRouter.route(
          createCubit: (wallet) => ImportWatchOnlyCubit(
            watchOnlyWallet: wallet,
            importWatchOnlyDescriptorUsecase: descriptor,
            importWatchOnlyXpubUsecase: xpub,
            parseWatchOnlyInputUsecase: parse,
            readNetworkUsecase: readNetwork,
          ),
          onImported: onImported,
        ),
        ...ImportColdcardRouter.routes(qrIllustration),
        ...qrDeviceRoutes(qrIllustration),
      ]),
      scan,
    );
  }

  Stream<MnemonicScanUpdate> scanMnemonic({
    required List<String> words,
    required Language language,
    required String passphrase,
    required Set<ScriptType> scriptTypes,
  }) => _scanUpdates(
    _scan,
    words: words,
    language: language,
    passphrase: passphrase,
    scriptTypes: scriptTypes,
  );

  static Stream<MnemonicScanUpdate> _scanUpdates(
    ScanMnemonicUsecase scan, {
    required List<String> words,
    required Language language,
    required String passphrase,
    required Set<ScriptType> scriptTypes,
  }) {
    final scans = scan.execute(
      words: words,
      language: language,
      passphrase: passphrase,
      scriptTypes: scriptTypes,
    );
    return Stream.fromFutures([
      for (final MapEntry(key: script, value: scan) in scans.entries)
        scan.then((result) => (scriptType: script, result: result)),
    ]);
  }

  @useResult
  Future<Result<bool, ImportMnemonicScanFailure>> hasBitcoinHistory({
    required List<String> words,
    required Language language,
    required String passphrase,
  }) async {
    final scan = _scan.execute(
      words: words,
      language: language,
      passphrase: passphrase,
      scriptTypes: const {ScriptType.bip84},
    )[ScriptType.bip84];
    if (scan == null) {
      return const Err(ImportMnemonicScanUnexpectedFailure('Missing scan'));
    }
    return switch (await scan) {
      Ok(:final value) => Ok(value.transactions > 0),
      Err(:final failure) => Err(failure),
    };
  }
}
