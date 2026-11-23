import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show QueryExecutor;
import 'package:legacy_storage/coordination.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

import 'exchange_database.dart';

/// Holds the actual keyed native connection on this isolate, without a Drift
/// transport or acknowledgement gap. The receipt and credential projections
/// use only the short startup queries owned by the migration participant.
final class ExchangeStore {
  final ExchangeDatabase database;
  final LifecycleHandle handle;

  const ExchangeStore(this.database, this.handle);

  static Future<Result<ExchangeStore, DatabaseOpenFailure>> open({
    required File file,
    required LifecycleAdmission admission,
    required DatabaseKeys keys,
    required bool existing,
  }) async {
    final settled = Completer<void>();
    QueryExecutor? native;
    ExchangeDatabase? database;
    final handle = admission.track(() async {
      await settled.future;
      if (database case final opened?) {
        await opened.close();
      } else {
        await native?.close();
      }
    });

    Result<ExchangeStore, DatabaseOpenFailure> result;
    try {
      switch (await keys.open(
        name: 'main',
        file: file,
        existingSchemaVersion: existing ? 1 : null,
      )) {
        case Ok(:final value):
          native = value;
          final opened = ExchangeDatabase(value);
          database = opened;
          await opened.customSelect('SELECT 1').get();
          result = Ok(ExchangeStore(opened, handle));
        case Err(:final failure):
          result = Err(failure);
      }
    } on Exception {
      // Neither SQL parameters nor paths are safe to forward.
      result = const Err(
        DatabaseFileUnavailable(DatabaseFileProblem.inaccessible),
      );
    } finally {
      settled.complete();
    }
    if (result case Err()) await handle.close();
    return result;
  }
}
