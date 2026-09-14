import 'package:drift/drift.dart';

/// What each vault has agreed to publish where, and how far that got.
///
/// One row per vault and destination. It holds the exact bytes that were signed
/// or sealed, written before the first send, so a retry after a lost
/// acknowledgement resends the same artifact instead of making a second one
/// (plan 7). Nothing here is a schedule: retries happen when a person asks.
@DataClassName('VaultDescriptorPublicationRow')
class VaultDescriptorPublications extends Table {
  TextColumn get walletId => text()();

  /// `server` or `nostr`. Bitcoin is not a destination this build can select.
  TextColumn get destination => text()();

  /// The person's choice for this destination, which nothing else may change.
  BoolColumn get enabled => boolean().withDefault(const Constant(false))();

  /// The signed Nostr event, or the BIP138 artifact, exactly as it was sent.
  BlobColumn get artifact => blob().nullable()();
  TextColumn get artifactSha256 => text().nullable()();

  /// `idle`, `pending`, `sent`, `verified` or `failed`.
  TextColumn get state => text().withDefault(const Constant('idle'))();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {walletId, destination};
}
