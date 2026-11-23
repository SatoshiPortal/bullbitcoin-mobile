import 'dart:io';

import 'package:drift/drift.dart' show QueryExecutor;
import 'package:flutter/services.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/domain/domain.dart';

import 'database_key_repository.dart';
import 'encrypted_database.dart';

Future<Result<QueryExecutor, F>> Function() Function(bool existing)
captureDatabaseWorkerOpener<F extends Failure>({
  required String module,
  required String name,
  required String path,
  required int schema,
  required F deferred,
  required F unavailable,
}) => _databaseOpenerFactory(
  module,
  name,
  path,
  schema,
  RootIsolateToken.instance,
  deferred,
  unavailable,
);

Future<Result<QueryExecutor, F>> Function() Function(bool existing)
_databaseOpenerFactory<F extends Failure>(
  String module,
  String name,
  String path,
  int schema,
  RootIsolateToken? token,
  F deferred,
  F unavailable,
) =>
    (existing) => _databaseWorkerOpener(
      module,
      name,
      path,
      existing ? schema : null,
      token,
      deferred,
      unavailable,
    );

Future<Result<QueryExecutor, F>> Function()
_databaseWorkerOpener<F extends Failure>(
  String module,
  String name,
  String path,
  int? schema,
  RootIsolateToken? token,
  F deferred,
  F unavailable,
) => () async {
  if (token == null) return Err(deferred);
  BackgroundIsolateBinaryMessenger.ensureInitialized(token);
  final opened = await openEncryptedDatabase(
    DatabaseKeyRepository(),
    module: module,
    name: name,
    file: File(path),
    existingSchemaVersion: schema,
  );
  return switch (opened) {
    Ok(:final value) => Ok(value),
    Err(failure: DatabaseNotReady()) ||
    Err(
      failure: DatabaseKeyUnavailable(reason: DatabaseKeyProblem.locked),
    ) => Err(deferred),
    Err() => Err(unavailable),
  };
};
