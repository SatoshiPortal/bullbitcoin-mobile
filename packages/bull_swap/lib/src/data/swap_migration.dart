import 'package:bull_swap/src/data/db/swap_database.dart';
import 'package:bull_swap/src/data/swap_legacy_data_port.dart';
import 'package:drift/drift.dart';

const _legacyImportName = 'root-swaps-v1';

Future<void> importLegacySwapData(
  SwapDatabase database,
  SwapLegacyDataPort source, {
  int Function()? now,
}) async {
  final stamp = now ?? (() => DateTime.now().millisecondsSinceEpoch);

  final completed = await (database.select(
    database.swapMigrations,
  )..where((row) => row.name.equals(_legacyImportName))).getSingleOrNull();
  if (completed != null) return;

  final swaps = await source.readSwaps();
  final autoSwaps = await source.readAutoSwaps();
  final orderSwaps = await source.readOrderSwaps();

  await database.transaction(() async {
    final marker = await (database.select(
      database.swapMigrations,
    )..where((row) => row.name.equals(_legacyImportName))).getSingleOrNull();
    if (marker != null) return;

    for (final swap in swaps) {
      await database
          .into(database.swaps)
          .insert(swap, mode: InsertMode.insertOrIgnore);
    }
    for (final autoSwap in autoSwaps) {
      await database
          .into(database.autoSwap)
          .insert(autoSwap, mode: InsertMode.insertOrIgnore);
    }
    for (final order in orderSwaps) {
      await database
          .into(database.orderSwaps)
          .insert(order, mode: InsertMode.insertOrIgnore);
    }

    await database
        .into(database.swapMigrations)
        .insert(
          SwapMigrationsCompanion.insert(
            name: _legacyImportName,
            completedAt: stamp(),
          ),
        );
  });
}
