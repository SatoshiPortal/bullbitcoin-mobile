import 'dart:convert';

import 'package:bb_mobile/features/send/application/application_errors.dart';
import 'package:bb_mobile/features/send/application/lnurl_pay_metadata_repository.dart';
import 'package:bb_mobile/features/send/domain/lnurl_pay_limits.dart';
import 'package:bech32/bech32.dart';

class ResolveLnurlPayLimitsUsecase {
  ResolveLnurlPayLimitsUsecase({
    required LnurlPayMetadataRepository metadataRepository,
  }) : _metadataRepository = metadataRepository;

  final LnurlPayMetadataRepository _metadataRepository;

  Future<LnurlPayLimits> execute(String lnurlOrAddress) async {
    final trimmed = lnurlOrAddress.trim();
    final metadataUri = _metadataUri(trimmed);
    final body = await _fetch(metadataUri);
    final Object? json;
    try {
      json = jsonDecode(body);
    } on FormatException catch (_) {
      throw const LnurlPayLimitsInvalidApplicationException();
    }
    if (json is! Map<String, dynamic>) {
      throw const LnurlPayLimitsInvalidApplicationException();
    }

    final tag = json['tag'];
    final callback = json['callback'];
    final minSendable = json['minSendable'];
    final maxSendable = json['maxSendable'];

    if (tag != 'payRequest' ||
        callback is! String ||
        !_isAllowedCallback(callback) ||
        minSendable is! int ||
        maxSendable is! int ||
        minSendable < 1 ||
        maxSendable < minSendable) {
      throw const LnurlPayLimitsInvalidApplicationException();
    }

    try {
      return LnurlPayLimits.fromMsats(
        minSendableMsat: minSendable,
        maxSendableMsat: maxSendable,
      );
    } on LnurlPayLimitsException {
      throw const LnurlPayLimitsInvalidApplicationException();
    }
  }

  Future<String> _fetch(Uri uri) async {
    try {
      return await _metadataRepository.fetch(uri);
    } on LnurlPayLimitsApplicationException {
      rethrow;
    } catch (_) {
      throw const LnurlPayLimitsUnavailableApplicationException();
    }
  }

  Uri _metadataUri(String value) {
    final at = value.indexOf('@');
    if (at > 0 && at < value.length - 1) {
      final username = value.substring(0, at);
      final domain = value.substring(at + 1);
      return Uri(
        scheme: _isOnionHost(domain) ? 'http' : 'https',
        host: domain,
        pathSegments: ['.well-known', 'lnurlp', username],
      );
    }

    final lower = value.toLowerCase();
    if (lower.startsWith('lnurl')) {
      final decoded = _decodeLnurl(value);
      final uri = Uri.tryParse(decoded);
      if (uri == null || !_isAllowedLnurlUri(uri)) {
        throw const LnurlPayLimitsInvalidApplicationException();
      }
      return uri;
    }

    throw const LnurlPayLimitsInvalidApplicationException();
  }

  bool _isAllowedCallback(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && _isAllowedLnurlUri(uri);
  }

  bool _isAllowedLnurlUri(Uri uri) {
    if (uri.host.isEmpty) return false;
    if (uri.scheme == 'https') return true;
    return uri.scheme == 'http' && _isOnionHost(uri.host);
  }

  bool _isOnionHost(String host) => host.toLowerCase().endsWith('.onion');

  String _decodeLnurl(String value) {
    try {
      final decoded = bech32.decode(value, value.length);
      if (decoded.hrp != 'lnurl') {
        throw const LnurlPayLimitsInvalidApplicationException();
      }
      return utf8.decode(_convertBits(decoded.data, from: 5, to: 8));
    } catch (_) {
      throw const LnurlPayLimitsInvalidApplicationException();
    }
  }

  List<int> _convertBits(List<int> data, {required int from, required int to}) {
    var acc = 0;
    var bits = 0;
    final result = <int>[];
    final maxValue = (1 << to) - 1;

    for (final value in data) {
      if (value < 0 || (value >> from) != 0) {
        throw const LnurlPayLimitsInvalidApplicationException();
      }
      acc = (acc << from) | value;
      bits += from;
      while (bits >= to) {
        bits -= to;
        result.add((acc >> bits) & maxValue);
      }
    }

    if (bits >= from || ((acc << (to - bits)) & maxValue) != 0) {
      throw const LnurlPayLimitsInvalidApplicationException();
    }

    return result;
  }
}
