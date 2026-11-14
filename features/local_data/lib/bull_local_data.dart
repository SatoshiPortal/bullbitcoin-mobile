/// Opens the app's local databases encrypted, and recovers when they cannot be opened.
library;

export 'generated/l10n/local_data_localizations.dart'
    show LocalDataLocalizations;
export 'public/local_data.dart' show LocalData, LocalDataSession;
export 'src/domain/local_data_failure.dart';
export 'src/domain/local_database.dart' show LocalDatabase, LocalDatabasePaths;
