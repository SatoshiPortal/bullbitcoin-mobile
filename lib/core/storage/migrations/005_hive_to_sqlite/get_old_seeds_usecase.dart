import 'package:bb_mobile/core/logging/domain/entities/log.dart';
import 'package:bb_mobile/core/logging/domain/usecases/add_log_usecase.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/entities/old_seed.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/entities/old_wallet.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/old_seed_repository.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/old_wallet_repository.dart';

class GetOldSeedsUsecase {
  final OldSeedRepository _oldSeedRepository;
  final OldWalletRepository _oldWalletRepository;
  final AddLogUsecase _addLogUsecase;
  GetOldSeedsUsecase({
    required OldSeedRepository oldSeedRepository,
    required OldWalletRepository oldWalletRepository,
    required AddLogUsecase addLogUsecase,
  }) : _oldSeedRepository = oldSeedRepository,
       _oldWalletRepository = oldWalletRepository,
       _addLogUsecase = addLogUsecase;
  // true : successful migration
  // false: migration was not required / success
  // throw: errors
  Future<List<OldSeed>> execute() async {
    try {
      final oldWallets = await _oldWalletRepository.fetch();
      if (oldWallets.isEmpty) return [];

      final oldMainnetDefaultWallets =
          oldWallets
              .where(
                (e) =>
                    e.type == OldBBWalletType.main &&
                    e.network == OldBBNetwork.Mainnet,
              )
              .toList();
      await _addLogUsecase.execute(
        NewLog(
          level: LogLevel.debug,
          message:
              'PROGRESS: Found  ${oldMainnetDefaultWallets.length} defaultOldSignerWallets',
          logger: 'MigrateToV5HiveToSqliteUsecase',
        ),
      );
      final oldMainnetExternalSignerWallets =
          oldWallets
              .where(
                (e) =>
                    e.type == OldBBWalletType.words &&
                    e.network == OldBBNetwork.Mainnet,
              )
              .toList();

      await _addLogUsecase.execute(
        NewLog(
          level: LogLevel.debug,
          message:
              'PROGRESS: Found ${oldMainnetExternalSignerWallets.length} externalOldSignerWallets',
          logger: 'MigrateToV5HiveToSqliteUsecase',
        ),
      );

      final oldMainnetSignerWallets =
          oldMainnetDefaultWallets + oldMainnetExternalSignerWallets;
      final oldSeeds = <OldSeed>[];
      for (final wallet in oldMainnetSignerWallets) {
        final seed = await _oldSeedRepository.fetch(
          fingerprint: wallet.mnemonicFingerprint,
        );
        if (seed != null) {
          oldSeeds.add(seed);
        }
      }
      return oldSeeds;
    } catch (e) {
      await _addLogUsecase.execute(
        NewLog(
          level: LogLevel.error,
          message: 'Migration failed',
          logger: 'MigrateToV5HiveToSqliteUsecase',
          exception: e,
          stackTrace: StackTrace.current,
        ),
      );
      rethrow;
    }
  }
}
