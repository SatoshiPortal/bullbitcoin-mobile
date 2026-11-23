import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show QueryExecutor;
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:legacy_storage/owner_database.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

import 'exchange_database.dart';

final class ExchangeStore {
  final ExchangeDatabase database;
  final LifecycleHandle handle;

  const ExchangeStore(this.database, this.handle);

  static Future<Result<ExchangeStore, LegacyImportFailure>> open({
    required File file,
    required LifecycleAdmission admission,
    required bool existing,
  }) async => (await OwnerDatabase.open(
    admission: admission,
    openExecutor: Secrets.databaseOpener<LegacyImportFailure>(
      module: 'exchange',
      name: 'main',
      file: file,
      schema: ExchangeDatabase.schema,
      deferred: const LegacyImportDeferred(),
      unavailable: const LegacyImportUnavailable(),
    )(existing),
    create: ExchangeDatabase.new,
  )).map((store) => ExchangeStore(store.database, store.handle));

  /// The test keystore platform is installed only on the current isolate.
  /// Keep its native connection tracked directly for import projection tests.
  static Future<Result<ExchangeStore, LegacyImportFailure>> openForTesting({
    required File file,
    required LifecycleAdmission admission,
    required DatabaseKeys keys,
    required bool existing,
  }) async {
    final settled = Completer<void>();
    QueryExecutor? native;
    ExchangeDatabase? database;
    final LifecycleHandle handle;
    try {
      handle = admission.track(() async {
        await settled.future;
        if (database case final opened?) {
          await opened.close();
        } else {
          await native?.close();
        }
      });
    } on LifecycleException {
      return const Err(LegacyImportDeferred());
    }

    Result<ExchangeStore, LegacyImportFailure> result;
    try {
      switch (await keys.open(
        name: 'main',
        file: file,
        existingSchemaVersion: existing ? ExchangeDatabase.schema : null,
      )) {
        case Ok(:final value):
          native = value;
          final opened = ExchangeDatabase(value);
          database = opened;
          await opened.customSelect('SELECT 1').get();
          result = Ok(ExchangeStore(opened, handle));
        case Err(:final failure):
          result = switch (failure) {
            DatabaseNotReady() ||
            DatabaseKeyUnavailable(
              reason: DatabaseKeyProblem.locked,
            ) => const Err(LegacyImportDeferred()),
            _ => const Err(LegacyImportUnavailable()),
          };
      }
    } on Exception {
      // Neither SQL parameters nor paths are safe to forward.
      result = const Err(LegacyImportUnavailable());
    } finally {
      settled.complete();
    }
    if (result case Err()) await handle.close();
    return result;
  }
}
