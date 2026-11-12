import 'package:primitives/primitives.dart' show DatabaseKey;

/// The app's local databases that this feature opens encrypted.
enum LocalDatabase {
  /// `bullbitcoin_sqlite.sqlite`: wallets, labels, transactions, swaps, settings.
  main,

  /// `payjoin.sqlite`: Payjoin sessions and policy.
  payjoin,
}

/// Where each database lives. Given by the shell, which knows each owner's file name.
final class LocalDatabasePaths {
  final String main;
  final String payjoin;

  const LocalDatabasePaths({required this.main, required this.payjoin});

  String of(LocalDatabase database) => switch (database) {
    LocalDatabase.main => main,
    LocalDatabase.payjoin => payjoin,
  };
}

/// A database whose file is encrypted with [key] and opens with it: checked, migrated from clear if it was, and durable on disk.
final class UnlockedDatabase {
  final LocalDatabase database;
  final String path;
  final DatabaseKey key;

  const UnlockedDatabase({
    required this.database,
    required this.path,
    required this.key,
  });

  @override
  String toString() => 'UnlockedDatabase(${database.name})';
}
