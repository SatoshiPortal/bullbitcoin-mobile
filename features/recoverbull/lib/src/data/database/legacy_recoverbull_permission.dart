import 'dart:io';

import 'package:legacy_storage/owner_database.dart';
import 'package:primitives/primitives.dart';

import '../../domain/recoverbull_failure.dart';

/// Reads only consent from an old schema-1 file. The caller holds exclusive
/// cutover admission. A missing family or singleton returns `Ok(null)`.
Future<Result<bool?, RecoverBullFailure>> readLegacyRecoverBullPermission(
  File file,
) async {
  try {
    bool? permission;
    final verified = await readStandaloneSource(file, (source) async {
      if (source == null) return true;
      if (source.userVersion != 1) return false;
      final rows = source.select(
        'SELECT id, permission_granted FROM recoverbull_state',
      );
      if (rows.isEmpty) return true;
      if (rows.length != 1) return false;
      final row = rows.single;
      final id = row['id'];
      if (id is! int || id != 1) return false;
      final value = row['permission_granted'];
      if (value is! int || (value != 0 && value != 1)) return false;
      permission = value == 1;
      return true;
    });
    return verified ? Ok(permission) : const Err(VaultStorageFailure());
  } on Exception {
    return const Err(VaultStorageFailure());
  }
}
