import 'dart:convert';

import 'package:bb_mobile/core/mempool/application/usecases/get_active_mempool_server_usecase.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_birthday_checkpoint_response_model.dart';
import 'package:dio/dio.dart';

/// Wraps the single external system this datasource talks to: whichever
/// mempool server is currently active for a network (custom or default —
/// resolved the same way `FeesDatasource` resolves its own base URL, see
/// `core/fees/data/fees_datasource.dart`).
///
/// Bitcoin-only: always resolves the active server with `isLiquid: false`.
/// A compact-block-filter birthday checkpoint has no Liquid equivalent.
class WalletBirthdayCheckpointDatasource {
  static const _timeout = Duration(seconds: 5);

  final GetActiveMempoolServerUsecase _getActiveMempoolServerUsecase;

  /// Builds the HTTP client for a resolved base URL. Injected so tests can
  /// supply a mock; defaults to a real Dio. The base URL is only known at
  /// call time (custom server vs default, mainnet vs testnet), so this is a
  /// builder rather than a pre-built client — mirrors `FeesDatasource`.
  final Dio Function(String baseUrl) _dioBuilder;

  WalletBirthdayCheckpointDatasource({
    required this._getActiveMempoolServerUsecase,
    Dio Function(String baseUrl)? dioBuilder,
  }) : _dioBuilder = dioBuilder ?? _defaultDioBuilder;

  static Dio _defaultDioBuilder(String baseUrl) => Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: _timeout,
      receiveTimeout: _timeout,
      sendTimeout: _timeout,
    ),
  );

  /// GETs `/api/v1/mining/blocks/timestamp/:unixSeconds` from the active
  /// mempool server for [isTestnet].
  ///
  /// Throws [DioException] on a transport/HTTP error, [FormatException] on
  /// a malformed body, or a plain [Exception] if no active mempool server
  /// could be resolved at all. Never retries — that bounded policy belongs
  /// to `WalletBirthdayCheckpointRepositoryImpl`, which is the layer that
  /// knows how many attempts remain.
  Future<WalletBirthdayCheckpointResponseModel> fetchBlockAtOrBeforeTimestamp({
    required bool isTestnet,
    required int unixSeconds,
  }) async {
    final server =
        (await _getActiveMempoolServerUsecase.execute(
          isTestnet: isTestnet,
          isLiquid: false,
        )).fold(
          (server) => server,
          (_) => throw Exception('Failed to fetch active mempool server'),
        );

    final http = _dioBuilder(server.fullUrl);
    final response = await http.get<dynamic>(
      '/api/v1/mining/blocks/timestamp/$unixSeconds',
    );

    var data = response.data;
    // Mirrors FeesDatasource: a working-but-misconfigured self-hosted
    // mempool can return the body as text/plain, so Dio leaves it undecoded
    // as a String.
    if (data is String && data.isNotEmpty) {
      data = jsonDecode(data);
    }
    if (data is! Map<String, dynamic>) {
      throw FormatException('Non-object mempool response body', data);
    }

    return WalletBirthdayCheckpointResponseModel.fromJson(data);
  }
}
