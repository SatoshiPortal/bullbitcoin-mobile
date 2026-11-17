import 'dart:io';

import 'package:btc_map/src/data/datasources/btc_map_api_datasource.dart';
import 'package:btc_map/src/data/datasources/merchant_cache_datasource.dart';
import 'package:btc_map/src/data/merchant_repository_impl.dart';
import 'package:btc_map/src/domain/bull_map_failure.dart';
import 'package:btc_map/src/domain/entities/merchant.dart';
import 'package:btc_map/src/domain/merchant_repository.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// Entry point of the package: where the cache lives, and a session per open
/// map.
abstract final class BullMap {
  static Directory? _cacheDirectory;

  static void init({required String cacheDirectory}) =>
      _cacheDirectory = Directory(cacheDirectory);

  /// A session for one open map. Its merchants live in memory as long as it
  /// does, so a screen opens one and drops it when it closes.
  static BullMapSession open() {
    final directory = _cacheDirectory;
    if (directory == null) throw StateError('BullMap.init was not called');
    return BullMapSession._(
      MerchantRepositoryImpl(
        BtcMapApiDatasource(),
        MerchantCacheDatasource(directory),
      ),
    );
  }
}

/// The merchants of one open map.
final class BullMapSession {
  final MerchantRepository _repository;

  BullMapSession._(this._repository);

  /// The merchants stored on the device, without touching the network. Empty
  /// before the first successful sync.
  @useResult
  Future<Result<List<Merchant>, BullMapFailure>> cachedMerchants() =>
      _repository.cached();

  /// Brings the device copy up to date with BTC Map and returns all of it.
  /// Concurrent calls share one download.
  @useResult
  Future<Result<List<Merchant>, BullMapFailure>> syncMerchants() =>
      _repository.sync();
}
