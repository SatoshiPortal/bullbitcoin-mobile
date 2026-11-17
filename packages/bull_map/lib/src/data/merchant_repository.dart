import 'dart:io';

import 'package:bull_map/src/data/datasources/btc_map_api_datasource.dart';
import 'package:bull_map/src/data/datasources/merchant_cache_datasource.dart';
import 'package:bull_map/src/data/merchant_mapper.dart';
import 'package:bull_map/src/data/models/merchant_model.dart';
import 'package:bull_map/src/domain/bull_map_failure.dart';
import 'package:bull_map/src/domain/entities/merchant.dart';
import 'package:dio/dio.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

final class MerchantRepository {
  final BtcMapApiDatasource _api;
  final MerchantCacheDatasource _cache;

  /// The cache contents by id, once read. Kept so a sync merges into memory
  /// instead of decoding the file again.
  Map<int, MerchantModel>? _snapshot;

  /// A sync already running, which a second caller joins instead of starting
  /// another download.
  Future<Result<List<Merchant>, BullMapFailure>>? _syncInFlight;

  MerchantRepository(this._api, this._cache);

  /// The merchants stored on the device, without touching the network. Empty
  /// before the first successful sync.
  @useResult
  Future<Result<List<Merchant>, BullMapFailure>> cached() async {
    try {
      return Ok(_toDomain(await _loadSnapshot()));
    } on FileSystemException catch (error) {
      return Err(BullMapUnexpectedFailure('${error.runtimeType}'));
    } on FormatException catch (error) {
      return Err(BullMapUnexpectedFailure('${error.runtimeType}'));
    }
  }

  /// Brings the device copy up to date with BTC Map and returns all of it.
  ///
  /// The first sync downloads every place; later ones fetch only what changed
  /// since the newest place already stored, deleted places included.
  @useResult
  Future<Result<List<Merchant>, BullMapFailure>> sync() =>
      _syncInFlight ??= _sync().whenComplete(() => _syncInFlight = null);

  Future<Result<List<Merchant>, BullMapFailure>> _sync() async {
    final snapshot = await _snapshotOrEmpty();
    final since = _newestUpdate(snapshot.values);

    final List<MerchantModel> changes;
    try {
      changes = await _api.fetchPlaces(updatedSince: since);
    } on DioException catch (error) {
      return Err(BullMapNetworkFailure(error.type.name));
    } on FormatException catch (error) {
      return Err(BullMapUnexpectedFailure('${error.runtimeType}'));
    }

    for (final place in changes) {
      if (place.isDeleted) {
        snapshot.remove(place.id);
      } else {
        snapshot[place.id] = place;
      }
    }

    if (changes.isNotEmpty) {
      try {
        await _cache.write(snapshot.values.toList(growable: false));
      } on FileSystemException {
        // The map can still show what was just downloaded; the next sync
        // starts from the older cache and fetches these changes again.
      }
    }
    return Ok(_toDomain(snapshot));
  }

  Future<Map<int, MerchantModel>> _loadSnapshot() async =>
      _snapshot ??= {for (final place in await _cache.read()) place.id: place};

  /// A cache that cannot be read is rebuilt by a full sync rather than
  /// blocking the map forever.
  Future<Map<int, MerchantModel>> _snapshotOrEmpty() async {
    try {
      return await _loadSnapshot();
    } on FileSystemException {
      return _snapshot = {};
    } on FormatException {
      return _snapshot = {};
    }
  }

  static DateTime? _newestUpdate(Iterable<MerchantModel> places) {
    DateTime? newest;
    for (final place in places) {
      final updatedAt = place.updatedAt;
      if (updatedAt != null && (newest == null || updatedAt.isAfter(newest))) {
        newest = updatedAt;
      }
    }
    return newest;
  }

  static List<Merchant> _toDomain(Map<int, MerchantModel> snapshot) => [
    for (final place in snapshot.values) ?place.toDomain(),
  ];
}
