import 'package:btc_map/src/data/datasources/btc_map_api_datasource.dart';
import 'package:btc_map/src/data/datasources/merchant_cache_datasource.dart';
import 'package:btc_map/src/data/merchant_mapper.dart';
import 'package:btc_map/src/data/models/merchant_model.dart';
import 'package:btc_map/src/domain/bull_map_failure.dart';
import 'package:btc_map/src/domain/entities/merchant.dart';
import 'package:dio/dio.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../domain/merchant_repository.dart';

/// The one place exceptions are caught: everything leaving it is a
/// [BullMapFailure], so a caller is never left waiting on a sync that threw.
/// Programming errors ([Error]) still surface.
final class MerchantRepositoryImpl implements MerchantRepository {
  final BtcMapApiDatasource _api;
  final MerchantCacheDatasource _cache;

  /// The cache contents by id, once read. Kept so a sync merges into memory
  /// instead of decoding the file again.
  Map<int, MerchantModel>? _snapshot;

  /// The `updated_at` the next sync starts after: the newest change seen,
  /// deletions included, so an evicted place is not fetched again.
  DateTime? _cursor;

  bool _cacheDirty = false;

  /// The merchants last returned. Handed back as is when a sync brings no
  /// change, so the map does not re-upload identical pins.
  List<Merchant>? _merchants;

  /// A sync already running, which a second caller joins instead of starting
  /// another download.
  Future<Result<List<Merchant>, BullMapFailure>>? _syncInFlight;

  MerchantRepositoryImpl(this._api, this._cache);

  /// The merchants stored on the device, without touching the network. Empty
  /// before the first successful sync.
  @override
  @useResult
  Future<Result<List<Merchant>, BullMapFailure>> cached() async {
    try {
      await _loadSnapshot();
      return Ok(_currentMerchants());
    } on Exception catch (error) {
      return Err(BullMapUnexpectedFailure('${error.runtimeType}'));
    }
  }

  /// Brings the device copy up to date with BTC Map and returns all of it.
  ///
  /// The first sync downloads every place; later ones fetch only what changed
  /// after the cursor, deleted places included.
  @override
  @useResult
  Future<Result<List<Merchant>, BullMapFailure>> sync() =>
      _syncInFlight ??= _sync().whenComplete(() => _syncInFlight = null);

  Future<Result<List<Merchant>, BullMapFailure>> _sync() async {
    try {
      final snapshot = await _snapshotOrEmpty();
      final List<MerchantModel> fetched;
      try {
        fetched = await _api.fetchPlaces(updatedSince: _cursor);
      } on DioException catch (error) {
        return Err(BullMapNetworkFailure(error.type.name));
      }
      final cursor = _newest(_cursor, fetched.map((place) => place.updatedAt));
      _cacheDirty = _cacheDirty || cursor != _cursor;
      _cursor = cursor;
      // BTC Map's `updated_since` is exclusive today; dropping what is already
      // stored keeps an inclusive server from rewriting the cache every time.
      final changes = [
        for (final place in fetched)
          if (_changes(snapshot, place)) place,
      ];
      if (changes.isEmpty && !_cacheDirty) return Ok(_currentMerchants());

      for (final place in changes) {
        if (place.isDeleted) {
          snapshot.remove(place.id);
        } else {
          snapshot[place.id] = place;
        }
      }
      if (changes.isNotEmpty) {
        _merchants = null;
        _cacheDirty = true;
      }

      try {
        await _cache.write(
          snapshot.values.toList(growable: false),
          cursor: _cursor,
        );
        _cacheDirty = false;
      } on Exception {
        // Keep the downloaded places on screen and retry this write on the
        // next sync, even when the server has no more changes.
      }
      return Ok(_currentMerchants());
    } on Exception catch (error) {
      return Err(BullMapUnexpectedFailure('${error.runtimeType}'));
    }
  }

  Future<Map<int, MerchantModel>> _loadSnapshot() async {
    final loaded = _snapshot;
    if (loaded != null) return loaded;
    final content = await _cache.read();
    final snapshot = {for (final place in content.places) place.id: place};
    // A cache written before the cursor was stored falls back to its newest
    // place.
    _cursor =
        content.cursor ??
        _newest(null, content.places.map((place) => place.updatedAt));
    return _snapshot = snapshot;
  }

  /// A cache that cannot be read is rebuilt by a full sync rather than
  /// blocking the map forever.
  Future<Map<int, MerchantModel>> _snapshotOrEmpty() async {
    try {
      return await _loadSnapshot();
    } on Exception {
      _cursor = null;
      return _snapshot = {};
    }
  }

  List<Merchant> _currentMerchants() => _merchants ??= [
    for (final place in _snapshot?.values ?? const <MerchantModel>[])
      ?place.toDomain(),
  ];

  /// Whether [place] differs from what [snapshot] already holds.
  static bool _changes(Map<int, MerchantModel> snapshot, MerchantModel place) {
    final stored = snapshot[place.id];
    if (place.isDeleted) return stored != null;
    return stored == null || stored.updatedAt != place.updatedAt;
  }

  static DateTime? _newest(DateTime? start, Iterable<DateTime?> moments) {
    var newest = start;
    for (final moment in moments.nonNulls) {
      if (newest == null || moment.isAfter(newest)) newest = moment;
    }
    return newest;
  }
}
