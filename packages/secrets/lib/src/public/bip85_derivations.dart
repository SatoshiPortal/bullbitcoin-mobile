part of 'secrets_inventory.dart';

enum Bip85Status { active, inactive, revoked }

enum Bip85Application { bip39, wif, xprv, hex, pwdBase64, pwdBase85, rsa, dice }

/// Metadata for a registered child. The derived material lives separately.
class Bip85Derivation {
  final RecordedDerivation _record;
  final Bip85Status status;
  final Bip85Application application;
  final int index;

  const Bip85Derivation._(
    this._record,
    this.status,
    this.application,
    this.index,
  );

  String get path => _record.path;
  String get parentFingerprint => _record.parentFingerprint;
  String? get alias => _record.alias;

  static Bip85Derivation? _decode(RecordedDerivation record) {
    final index = record.index;
    final application = Bip85Application.values
        .where((value) => value.name == record.application)
        .firstOrNull;
    final status = Bip85Status.values
        .where((value) => value.name == record.status)
        .firstOrNull;
    if (index == null || application == null || status == null) return null;
    return Bip85Derivation._(record, status, application, index);
  }
}

/// A foreground registry of deterministic children, gated by the inventory
/// session. The derivation roots stay in Secrets.
class Bip85Derivations {
  final SecretsInventory _inventory;
  final Secrets _secrets;

  const Bip85Derivations._(this._inventory, this._secrets);

  /// Includes revoked and inactive records. Unreadable metadata fails closed.
  @useResult
  Future<Result<List<Bip85Derivation>, SecretFailure>> list() async {
    switch (await _inventory.listDerivations()) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        final records = <Bip85Derivation>[];
        for (final raw in value) {
          final record = Bip85Derivation._decode(raw);
          if (record == null) {
            return const Err(unreadableBip85RecordFailure);
          }
          records.add(record);
        }
        return Ok(List.unmodifiable(records));
    }
  }

  /// Allocates the next HEX index. The committed reservation is never reused.
  @useResult
  Future<Result<Bip85Derivation, SecretFailure>> deriveNextHex({
    required Fingerprint parent,
    required int length,
    String? alias,
  }) async {
    if (length < 16 || length > 64) {
      return const Err(invalidBip85HexLengthFailure);
    }
    return _reserveAndDerive(
      parent,
      reserve: () => _inventory.reserveHexDerivation(
        parent: parent,
        length: length,
        alias: alias,
      ),
      derive: (secret, index) =>
          secret.derive.bip85.hex(numBytes: length, index: index),
    );
  }

  /// Allocates the next English BIP39 child, regardless of the root's language.
  @useResult
  Future<Result<Bip85Derivation, SecretFailure>> deriveNextMnemonic({
    required Fingerprint parent,
    MnemonicLength length = MnemonicLength.words12,
    String? alias,
  }) => _reserveAndDerive(
    parent,
    reserve: () => _inventory.reserveMnemonicDerivation(
      parent: parent,
      length: length,
      language: Language.english,
      alias: alias,
    ),
    derive: (secret, index) => secret.derive.bip85.mnemonic(
      wordCount: length,
      index: index,
      language: Language.english,
    ),
  );

  Future<Result<Bip85Derivation, SecretFailure>> _reserveAndDerive<T>(
    Fingerprint parent, {
    required Future<Result<RecordedDerivation, SecretFailure>> Function()
    reserve,
    required Future<Result<T, SecretFailure>> Function(Secret, int) derive,
  }) => _inventory._inSession((session, _) async {
    final Secret secret;
    switch (await _secrets.fetch(parent)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        secret = value;
    }
    if (session != _inventory._session) {
      return const Err(inventorySessionChangedFailure);
    }
    switch (await reserve()) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        final record = Bip85Derivation._decode(value);
        if (record == null) {
          return const Err(unreadableBip85RecordFailure);
        }
        return (await derive(secret, record.index)).map((_) => record);
    }
  });

  /// Re-derives the registered HEX and English BIP39 children of [parent].
  /// Each path is validated against its application before using the root.
  @useResult
  Future<
    Result<List<({Bip85Derivation derivation, String entropy})>, SecretFailure>
  >
  reveal(Fingerprint parent) => _inventory._inSession((session, _) async {
    final Secret secret;
    switch (await _secrets.fetch(parent)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        secret = value;
    }
    if (session != _inventory._session) {
      return const Err(inventorySessionChangedFailure);
    }
    switch (await list()) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        final children = <({Bip85Derivation derivation, String entropy})>[];
        for (final record in value) {
          if (session != _inventory._session) {
            return const Err(inventorySessionChangedFailure);
          }
          if (record.parentFingerprint.toLowerCase() != parent.hex) continue;
          switch (await _derive(secret, record)) {
            case Err(:final failure):
              return Err(failure);
            case Ok(value: final entropy?):
              children.add((derivation: record, entropy: entropy));
            case Ok(value: null):
              break;
          }
        }
        return Ok(List.unmodifiable(children));
    }
  });

  Future<Result<String?, SecretFailure>> _derive(
    Secret secret,
    Bip85Derivation record,
  ) async {
    final path = record.path.replaceFirst(RegExp(r'^m/'), '').split('/');
    final segments = <int>[];
    for (final segment in path) {
      if (!segment.endsWith("'")) return const Ok(null);
      final value = int.tryParse(segment.substring(0, segment.length - 1));
      if (value == null || value < 0 || value >= 0x80000000) {
        return const Ok(null);
      }
      segments.add(value);
    }
    switch ((record.application, segments)) {
      case (Bip85Application.hex, [128169, final length, final index])
          when index == record.index:
        return secret.derive.bip85.hex(numBytes: length, index: index);
      case (Bip85Application.bip39, [39, 0, final count, final index])
          when index == record.index:
        final length = MnemonicLength.values
            .where((value) => value.words == count)
            .firstOrNull;
        if (length == null) return const Ok(null);
        return (await secret.derive.bip85.mnemonic(
          wordCount: length,
          index: index,
          language: Language.english,
        )).map((words) => words.join(' '));
      default:
        return const Ok(null);
    }
  }

  @useResult
  Future<Result<void, SecretFailure>> rename(
    Bip85Derivation derivation,
    String? alias,
  ) => _inventory.renameDerivation(derivation._record, alias);

  @useResult
  Future<Result<void, SecretFailure>> setActive(
    Bip85Derivation derivation, {
    required bool active,
  }) => _inventory.setDerivationActive(derivation._record, active: active);
}
