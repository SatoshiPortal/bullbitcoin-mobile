import 'dart:async';

import 'package:electrum/electrum.dart';
import 'package:electrum/setup.dart';
import 'package:primitives/primitives.dart'
    show BitcoinNetwork, Err, NetworkEnv, Ok, ScriptType;
import 'package:preferences/preferences.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:secrets/secrets.dart';
import 'package:sync/sync.dart' as sync;
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;

/// Scans the chain for a mnemonic that is not imported yet, for several script types.
///
/// `secrets` derives the public descriptors of every script type from one seed; the wallet datasource scans with those descriptors only and never receives the words, their entropy or the passphrase.
class CheckWalletStatusUsecase {
  CheckWalletStatusUsecase(
    this._settingsRepository,
    this._serversPort,
    this._secrets, {
    Future<({BigInt satoshis, int transactions})> Function({
          required String externalDescriptor,
          required String internalDescriptor,
          required BitcoinNetwork network,
          required ElectrumConnection electrumServer,
        })
        prescan =
        _prescan,
  }) : _dryScan = prescan;
  final Preferences _settingsRepository;
  final ElectrumServersPort _serversPort;
  final Future<({BigInt satoshis, int transactions})> Function({
    required String externalDescriptor,
    required String internalDescriptor,
    required BitcoinNetwork network,
    required ElectrumConnection electrumServer,
  })
  _dryScan;
  final Secrets _secrets;

  /// Derives the descriptors of all [scriptTypes] in one call, then starts one scan per script type.
  ///
  /// The returned future fails with [CheckWalletStatusException] when the descriptors cannot be derived, [CheckWalletStatusInvalidMnemonicException] for words that are not a mnemonic. Each scan's own future then carries its result or failure ([ElectrumFallbackException], [TimeoutException] or [CheckWalletStatusException]), so a slow or failing scan does not hold back the others.
  Future<Map<ScriptType, Future<({BigInt satoshis, int transactions})>>>
  execute({
    required List<String> words,
    required bip39.Language language,
    required String passphrase,
    required Set<ScriptType> scriptTypes,
  }) async {
    final BitcoinNetwork network;
    final Map<ScriptType, Descriptors> descriptors;
    try {
      final settings = (await _settingsRepository.fetch()).fold(
        (value) => value,
        (failure) => throw Exception('Preferences read failed'),
      );
      network = switch (settings.environment.networkEnv) {
        NetworkEnv.mainnet => BitcoinNetwork.mainnet,
        NetworkEnv.testnet => BitcoinNetwork.testnet,
        NetworkEnv.regtest => BitcoinNetwork.regtest,
        NetworkEnv.signet => throw const UnsupportedImportScanException(),
      };

      descriptors = switch (await _secrets.preview.bitcoinDescriptors(
        words: words,
        language: language,
        passphrase: passphrase,
        network: network,
        scriptTypes: scriptTypes,
      )) {
        Ok(:final value) => value,
        // Only the failure's type travels: its message may describe the words.
        Err(failure: InvalidMnemonicFailure()) =>
          throw CheckWalletStatusInvalidMnemonicException(),
        Err(:final failure) => throw CheckWalletStatusException(
          'Could not derive the descriptors to scan: ${failure.runtimeType}',
        ),
      };
    } on UnsupportedImportScanException {
      rethrow;
    } on CheckWalletStatusException catch (e) {
      log.warning(
        'Import scan blocked stage=derive reason=${e is CheckWalletStatusInvalidMnemonicException ? 'invalid_mnemonic' : 'derivation'}',
      );
      rethrow;
    } catch (e) {
      // Only the type is reported: a foreign message may quote the input.
      final error = CheckWalletStatusException(
        'Could not prepare the scan: ${e.runtimeType}',
      );
      log.warning('Import scan blocked stage=derive reason=preparation');
      throw error;
    }

    return {
      for (final MapEntry(key: scriptType, value: pair) in descriptors.entries)
        scriptType: _handled(
          _scan(descriptors: pair, network: network, scriptType: scriptType),
        ),
    };
  }

  Future<({BigInt satoshis, int transactions})> _scan({
    required Descriptors descriptors,
    required BitcoinNetwork network,
    required ScriptType scriptType,
  }) async {
    final timer = Stopwatch()..start();
    final context = 'network=${network.env.name} script=${scriptType.name}';
    log.fine('Import scan started $context');
    try {
      if (network == BitcoinNetwork.regtest && scriptType != ScriptType.bip84) {
        throw const UnsupportedImportScanException();
      }
      final result = await _serversPort
          .runWithFallback<({BigInt satoshis, int transactions})>(
            network: ElectrumServerNetwork.fromNetworkEnv(
              network.env,
              isLiquid: false,
            ),
            operation: (connection) => _dryScan(
              externalDescriptor: descriptors.external,
              internalDescriptor: descriptors.internal,
              network: network,
              electrumServer: connection,
            ),
          );
      log.fine(
        'Import scan finished $context outcome=${result.transactions == 0 ? 'empty' : 'history'} tx_count=${result.transactions} duration_ms=${timer.elapsedMilliseconds}',
      );
      return result;
    } catch (e) {
      final reason = switch (e) {
        TimeoutException() => 'timeout',
        ElectrumFallbackException() => 'server_unavailable',
        UnsupportedImportScanException() => 'unsupported',
        _ => 'unexpected',
      };
      log.warning(
        'Import scan failed $context reason=$reason duration_ms=${timer.elapsedMilliseconds}',
      );
      if (e is ElectrumFallbackException ||
          e is TimeoutException ||
          e is UnsupportedImportScanException) {
        rethrow;
      }
      throw CheckWalletStatusException('Scan failed: ${e.runtimeType}');
    }
  }

  static Future<({BigInt satoshis, int transactions})> _prescan({
    required String externalDescriptor,
    required String internalDescriptor,
    required BitcoinNetwork network,
    required ElectrumConnection electrumServer,
  }) async {
    final scanned = await sync.prescanBitcoinWallet(
      externalDescriptor: externalDescriptor,
      internalDescriptor: internalDescriptor,
      network: network,
      connection: sync.WalletConnection(
        url: electrumServer.url,
        socks5: electrumServer.socks5,
        timeout: Duration(seconds: electrumServer.effectiveTimeout),
        retry: electrumServer.retry,
        stopGap: electrumServer.stopGap,
        validateDomain: electrumServer.validateDomain,
      ),
    );
    return switch (scanned) {
      Ok(:final value) => (
        satoshis: value.confirmedSat,
        transactions: value.transactions,
      ),
      Err(:final failure) => throw sync.WalletSnapshotException(failure),
    };
  }

  /// Marks [scan]'s failure as handled for the moment before the caller listens; the caller still receives it.
  static Future<T> _handled<T>(Future<T> scan) {
    unawaited(scan.then<void>((_) {}, onError: (Object _) {}));
    return scan;
  }
}

class CheckWalletStatusException implements Exception {
  final String message;

  const CheckWalletStatusException(this.message);
}

final class UnsupportedImportScanException implements Exception {
  const UnsupportedImportScanException();
}

/// The words are not a BIP39 mnemonic in the language given, so nothing could be scanned.
class CheckWalletStatusInvalidMnemonicException
    extends CheckWalletStatusException {
  CheckWalletStatusInvalidMnemonicException()
    : super('Could not derive the descriptors to scan: invalid mnemonic');
}
