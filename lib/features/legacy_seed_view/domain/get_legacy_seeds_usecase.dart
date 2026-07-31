import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/keychain_locked_exception.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/get_old_seeds_usecase.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/entities/old_seed.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/legacy_seed_view/domain/legacy_seed_view_failure.dart';
import 'package:meta/meta.dart';

/// Feature boundary: wraps the shared core [GetOldSeedsUsecase] (which still
/// throws) in the first layer this feature owns. Logs sanitized exception
/// metadata and returns a typed [LegacySeedViewFailure] so nothing above ever
/// sees raw exception text.
class GetLegacySeedsUsecase {
  final GetOldSeedsUsecase _getOldSeedsUsecase;

  GetLegacySeedsUsecase({required this._getOldSeedsUsecase});

  @useResult
  Future<Result<List<OldSeed>, LegacySeedViewFailure>> execute() async {
    try {
      final seeds = await _getOldSeedsUsecase.execute();
      return Ok(_dedupeByMnemonic(seeds));
    } on KeychainLockedException catch (e, st) {
      // Exceptions from this secret-bearing flow may contain key material.
      // Record the safe type and trace, never the exception payload itself.
      log.warning(
        'fetch legacy seeds unavailable (${e.runtimeType})',
        error: e.runtimeType,
        trace: st,
      );
      return const Err(LegacySeedViewFetchFailure());
    } on Exception catch (e, st) {
      log.severe(
        message: 'fetch legacy seeds failed (${e.runtimeType})',
        error: e.runtimeType,
        trace: st,
      );
      return const Err(LegacySeedViewUnexpectedFailure());
    }
  }

  /// Collapses seeds that share a mnemonic into one entry, merging their
  /// passphrases (deduplicated by passphrase + source fingerprint).
  List<OldSeed> _dedupeByMnemonic(List<OldSeed> seeds) {
    final mnemonicMap = <String, OldSeed>{};
    for (final seed in seeds) {
      final existing = mnemonicMap[seed.mnemonic];
      if (existing == null) {
        mnemonicMap[seed.mnemonic] = seed;
        continue;
      }
      mnemonicMap[seed.mnemonic] = existing.copyWith(
        passphrases: [
          ...existing.passphrases,
          ...seed.passphrases.where(
            (p) => !existing.passphrases.any(
              (ep) =>
                  ep.passphrase == p.passphrase &&
                  ep.sourceFingerprint == p.sourceFingerprint,
            ),
          ),
        ],
      );
    }
    return mnemonicMap.values.toList();
  }
}
