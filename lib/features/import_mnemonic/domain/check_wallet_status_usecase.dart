import 'dart:async';

import 'package:bb_mobile/core/electrum/domain/errors/electrum_fallback_exception.dart';
import 'package:primitives/primitives.dart' as primitives;
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:secrets/secrets.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/data/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;

/// Scans the chain for a mnemonic that is not imported yet, for several script types.
///
/// `secrets` derives the public descriptors of every script type from one seed; the wallet datasource scans with those descriptors only and never receives the words, their entropy or the passphrase.
class CheckWalletStatusUsecase {
  CheckWalletStatusUsecase(
    this._settingsRepository,
    this._serversPort,
    this._bitcoinWalletRepository,
    this._secrets,
  );
  final SettingsRepository _settingsRepository;
  final ElectrumServersPort _serversPort;
  final BitcoinWalletRepository _bitcoinWalletRepository;
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
    final bool isTestnet;
    final Map<primitives.ScriptType, Descriptors> descriptors;
    try {
      final settings = await _settingsRepository.fetch();
      isTestnet = settings.environment.isTestnet;

      descriptors = switch (await _secrets.preview.bitcoinDescriptors(
        words: words,
        language: language,
        passphrase: passphrase,
        network: isTestnet
            ? primitives.BitcoinNetwork.testnet
            : primitives.BitcoinNetwork.mainnet,
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
    } on CheckWalletStatusException {
      rethrow;
    } catch (e, st) {
      // Only the type is reported: a foreign message may quote the input.
      final error = CheckWalletStatusException(
        'Could not prepare the scan: ${e.runtimeType}',
      );
      log.severe(message: error.message, error: error, trace: st);
      throw error;
    }

    return {
      for (final MapEntry(key: scriptType, value: pair) in descriptors.entries)
        switch (scriptType) {
          primitives.ScriptType.bip84 => ScriptType.bip84,
          primitives.ScriptType.bip49 => ScriptType.bip49,
          primitives.ScriptType.bip44 => ScriptType.bip44,
        }: _handled(
          _scan(descriptors: pair, isTestnet: isTestnet),
        ),
    };
  }

  Future<({BigInt satoshis, int transactions})> _scan({
    required Descriptors descriptors,
    required bool isTestnet,
  }) async {
    try {
      return await _serversPort
          .runWithFallback<({BigInt satoshis, int transactions})>(
            network: isTestnet
                ? ElectrumServerNetwork.bitcoinTestnet
                : ElectrumServerNetwork.bitcoinMainnet,
            operation: (connection) => _bitcoinWalletRepository.dryScan(
              externalDescriptor: descriptors.external,
              internalDescriptor: descriptors.internal,
              isTestnet: isTestnet,
              electrumServer: connection,
            ),
          );
    } on ElectrumFallbackException {
      // Preserve the typed exception so callers retain the per-server
      // attempts (failure tier, urls, root-cause errors) for diagnostics.
      rethrow;
    } on TimeoutException {
      rethrow;
    } catch (e, st) {
      // Only the type is reported: a foreign message may quote a descriptor.
      final error = CheckWalletStatusException('Scan failed: ${e.runtimeType}');
      log.severe(message: error.message, error: error, trace: st);
      throw error;
    }
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
