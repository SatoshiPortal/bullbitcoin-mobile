import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:satoshifier/satoshifier.dart' as sat;
import 'package:signers/signers.dart';
import 'package:wallet_import/src/domain/import_failure.dart';

/// A Bitcoin descriptor or extended public key, with any acquisition context.
sealed class WatchOnlyInput {
  final BitcoinNetwork keyNetwork;
  final BitcoinNetwork? selectedNetwork;
  final SignerDevice? signerDevice;
  final String? keyOrigin;

  const WatchOnlyInput._(
    this.keyNetwork,
    this.selectedNetwork,
    this.signerDevice,
    this.keyOrigin,
  );

  BitcoinNetwork get network => selectedNetwork ?? keyNetwork;
  String get pubkey;
  ScriptType get scriptType;

  static final _privateKey = RegExp(
    r'(?<![A-Za-z0-9])(xprv|yprv|zprv|tprv|uprv|vprv)[1-9A-HJ-NP-Za-km-z]+',
  );
  static final _keyOrigin = RegExp(r'^\[[^\]]+\]');
  static final _regtestOrigin = RegExp(
    r"^\[[0-9a-fA-F]{8}/84[h']/1[h']/[0-9]+[h']\]$",
  );

  @useResult
  static Future<Result<WatchOnlyInput, ImportFailure>> parse(
    String text, {
    NetworkEnv? environment,
    SignerDevice? signerDevice,
  }) async {
    if (_privateKey.hasMatch(text)) {
      return const Err(InvalidWatchOnlyInputFailure());
    }
    final trimmed = text.trim();
    final origin = _keyOrigin.firstMatch(trimmed)?.group(0);
    if ((origin == null && trimmed.startsWith('[')) ||
        (environment == NetworkEnv.regtest &&
            !_allowsRegtestProvenance(signerDevice, origin))) {
      return const Err(InvalidWatchOnlyInputFailure());
    }
    final normalized = trimmed.substring(origin?.length ?? 0);
    final sat.Satoshifier parsed;
    try {
      parsed = await sat.Satoshifier.parse(normalized);
    } catch (error) {
      if (error is Error) rethrow;
      log.warning('Failed to parse watch-only input');
      return const Err(InvalidWatchOnlyInputFailure());
    }

    final input = switch (parsed) {
      sat.WatchOnlyDescriptor() => fromDescriptor(
        parsed,
        signerDevice: signerDevice,
        keyOrigin: origin,
      ),
      sat.WatchOnlyXpub() => fromXpub(
        parsed,
        signerDevice: signerDevice,
        keyOrigin: origin,
      ),
      _ => const Err<WatchOnlyInput, ImportFailure>(
        InvalidWatchOnlyInputFailure(),
      ),
    };
    return environment == null
        ? input
        : switch (input) {
            Ok(:final value) => value.captureEnvironment(environment),
            Err() => input,
          };
  }

  @useResult
  static Result<WatchOnlyInput, ImportFailure> fromSignerAccount(
    SignerAccount account,
  ) {
    final sat.Descriptor descriptor;
    try {
      descriptor = sat.Descriptor.fromStrings(
        fingerprint: account.masterFingerprint,
        path: account.derivationPath,
        xpub: account.xpub,
      );
    } catch (error) {
      if (error is Error) rethrow;
      return const Err(InvalidWatchOnlyInputFailure());
    }
    final input = fromDescriptor(
      sat.WatchOnlyDescriptor(descriptor: descriptor),
      signerDevice: account.device,
    );
    return switch (input) {
      Ok(:final value) => value.captureEnvironment(account.network),
      Err() => input,
    };
  }

  @useResult
  static Result<WatchOnlyDescriptorInput, ImportFailure> fromDescriptor(
    sat.WatchOnlyDescriptor value, {
    SignerDevice? signerDevice,
    String? keyOrigin,
  }) {
    final encoded = _bitcoinNetwork(value.descriptor.network);
    if (encoded == null ||
        _privateKey.hasMatch(value.descriptor.external) ||
        _privateKey.hasMatch(value.descriptor.internal)) {
      return const Err(InvalidWatchOnlyInputFailure());
    }
    return Ok(
      WatchOnlyDescriptorInput._(value, encoded, null, signerDevice, keyOrigin),
    );
  }

  @useResult
  static Result<WatchOnlyXpubInput, ImportFailure> fromXpub(
    sat.WatchOnlyXpub value, {
    String? keyOrigin,
    SignerDevice? signerDevice,
  }) {
    final encoded = _bitcoinNetwork(value.extendedPubkey.network);
    if (encoded == null ||
        _privateKey.hasMatch(value.extendedPubkey.pubBase58)) {
      return const Err(InvalidWatchOnlyInputFailure());
    }
    return Ok(
      WatchOnlyXpubInput._(value, encoded, null, signerDevice, keyOrigin),
    );
  }

  static BitcoinNetwork? _bitcoinNetwork(sat.Network network) =>
      switch (network) {
        sat.Network.bitcoinMainnet => BitcoinNetwork.mainnet,
        sat.Network.bitcoinTestnet => BitcoinNetwork.testnet,
        sat.Network.bitcoinRegtest => BitcoinNetwork.regtest,
        _ => null,
      };

  static bool _allowsRegtestProvenance(SignerDevice? device, String? origin) =>
      device == null && (origin == null || _regtestOrigin.hasMatch(origin));

  @useResult
  Result<WatchOnlyInput, ImportFailure> captureEnvironment(
    NetworkEnv environment,
  ) {
    final selected = switch (environment) {
      NetworkEnv.mainnet => BitcoinNetwork.mainnet,
      NetworkEnv.testnet => BitcoinNetwork.testnet,
      NetworkEnv.regtest => BitcoinNetwork.regtest,
      NetworkEnv.signet => BitcoinNetwork.signet,
    };

    if (selected == BitcoinNetwork.signet) {
      return const Err(InvalidWatchOnlyInputFailure());
    }
    if ((selectedNetwork != null && selectedNetwork != selected) ||
        selected.isMainnet != keyNetwork.isMainnet ||
        (selected != BitcoinNetwork.regtest && selected != keyNetwork)) {
      return const Err(WatchOnlyNetworkMismatchFailure());
    }

    final input = this;
    if (selected == BitcoinNetwork.regtest &&
        !_allowsRegtestProvenance(signerDevice, keyOrigin)) {
      return const Err(InvalidWatchOnlyInputFailure());
    }
    final value = switch (input) {
      WatchOnlyDescriptorInput() => WatchOnlyDescriptorInput._(
        input.value,
        keyNetwork,
        selected,
        signerDevice,
        keyOrigin,
      ),
      WatchOnlyXpubInput() => WatchOnlyXpubInput._(
        selected == BitcoinNetwork.regtest && input.pubkey.startsWith('tpub')
            ? input._resolvePlainTpub()
            : input.value,
        keyNetwork,
        selected,
        signerDevice,
        input.keyOrigin,
      ),
    };
    if (selected == BitcoinNetwork.regtest &&
        value.scriptType != ScriptType.bip84) {
      return const Err(InvalidWatchOnlyInputFailure());
    }
    return Ok(value);
  }
}

final class WatchOnlyDescriptorInput extends WatchOnlyInput {
  final sat.WatchOnlyDescriptor value;

  const WatchOnlyDescriptorInput._(
    this.value,
    super.keyNetwork,
    super.selectedNetwork,
    super.signerDevice,
    super.keyOrigin,
  ) : super._();

  @override
  String get pubkey => value.descriptor.pubkey;

  @override
  ScriptType get scriptType =>
      ScriptType.fromName(value.descriptor.derivation.name);
}

final class WatchOnlyXpubInput extends WatchOnlyInput {
  final sat.WatchOnlyXpub value;

  const WatchOnlyXpubInput._(
    this.value,
    super.keyNetwork,
    super.selectedNetwork,
    super.signerDevice,
    super.keyOrigin,
  ) : super._();

  @override
  String get pubkey => value.extendedPubkey.pubBase58;

  @override
  ScriptType get scriptType =>
      ScriptType.fromName(value.extendedPubkey.derivation.name);

  sat.WatchOnlyXpub _resolvePlainTpub() {
    final key = value.extendedPubkey;
    return sat.WatchOnlyXpub(
      extendedPubkey: sat.ExtendedPubkey(
        pubkey: key.pubkey,
        derivation: sat.Derivation.bip84,
        network: key.network,
      ),
    );
  }
}
