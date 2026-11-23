/// The application database used by the legacy schema and its remaining readers.
library;

export 'src/app_database/sqlite_database.dart' show SqliteDatabase;
export 'src/app_database/tables/bip85_derivations_table.dart'
    show Bip85ApplicationColumn, Bip85StatusColumn;
export 'src/app_database/tables/bip85_derivations_table.drift.dart'
    show Bip85DerivationRow, Bip85DerivationsCompanion;
export 'src/app_database/tables/settings_table.dart' show Settings;
export 'src/app_database/tables/wallet_metadata_table.dart'
    show Signer, SignerDevice;
export 'src/app_database/tables/wallet_metadata_table.drift.dart'
    show WalletMetadataRow, WalletMetadatasCompanion;
