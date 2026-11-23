import 'package:bb_mobile/features/bip85_entropy/data/bip85_repository.dart';
import 'package:bb_mobile/features/bip85_entropy/domain/errors/bip85_failure.dart';
import 'package:secrets/secrets.dart';
import 'package:primitives/primitives.dart' show Err, Fingerprint, Ok, Result;
import 'package:bull_logger/bull_logger.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:meta/meta.dart';

class DeriveNextBip85MnemonicFromDefaultWalletUsecase {
  final Bip85Repository _bip85Repository;
  final Secrets _secrets;

  DeriveNextBip85MnemonicFromDefaultWalletUsecase({
    required this._bip85Repository,
    required this._secrets,
  });

  @useResult
  Future<Result<({String derivation, bip39.Mnemonic mnemonic}), Bip85Failure>>
  execute({
    required Fingerprint fingerprint,
    bip39.MnemonicLength length = bip39.MnemonicLength.words12,
    String? alias,
  }) async {
    try {
      final secret = switch (await _secrets.fetch(fingerprint)) {
        Ok(:final value) => value,
        Err(:final failure) => throw StateError(failure.runtimeType.toString()),
      };

      // BIP85 children are English by design.
      const language = bip39.Language.english;
      final reservation = await _bip85Repository.reserveMnemonic(
        parent: secret.id,
        length: length,
        alias: alias,
        language: language,
      );
      switch (reservation) {
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          final index = value.index;
          if (index == null) return const Err(Bip85StorageFailure());
          final words = switch (await secret.derive.bip85.mnemonic(
            wordCount: MnemonicLength.values.byName(length.name),
            index: index,
            language: language,
          )) {
            Ok(:final value) => value,
            Err(:final failure) => throw StateError(
              failure.runtimeType.toString(),
            ),
          };
          return Ok((
            derivation: value.path,
            mnemonic: bip39.Mnemonic.fromWords(
              words: words,
              language: language,
            ),
          ));
      }
    } catch (e, st) {
      log.severe(
        message: 'DeriveNextBip85MnemonicFromDefaultWalletUsecase failed',
        error: e,
        trace: st,
      );
      return Err(Bip85UnexpectedFailure('derivation: ${e.runtimeType}'));
    }
  }
}
