import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:satoshifier/bip32_derivation.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/storage.dart';
import 'package:sync/sync.dart';
import 'package:sync/write.dart' show WalletNativeLifecycle;

import '../provisioning_failure.dart';

/// Public key material of a watch-only account read from a descriptor.
final class WatchOnlyAccount {
  final BitcoinNetwork network;
  final ScriptType scriptType;

  /// The key origin fingerprint, kept verbatim: some exporters write it in
  /// uppercase, and an account without an origin has none.
  final String masterFingerprint;
  final String pubkey;
  final ({String external, String internal}) descriptors;
  final SignerEntity signer;

  /// The device name the user chose at import, if any.
  final String? signerDevice;
  final String label;

  const WatchOnlyAccount({
    required this.network,
    required this.scriptType,
    required this.masterFingerprint,
    required this.pubkey,
    required this.descriptors,
    required this.signer,
    required this.signerDevice,
    required this.label,
  });
}

/// Creates accounts from a stored secret or public key material, registers
/// them in the inventory with the properties of their other owners prepared,
/// and creates their native stores.
abstract interface class WalletProvisioning {
  factory WalletProvisioning.open({
    required SecretsInventory inventory,
    required WalletNativeLifecycle native,
    required Future<Result<void, SyncFailure>> Function() resume,
    required List<WalletPropertyStore> properties,
  }) = _WalletProvisioning;

  /// Finishes a creation interrupted between the catalog and native stores.
  @useResult
  Future<Result<void, WalletProvisioningFailure>> resume();

  /// Creates the default account of [network] for [secret] and returns its
  /// identifier.
  @useResult
  Future<Result<String, WalletProvisioningFailure>> createDefault(
    Secret secret,
    Network network, {
    DateTime? birthday,
  });

  /// Imports a Bitcoin account of a stored seed under parent custody
  /// admission. The catalog reference is durable before either tombstone is
  /// cleared.
  @useResult
  Future<Result<void, ParentCustodyFailure>> importMnemonic({
    required Fingerprint parent,
    required Secrets secrets,
    required ParentCustodyAdmissionPort admission,
    required BitcoinNetwork network,
    required ScriptType scriptType,
    String? label,
  });

  @useResult
  Future<Result<void, WalletProvisioningFailure>> importDescriptor(
    WatchOnlyAccount account,
  );

  @useResult
  Future<Result<void, WalletProvisioningFailure>> importXpub({
    required String xpub,
    required BitcoinNetwork network,
    required ScriptType scriptType,
    required String label,
  });
}

/// A creation failure inside parent custody admission. The catalog row may
/// already be committed, so the importer reports it without compensation.
final class WalletProvisioningException implements Exception {
  final WalletProvisioningFailure failure;
  const WalletProvisioningException(this.failure);
}

typedef _Account = ({
  String id,
  Network network,
  String masterFingerprint,
  SignerEntity signer,
  String? signerDevice,
  String xpub,
  String external,
  String internal,
  String? label,
  DateTime? birthday,
  bool isDefault,
});

final class _WalletProvisioning implements WalletProvisioning {
  static const _regtestSuffix = ':regtest';

  final SecretsInventory _inventory;
  final WalletNativeLifecycle _native;
  final Future<Result<void, SyncFailure>> Function() _resume;
  final List<WalletPropertyStore> _properties;

  _WalletProvisioning({
    required this._inventory,
    required this._native,
    required this._resume,
    required List<WalletPropertyStore> properties,
  }) : _properties = List.unmodifiable(properties);

  @override
  Future<Result<void, WalletProvisioningFailure>> resume() async =>
      (await _resume()).mapErr((_) => const WalletProvisioningStorageFailure());

  @override
  Future<Result<String, WalletProvisioningFailure>> createDefault(
    Secret secret,
    Network network, {
    DateTime? birthday,
  }) async {
    final defaults = await _hasDefault(network);
    switch (defaults) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: true):
        return const Err(WalletProvisioningConflictFailure());
      case Ok():
    }
    final label =
        network.env == NetworkEnv.mainnet || network.env == NetworkEnv.testnet
        ? switch (network) {
            BitcoinNetwork() => 'Secure Bitcoin',
            LiquidNetwork() => 'Instant Payments',
          }
        : null;
    final derived = await _fromSecret(
      secret,
      network,
      ScriptType.bip84,
      label: label,
      isDefault: true,
      birthday: birthday,
    );
    switch (derived) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final account):
        return (await _provision(account)).map((_) => account.id);
    }
  }

  @override
  Future<Result<void, ParentCustodyFailure>> importMnemonic({
    required Fingerprint parent,
    required Secrets secrets,
    required ParentCustodyAdmissionPort admission,
    required BitcoinNetwork network,
    required ScriptType scriptType,
    String? label,
  }) => admission.runExclusive<void>(parent, (lease) async {
    final Secret secret;
    switch (await secrets.fetch(parent)) {
      case Ok(:final value):
        secret = value;
      case Err():
        return const Err(ParentCustodySeedUnavailableFailure());
    }
    final derived = await _fromSecret(
      secret,
      network,
      scriptType,
      label: label,
      isDefault: false,
    );
    final provisioned = switch (derived) {
      Err(:final failure) => Err<void, WalletProvisioningFailure>(failure),
      Ok(value: final account) => await _provision(account),
    };
    if (provisioned case Err(:final failure)) {
      throw WalletProvisioningException(failure);
    }
    return lease.reconcilePresent();
  });

  @override
  Future<Result<void, WalletProvisioningFailure>> importDescriptor(
    WatchOnlyAccount account,
  ) => _importWatchOnly(account.network, account.scriptType, (
    id: _id(account.masterFingerprint, account.network, account.scriptType),
    network: account.network,
    masterFingerprint: account.masterFingerprint,
    signer: account.signer,
    signerDevice: account.signerDevice,
    xpub: account.pubkey,
    external: account.descriptors.external,
    internal: account.descriptors.internal,
    label: account.label,
    birthday: null,
    isDefault: false,
  ));

  @override
  Future<Result<void, WalletProvisioningFailure>> importXpub({
    required String xpub,
    required BitcoinNetwork network,
    required ScriptType scriptType,
    required String label,
  }) {
    final _Account account;
    try {
      final key = Bip32Derivation.getBip32Xpub(xpub);
      // Descriptor keys use BIP32 versions for the target network, even when
      // the imported account uses SLIP132 (ypub/zpub/upub/vpub) versions.
      final base58 = key.convert(
        network == BitcoinNetwork.mainnet ? XpubType.xpub : XpubType.tpub,
      );
      final fingerprint = key.fingerprintHex;
      String derive(Keychain keychain) => switch (bitcoinPublicDescriptor(
        xpub: base58,
        fingerprint: fingerprint,
        scriptType: scriptType,
        keychain: keychain,
        network: network,
      )) {
        Ok(:final value) => value,
        Err() => throw const FormatException('Invalid account key'),
      };
      account = (
        id: _id(fingerprint, network, scriptType),
        network: network,
        masterFingerprint: '',
        signer: SignerEntity.none,
        signerDevice: null,
        xpub: key.convert(scriptType.getXpubType(network)),
        external: derive(Keychain.external),
        internal: derive(Keychain.internal),
        label: label,
        birthday: null,
        isDefault: false,
      );
    } on FormatException {
      return Future.value(const Err(WalletProvisioningInvalidFailure()));
    } on ArgumentError {
      return Future.value(const Err(WalletProvisioningInvalidFailure()));
    }
    return _importWatchOnly(network, scriptType, account);
  }

  Future<Result<void, WalletProvisioningFailure>> _importWatchOnly(
    BitcoinNetwork network,
    ScriptType scriptType,
    _Account account,
  ) async {
    if (!_supported(network, scriptType)) {
      return const Err(WalletProvisioningUnsupportedFailure());
    }
    final provisioned = await _provision(account);
    // An operational refusal stays reconstructible from an exported log, as a
    // fixed code: the imported key material, descriptors and any foreign error
    // text never reach the log.
    if (provisioned case Err(failure: WalletProvisioningStorageFailure())) {
      log.warning('Watch-only import refused reason=storage');
    }
    return provisioned;
  }

  Future<Result<bool, WalletProvisioningFailure>> _hasDefault(
    Network network,
  ) async => switch (await _inventory.listWallets()) {
    Ok(:final value) => Ok(
      value.any((row) => row.isDefault && row.network == _networkCode(network)),
    ),
    Err() => const Err(WalletProvisioningStorageFailure()),
  };

  /// Every derivation happens inside the `secrets` package: what comes back
  /// is an xpub and public descriptors, never the seed or its words.
  Future<Result<_Account, WalletProvisioningFailure>> _fromSecret(
    Secret secret,
    Network network,
    ScriptType scriptType, {
    required String? label,
    required bool isDefault,
    DateTime? birthday,
  }) async {
    if (!_supported(network, scriptType)) {
      return const Err(WalletProvisioningUnsupportedFailure());
    }
    // Each chain keeps its own SLIP-44 coin type, as every wallet already on
    // a device was derived.
    final xpub = await secret.derive.xpub(
      network: network,
      scriptType: scriptType,
    );
    final String external;
    final String internal;
    switch (network) {
      case BitcoinNetwork():
        switch (await secret.derive.descriptors.bitcoin(
          network: network,
          scriptType: scriptType,
        )) {
          case Ok(:final value):
            external = value.external;
            internal = value.internal;
          case Err():
            return const Err(WalletProvisioningSecretFailure());
        }
      case LiquidNetwork():
        // The confidential descriptor covers both keychains; a seed-only
        // secret is refused before anything is loaded.
        switch (await secret.derive.descriptors.liquid(network: network)) {
          case Ok(:final value):
            external = value;
            internal = value;
          case Err():
            return const Err(WalletProvisioningSecretFailure());
        }
    }
    if (xpub case Err()) return const Err(WalletProvisioningSecretFailure());
    final fingerprint = secret.info.id.hex;
    return Ok((
      id: _id(fingerprint, network, scriptType),
      network: network,
      masterFingerprint: fingerprint,
      signer: SignerEntity.local,
      signerDevice: null,
      xpub: (xpub as Ok<String, SecretFailure>).value,
      external: external,
      internal: internal,
      label: label,
      birthday: birthday,
      isDefault: isDefault,
    ));
  }

  /// The writer resolves descriptors from the catalog row: claim it before
  /// native creation, without holding a transaction across native work.
  Future<Result<void, WalletProvisioningFailure>> _provision(
    _Account account,
  ) async {
    final WalletKey key;
    switch (_key(account)) {
      case Ok(:final value):
        key = value;
      case Err(:final failure):
        return Err(failure);
    }
    switch (await _inventory.findWallet(account.id)) {
      case Ok(value: null):
        break;
      case Ok():
        return const Err(WalletProvisioningConflictFailure());
      case Err():
        return const Err(WalletProvisioningStorageFailure());
    }
    if (await _native.prepareCreate(key) case Err()) {
      return const Err(WalletProvisioningStorageFailure());
    }
    final local = account.signer == SignerEntity.local;
    final registered = await _inventory.registerWallet(
      RegisteredWallet(
        id: account.id,
        secretFingerprint: local ? account.masterFingerprint : null,
        masterFingerprint: account.masterFingerprint,
        signer: account.signer.name,
        network: _networkCode(account.network),
        xpub: account.xpub,
        externalDescriptor: account.external,
        internalDescriptor: account.internal,
        label: account.label,
        birthday: account.birthday?.toIso8601String(),
        isDefault: account.isDefault,
      ),
      prepareProperties: (existingSecretMember) => _prepareProperties(
        WalletPropertyDraft(
          id: account.id,
          network: account.network,
          secretFingerprint: local
              ? Fingerprint.tryParse(account.masterFingerprint)
              : null,
          signerDevice: account.signerDevice,
          existingSecretMember: existingSecretMember,
        ),
      ),
    );
    switch (registered) {
      case Ok():
        break;
      case Err(failure: WalletAlreadyRegisteredFailure()):
        return const Err(WalletProvisioningConflictFailure());
      case Err(failure: BackupRequiredFailure()):
        return const Err(WalletProvisioningBackupRequiredFailure());
      case Err():
        return const Err(WalletProvisioningStorageFailure());
    }
    if (await _native.create(key) case Err()) {
      // Only a successful registration owns compensation; secrets and native
      // recovery state stay for a later retry.
      final _ = await _inventory.removeWallet(account.id);
      log.warning('Wallet creation failed catalog row removed');
      return const Err(WalletProvisioningStorageFailure());
    }
    return const Ok(null);
  }

  Future<Result<void, SecretFailure>> _prepareProperties(
    WalletPropertyDraft draft,
  ) async {
    for (final store in _properties) {
      if (await store.prepareWallet(draft) case Err()) {
        return const Err(StoreSecretFailure());
      }
    }
    return const Ok(null);
  }

  /// Checks the derived identity the native writer will resolve.
  static Result<WalletKey, WalletProvisioningFailure> _key(_Account account) {
    final network = account.network;
    final origin = _originOf(account.id);
    final liquid = network is LiquidNetwork;
    if (!RegExp(r'\[[a-fA-F0-9]+/(84h|49h|44h)/\d+h/\d+h\]').hasMatch(origin) ||
        origin.startsWith('el') != liquid ||
        account.id.endsWith(_regtestSuffix) !=
            (network.env == NetworkEnv.regtest)) {
      return const Err(WalletProvisioningInvalidFailure());
    }
    final valid = switch (network) {
      BitcoinNetwork() =>
        BitcoinWalletDescriptor.isPublicDescriptor(account.external) &&
            BitcoinWalletDescriptor.isPublicDescriptor(account.internal),
      LiquidNetwork() => LiquidWalletDescriptor.isConfidentialDescriptor(
        account.external,
      ),
    };
    return valid
        ? Ok(WalletKey(id: account.id, network: network))
        : const Err(WalletProvisioningInvalidFailure());
  }

  static bool _supported(Network network, ScriptType scriptType) =>
      network.env != NetworkEnv.signet &&
      (network != BitcoinNetwork.regtest || scriptType == ScriptType.bip84);

  static String _originOf(String id) => id.endsWith(_regtestSuffix)
      ? id.substring(0, id.length - _regtestSuffix.length)
      : id;

  static String _id(String fingerprint, Network network, ScriptType script) {
    final networkPath = switch (network) {
      BitcoinNetwork.mainnet => '0h',
      LiquidNetwork.mainnet => '1776h',
      _ => '1h',
    };
    final liquid = network is LiquidNetwork;
    final (prefix, purpose) = switch (script) {
      ScriptType.bip84 => (liquid ? 'elwpkh([*])' : 'wpkh([*])', '84h'),
      ScriptType.bip49 => (liquid ? 'elsh(wpkh([*]))' : 'sh(wpkh([*]))', '49h'),
      ScriptType.bip44 => (liquid ? 'elpkh([*])' : 'pkh([*])', '44h'),
    };
    final origin = prefix.replaceAll(
      '[*]',
      '[$fingerprint/$purpose/$networkPath/0h]',
    );
    return network.env == NetworkEnv.regtest
        ? '$origin$_regtestSuffix'
        : origin;
  }

  /// Persisted names are an explicit contract, independent of enum ordering.
  static String _networkCode(Network network) => switch (network) {
    BitcoinNetwork.mainnet => 'bitcoinMainnet',
    BitcoinNetwork.testnet => 'bitcoinTestnet',
    BitcoinNetwork.regtest => 'bitcoinRegtest',
    LiquidNetwork.mainnet => 'liquidMainnet',
    LiquidNetwork.testnet => 'liquidTestnet',
    LiquidNetwork.regtest => 'liquidRegtest',
    BitcoinNetwork.signet => 'bitcoinSignet',
  };
}

/// For owner test support only; delegates to the production identity codec.
String walletIdForTesting({
  required String fingerprint,
  required Network network,
  required ScriptType scriptType,
}) => _WalletProvisioning._id(fingerprint, network, scriptType);

/// For owner test support only; delegates to the production storage codec.
String storedWalletNetworkForTesting(Network network) =>
    _WalletProvisioning._networkCode(network);
