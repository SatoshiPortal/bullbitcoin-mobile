import 'dart:async';

import 'package:primitives/primitives.dart';

import '../domain/domain.dart';
import 'backup_guard.dart';
import 'boundary.dart';

Future<Result<T, SecretFailure>> runInventorySession<T>(
  Future<Result<T, SecretFailure>> Function() run, {
  required bool Function() isCurrent,
  bool preserveCommittedCommand = false,
  void Function()? onCatalogueCommit,
}) async {
  var committed = false;
  final result = await Zone.current
      .fork(
        zoneValues: {
          inventorySessionCheck: isCurrent,
          inventoryCommitConfirmed: () => committed = true,
          inventoryCatalogueCommitConfirmed: onCatalogueCommit,
        },
      )
      .run(run);
  return isCurrent() || (preserveCommittedCommand && committed && result is Ok)
      ? result
      : const Err(inventorySessionChangedFailure);
}
