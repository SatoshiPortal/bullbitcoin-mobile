import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/tor/data/datasources/tor_datasource.dart';
import 'package:bb_mobile/core/tor/domain/value_objects/tor_proxy_config.dart';
import 'package:bb_mobile/features/send/application/application_errors.dart';
import 'package:bb_mobile/features/send/application/lnurl_pay_metadata_repository.dart';

class LnurlPayMetadataDatasource implements LnurlPayMetadataRepository {
  LnurlPayMetadataDatasource({
    required GetSettingsUsecase getSettingsUsecase,
    required TorDatasource torDatasource,
  }) : _getSettingsUsecase = getSettingsUsecase,
       _torDatasource = torDatasource;

  static const _fetchTimeout = Duration(seconds: 15);
  static const _maxResponseBytes = 256 * 1024;

  final GetSettingsUsecase _getSettingsUsecase;
  final TorDatasource _torDatasource;

  @override
  Future<String> fetch(Uri uri) {
    return _fetch(uri).timeout(
      _fetchTimeout,
      onTimeout: () =>
          throw const LnurlPayLimitsUnavailableApplicationException(),
    );
  }

  Future<String> _fetch(Uri uri) async {
    final settings = await _getSettingsUsecase.execute();
    final client = settings.useTorProxy
        ? _torDatasource.httpClient(
            externalProxy: TorProxyConfig(port: settings.torProxyPort),
          )
        : HttpClient();

    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      final body = await _readLimitedUtf8(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const LnurlPayLimitsUnavailableApplicationException();
      }
      return body;
    } on LnurlPayLimitsApplicationException {
      rethrow;
    } on FormatException {
      throw const LnurlPayLimitsUnavailableApplicationException();
    } on IOException {
      throw const LnurlPayLimitsUnavailableApplicationException();
    } finally {
      client.close(force: true);
    }
  }

  Future<String> _readLimitedUtf8(Stream<List<int>> response) async {
    final bytes = <int>[];
    await for (final chunk in response) {
      if (bytes.length + chunk.length > _maxResponseBytes) {
        throw const LnurlPayLimitsUnavailableApplicationException();
      }
      bytes.addAll(chunk);
    }
    return utf8.decode(bytes);
  }
}
