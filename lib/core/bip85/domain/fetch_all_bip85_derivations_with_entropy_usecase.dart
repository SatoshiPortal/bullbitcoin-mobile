import 'package:bb_mobile/core/bip85/data/bip85_repository.dart';
import 'package:bb_mobile/core/bip85/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/core/bip85/domain/errors/bip85_failure.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart' show Fingerprint;
import 'package:secrets/secrets.dart';

/// Every persisted BIP85 derivation of the default wallet, with its value re-derived.
///
/// The value is re-derived inside the `secrets` package from the persisted path — the xprv never comes out here, as it used to. Each row is dispatched on its application to the package's existing HEX or BIP39 operation; a path of any other application was never written by this app and is skipped with a log line rather than guessed at.
///
/// One keystore read and one PBKDF2 pass per row, today. A batch operation that materialises once for N paths is planned; correctness first.
class FetchAllBip85DerivationsWithEntropyUsecase {
  final Bip85Repository _bip85Repository;
  final WalletRepository _walletRepository;
  final SettingsRepository _settingsRepository;
  final Secrets _secrets;

  FetchAllBip85DerivationsWithEntropyUsecase({
    required Bip85Repository bip85Repository,
    required WalletRepository walletRepository,
    required SettingsRepository settingsRepository,
    required Secrets secrets,
  }) : this._(bip85Repository, walletRepository, settingsRepository, secrets);

  const FetchAllBip85DerivationsWithEntropyUsecase._(
    this._bip85Repository,
    this._walletRepository,
    this._settingsRepository,
    this._secrets,
  );

  @useResult
  Future<
    Result<
      List<({Bip85DerivationEntity derivation, String entropy})>,
      Bip85Failure
    >
  >
  execute() async {
    try {
      final settings = await _settingsRepository.fetch();
      final wallets = await _walletRepository.getWallets(
        onlyDefaults: true,
        onlyBitcoin: true,
        environment: settings.environment,
      );
      if (wallets.isEmpty) return const Err(Bip85NoDefaultWalletFailure());
      final secret = switch (await _secrets.fetch(
        Fingerprint(wallets.first.masterFingerprint),
      )) {
        Ok(:final value) => value,
        Err(:final failure) => throw StateError(failure.runtimeType.toString()),
      };

      switch (await _bip85Repository.fetchAll()) {
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          final out = <({Bip85DerivationEntity derivation, String entropy})>[];
          for (final e in value) {
            // A row is bound to the root key that created it. If that key is no longer the default, never show a value derived from another wallet in its place. The root fingerprint is the master fingerprint.
            if (e.xprvFingerprint.toLowerCase() != secret.id.hex) continue;
            final entropy = await _derive(secret, e);
            if (entropy != null) out.add((derivation: e, entropy: entropy));
          }
          return Ok(out);
      }
    } catch (e, st) {
      log.severe(
        message: 'FetchAllBip85DerivationsWithEntropyUsecase failed',
        error: e,
        trace: st,
      );
      return Err(Bip85UnexpectedFailure(e.toString()));
    }
  }

  /// Re-derives one row from its persisted path, through the package operation that produced it.
  ///
  /// The path is checked, not trusted: every component hardened, the application number matching the row's tag, the index matching the row's. A row that fails any of these is skipped and logged — never derived as something else.
  static Future<String?> _derive(Secret secret, Bip85DerivationEntity e) async {
    final parts = e.path.replaceFirst(RegExp(r"^m/"), '').split('/');
    if (parts.any((p) => !p.endsWith("'"))) {
      return _skip(e, 'unhardened component');
    }
    final segments = parts
        .map((p) => int.tryParse(p.substring(0, p.length - 1)))
        .toList();
    if (segments.any((n) => n == null)) {
      return _skip(e, 'non-numeric component');
    }
    if (segments.last != e.index) {
      return _skip(e, 'index does not match the row');
    }

    final Result<String, SecretFailure>? result = switch (e.application) {
      Bip85Application.hex when segments.length == 3 && segments[0] == 128169 =>
        await secret.derive.bip85.hex(
          numBytes: segments[1]!,
          index: segments[2]!,
        ),
      Bip85Application.bip39
          when segments.length == 4 && segments[0] == 39 && segments[1] == 0 =>
        (await secret.derive.bip85.mnemonic(
          length: bip39.MnemonicLength.fromWords(segments[2]!),
          index: segments[3]!,
        )).map((words) => words.join(' ')),
      _ => null,
    };
    if (result == null) {
      return _skip(e, 'path does not match its application tag');
    }
    return switch (result) {
      Ok(:final value) => value,
      Err(:final failure) => throw StateError(failure.runtimeType.toString()),
    };
  }

  static String? _skip(Bip85DerivationEntity e, String why) {
    log.warning('BIP85: row skipped, $why (${e.application.name})');
    return null;
  }
}
