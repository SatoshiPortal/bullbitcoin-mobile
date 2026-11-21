import 'package:bb_mobile/features/bip85_entropy/data/bip85_repository.dart';
import 'package:bb_mobile/features/bip85_entropy/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/features/bip85_entropy/domain/errors/bip85_failure.dart';
import 'package:secrets/secrets.dart';
import 'package:primitives/primitives.dart' show Err, Fingerprint, Ok, Result;
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

class DeriveNextBip85HexFromDefaultWalletUsecase {
  final Bip85Repository _bip85Repository;
  final Secrets _secrets;

  DeriveNextBip85HexFromDefaultWalletUsecase({
    required this._bip85Repository,
    required this._secrets,
  });

  @useResult
  Future<Result<({String derivation, String hex}), Bip85Failure>> execute({
    required Fingerprint fingerprint,
    required int length,
    String? alias,
  }) async {
    try {
      final secret = switch (await _secrets.fetch(fingerprint)) {
        Ok(:final value) => value,
        Err(:final failure) => throw StateError(failure.runtimeType.toString()),
      };

      const application = Bip85Application.hex;
      final indexResult = await _bip85Repository.fetchNextIndexForApplication(
        application,
      );
      switch (indexResult) {
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          // Derived inside the package — the xprv never comes out — then recorded by the repository under the same path it has always written.
          final hex = switch (await secret.derive.bip85.hex(
            numBytes: length,
            index: value,
          )) {
            Ok(:final value) => value,
            Err(:final failure) => throw StateError(
              failure.runtimeType.toString(),
            ),
          };
          return (await _bip85Repository.recordHex(
            xprvFingerprint: secret.id.hex,
            length: length,
            index: value,
            alias: alias,
          )).map((derivation) => (derivation: derivation, hex: hex));
      }
    } catch (e, st) {
      log.severe(
        message: 'DeriveNextBip85HexFromDefaultWalletUsecase failed',
        error: e,
        trace: st,
      );
      return Err(Bip85UnexpectedFailure('derivation: ${e.runtimeType}'));
    }
  }
}
