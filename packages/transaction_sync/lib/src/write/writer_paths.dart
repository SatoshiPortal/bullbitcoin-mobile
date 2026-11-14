/// Shared foreground/worker paths, separate from native stores and app Drift.
String writerMetadataPath(String documentsDirectory) =>
    '$documentsDirectory/transaction_sync/revisions.sqlite';

String writerLockDirectory(String documentsDirectory) =>
    '$documentsDirectory/transaction_sync/locks';
