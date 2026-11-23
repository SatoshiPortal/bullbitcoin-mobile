import 'package:primitives/primitives.dart' show UnsupportedNetworkException;
import 'package:primitives/primitives.dart' show ScriptType;
import 'package:bb_mobile/features/wallet/domain/network_x.dart';

import 'dart:async';

import 'package:electrum/electrum.dart';
import 'package:electrum/setup.dart';
import 'package:primitives/primitives.dart' as primitives;
import 'package:preferences/preferences.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:secrets/secrets.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:sync/sync.dart' as sync;
import 'package:primitives/legacy_exceptions.dart';
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
          required Network network,
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
    required Network network,
    required ElectrumConnection electrumServer,
  })
  _dryScan;
  final Secrets _secrets;

  /// Derives the descriptors of all [scriptTypes] in one call, then starts one scan per script type.
  ///
  /// The returned future fails with [CheckWalletStatusException] when the descriptors cannot be derived, [CheckWalletStatusInvalidMnemonicException] for words that are not a mnemonic. Each scan's own future then carries its result or failure ([ElectrumFallbackException], [TimeoutException] or [CheckWalletStatusException]), so a slow or failing scan does not hold back the others.
  Future<Map<ScriptType, Future<({BigInt satoshis, int transactions})>>> call({
    required List<String> words,
    required bip39.Language language,
    required String passphrase,
    required Set<ScriptType> scriptTypes,
  }) async {
    final Network network;
    final Map<primitives.ScriptType, Descriptors> descriptors;
    try {
      final settings = (await _settingsRepository.fetch()).fold(
        (value) => value,
        (failure) => throw Exception('Preferences read failed'),
      );
      network = Network.fromEnvironment(
        environment: settings.environment.networkEnv,
        isLiquid: false,
      );

      descriptors = switch (await _secrets.preview.bitcoinDescriptors(
        words: words,
        language: language,
        passphrase: passphrase,
        network: network.bitcoin,
        scriptTypes: {
          for (final scriptType in scriptTypes)
            switch (scriptType) {
              ScriptType.bip84 => primitives.ScriptType.bip84,
              ScriptType.bip49 => primitives.ScriptType.bip49,
              ScriptType.bip44 => primitives.ScriptType.bip44,
            },
        },
      )) {
        primitives.Ok(:final value) => value,
        // Only the failure's type travels: its message may describe the words.
        primitives.Err(failure: InvalidMnemonicFailure()) =>
          throw CheckWalletStatusInvalidMnemonicException(),
        primitives.Err(:final failure) => throw CheckWalletStatusException(
          'Could not derive the descriptors to scan: ${failure.runtimeType}',
        ),
      };
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
        switch (scriptType) {
          primitives.ScriptType.bip84 => ScriptType.bip84,
          primitives.ScriptType.bip49 => ScriptType.bip49,
          primitives.ScriptType.bip44 => ScriptType.bip44,
        }: _handled(
          _scan(descriptors: pair, network: network, scriptType: scriptType),
        ),
    };
  }

  Future<({BigInt satoshis, int transactions})> _scan({
    required Descriptors descriptors,
    required Network network,
    required primitives.ScriptType scriptType,
  }) async {
    final timer = Stopwatch()..start();
    final context =
        'network=${network.bitcoin.env.name} script=${scriptType.name}';
    log.fine('Import scan started $context');
    try {
      if (network == Network.bitcoinRegtest &&
          scriptType != primitives.ScriptType.bip84) {
        throw const UnsupportedNetworkException();
      }
      final result = await _serversPort
          .runWithFallback<({BigInt satoshis, int transactions})>(
            network: ElectrumServerNetwork.fromNetworkEnv(
              network.bitcoin.env,
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
        UnsupportedNetworkException() => 'unsupported',
        _ => 'unexpected',
      };
      log.warning(
        'Import scan failed $context reason=$reason duration_ms=${timer.elapsedMilliseconds}',
      );
      if (e is ElectrumFallbackException ||
          e is TimeoutException ||
          e is UnsupportedNetworkException) {
        rethrow;
      }
      throw CheckWalletStatusException('Scan failed: ${e.runtimeType}');
    }
  }

  static Future<({BigInt satoshis, int transactions})> _prescan({
    required String externalDescriptor,
    required String internalDescriptor,
    required Network network,
    required ElectrumConnection electrumServer,
  }) async {
    final scanned = await sync.prescanBitcoinWallet(
      externalDescriptor: externalDescriptor,
      internalDescriptor: internalDescriptor,
      network: network.bitcoin,
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
      primitives.Ok(:final value) => (
        satoshis: value.confirmedSat,
        transactions: value.transactions,
      ),
      primitives.Err(:final failure) => throw sync.WalletSnapshotException(
        failure,
      ),
    };
  }

  /// Marks [scan]'s failure as handled for the moment before the caller listens; the caller still receives it.
  static Future<T> _handled<T>(Future<T> scan) {
    unawaited(scan.then<void>((_) {}, onError: (Object _) {}));
    return scan;
  }
}

class CheckWalletStatusException extends BullException {
  CheckWalletStatusException(super.message);
}

/// The words are not a BIP39 mnemonic in the language given, so nothing could be scanned.
class CheckWalletStatusInvalidMnemonicException
    extends CheckWalletStatusException {
  CheckWalletStatusInvalidMnemonicException()
    : super('Could not derive the descriptors to scan: invalid mnemonic');
}
