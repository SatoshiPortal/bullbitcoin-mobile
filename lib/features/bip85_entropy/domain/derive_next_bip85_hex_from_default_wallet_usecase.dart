import 'package:bb_mobile/features/bip85_entropy/data/bip85_repository.dart';
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

      final reservation = await _bip85Repository.reserveHex(
        parent: secret.id,
        length: length,
        alias: alias,
      );
      switch (reservation) {
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          final index = value.index;
          if (index == null) return const Err(Bip85StorageFailure());
          final hex = switch (await secret.derive.bip85.hex(
            numBytes: length,
            index: index,
          )) {
            Ok(:final value) => value,
            Err(:final failure) => throw StateError(
              failure.runtimeType.toString(),
            ),
          };
          return Ok((derivation: value.path, hex: hex));
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
