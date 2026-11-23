import 'package:bip39_mnemonic/bip39_mnemonic.dart' show Language;
import 'package:electrum/setup.dart' show ElectrumServersPort;
import 'package:go_router/go_router.dart' show RouteBase;
import 'package:material_ui/material_ui.dart' show ImageProvider;
import 'package:meta/meta.dart';
import 'package:preferences/preferences.dart' show Preferences;
import 'package:primitives/primitives.dart' show Err, Ok, Result, ScriptType;
import 'package:secrets/secrets.dart' show Secrets;
import 'package:wallet_import/src/domain/check_wallet_status_usecase.dart';
import 'package:wallet_import/src/domain/import_failure.dart';
import 'package:wallet_import/src/domain/scan_mnemonic_usecase.dart';
import 'package:wallet_import/src/ui/qr_device_routes.dart';

class ImportFeature {
  final List<RouteBase> routes;
  final ScanMnemonicUsecase _scan;

  ImportFeature._(this.routes, this._scan);

  static ImportFeature mount({
    required Preferences preferences,
    required ElectrumServersPort servers,
    required Secrets secrets,
    required ImageProvider<Object> qrIllustration,
  }) {
    final scan = ScanMnemonicUsecase(
      checkWalletStatus: CheckWalletStatusUsecase(
        preferences,
        servers,
        secrets,
      ),
    );
    return ImportFeature._(
      List.unmodifiable(qrDeviceRoutes(qrIllustration)),
      scan,
    );
  }

  Stream<MnemonicScanUpdate> scanMnemonic({
    required List<String> words,
    required Language language,
    required String passphrase,
    required Set<ScriptType> scriptTypes,
  }) {
    final scans = _scan.execute(
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
