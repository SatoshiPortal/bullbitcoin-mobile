import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:drift/drift.dart';

/// Migration from version 13 to 14
///
/// Changes to walletMetadatas table:
/// - Adds 'bitcoin_sync_backend' column: the sync backend (`electrum` or
///   `compactBlockFilters`) a wallet uses to discover and sync its chain
///   data. Every wallet created before this column existed is backfilled to
///   `electrum` (the column default), since that was the only backend
///   available at the time.
/// - Adds 'last_receive_address_index' column: the highest receive address
///   index revealed by the wallet. Existing wallets are backfilled to `0`,
///   which makes CBF recovery scan from the wallet's start rather than risk
///   skipping addresses.
/// - Adds 'birthday_block_timestamp', 'birthday_block_height', and
///   'birthday_block_hash' columns: the concrete block a wallet's requested
///   `birthday` was resolved to (see `WalletBirthdayCheckpoint`,
///   `domain/entities/`). All three are nullable and atomic — always
///   written together — and default to `NULL` for every existing wallet,
///   since resolution hasn't happened yet for any of them.
///
/// Changes to settings table:
/// - Adds 'use_compact_block_filters_by_default' column. Existing installs
///   are backfilled to `false`, preserving Electrum as their default.
class Schema13To14 {
  static Future<void> migrate(Migrator m, Schema14 schema14) async {
    try {
      await m.addColumn(
        schema14.walletMetadatas,
        schema14.walletMetadatas.bitcoinSyncBackend,
      );
    } catch (e) {
      if (!e.toString().contains('duplicate column')) rethrow;
    }

    try {
      await m.addColumn(
        schema14.walletMetadatas,
        schema14.walletMetadatas.lastReceiveAddressIndex,
      );
    } catch (e) {
      if (!e.toString().contains('duplicate column')) rethrow;
    }

    try {
      await m.addColumn(
        schema14.settings,
        schema14.settings.useCompactBlockFiltersByDefault,
      );
    } catch (e) {
      if (!e.toString().contains('duplicate column')) rethrow;
    }

    try {
      await m.addColumn(
        schema14.walletMetadatas,
        schema14.walletMetadatas.birthdayBlockTimestamp,
      );
    } catch (e) {
      if (!e.toString().contains('duplicate column')) rethrow;
    }

    try {
      await m.addColumn(
        schema14.walletMetadatas,
        schema14.walletMetadatas.birthdayBlockHeight,
      );
    } catch (e) {
      if (!e.toString().contains('duplicate column')) rethrow;
    }

    try {
      await m.addColumn(
        schema14.walletMetadatas,
        schema14.walletMetadatas.birthdayBlockHash,
      );
    } catch (e) {
      if (!e.toString().contains('duplicate column')) rethrow;
    }
  }
}
