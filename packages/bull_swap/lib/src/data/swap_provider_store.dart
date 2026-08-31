import 'package:bull_swap/src/data/db/swap_database.dart';
import 'package:bull_swap/src/domain/swap_provider_config.dart';
import 'package:bull_swap/src/domain/swap_provider_kind.dart';
import 'package:drift/drift.dart';

class SwapProviderStore {
  final SwapDatabase _db;
  final int Function() _now;

  SwapProviderStore(this._db, {int Function()? now})
    : _now = now ?? (() => DateTime.now().microsecondsSinceEpoch);

  Future<void> ensureSeeded(
    List<SwapProviderConfig> builtIns,
    String defaultActiveId,
  ) async {
    await _db.transaction(() async {
      for (final config in builtIns) {
        await _db
            .into(_db.swapProviders)
            .insert(_toCompanion(config), mode: InsertMode.insertOrIgnore);
      }
      final active = await _activeRow();
      if (active == null) {
        await _setActiveLocked(defaultActiveId);
      }
    });
  }

  Future<List<SwapProviderConfig>> all() async {
    final rows = await _db.select(_db.swapProviders).get();
    return rows.map(_fromRow).toList(growable: false);
  }

  Future<SwapProviderConfig?> active() async {
    final row = await _activeRow();
    return row == null ? null : _fromRow(row);
  }

  Future<SwapProviderConfig?> byId(String id) async {
    final row = await (_db.select(
      _db.swapProviders,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  Future<void> setActive(String id) =>
      _db.transaction(() => _setActiveLocked(id));

  Future<SwapProviderConfig> addCustomBoltz({
    required String name,
    required String baseUrl,
    String? id,
  }) async {
    final config = SwapProviderConfig(
      id: id ?? 'boltz-custom-${_now()}',
      kind: SwapProviderKind.boltz,
      name: name,
      baseUrl: baseUrl,
    );
    await _db.into(_db.swapProviders).insert(_toCompanion(config));
    return config;
  }

  Future<void> removeCustom(String id) async {
    await _db.transaction(() async {
      final row = await (_db.select(
        _db.swapProviders,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (row == null || row.isBuiltIn) return;
      if (row.isActive) {
        final fallback =
            await (_db.select(_db.swapProviders)
                  ..where((t) => t.isBuiltIn.equals(true))
                  ..limit(1))
                .getSingleOrNull();
        if (fallback != null) await _setActiveLocked(fallback.id);
      }
      await (_db.delete(_db.swapProviders)..where((t) => t.id.equals(id))).go();
    });
  }

  Future<SwapProviderRow?> _activeRow() => (_db.select(
    _db.swapProviders,
  )..where((t) => t.isActive.equals(true))).getSingleOrNull();

  Future<void> _setActiveLocked(String id) async {
    await _db
        .update(_db.swapProviders)
        .write(const SwapProvidersCompanion(isActive: Value(false)));
    final updated =
        await (_db.update(_db.swapProviders)..where((t) => t.id.equals(id)))
            .write(const SwapProvidersCompanion(isActive: Value(true)));
    if (updated == 0) {
      throw ArgumentError('Unknown swap provider: $id');
    }
  }

  SwapProvidersCompanion _toCompanion(SwapProviderConfig config) =>
      SwapProvidersCompanion(
        id: Value(config.id),
        kind: Value(config.kind.name),
        name: Value(config.name),
        baseUrl: Value(config.baseUrl),
        isBuiltIn: Value(config.isBuiltIn),
        createdAt: Value(_now()),
      );

  SwapProviderConfig _fromRow(SwapProviderRow row) => SwapProviderConfig(
    id: row.id,
    kind: SwapProviderKind.fromName(row.kind),
    name: row.name,
    baseUrl: row.baseUrl,
    isBuiltIn: row.isBuiltIn,
  );
}
