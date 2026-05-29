import 'dart:convert';

import 'package:bb_mobile/features/send/domain/lnurl_pay_limits.dart';
import 'package:bech32/bech32.dart';

typedef LnurlPayMetadataFetcher = Future<String> Function(Uri uri);

class ResolveLnurlPayLimitsUsecase {
  ResolveLnurlPayLimitsUsecase({required LnurlPayMetadataFetcher fetcher})
    : _fetcher = fetcher;

  final LnurlPayMetadataFetcher _fetcher;

  Future<LnurlPayLimits> execute(String lnurlOrAddress) async {
    final trimmed = lnurlOrAddress.trim();
    final metadataUri = _metadataUri(trimmed);
    final body = await _fetch(metadataUri);
    final Object? json;
    try {
      json = jsonDecode(body);
    } on FormatException catch (_) {
      throw const LnurlPayLimitsInvalidException('Invalid LNURL metadata');
    }
    if (json is! Map<String, dynamic>) {
      throw const LnurlPayLimitsInvalidException('Invalid LNURL metadata');
    }

    final tag = json['tag'];
    final minSendable = json['minSendable'];
    final maxSendable = json['maxSendable'];

    if (tag != 'payRequest' ||
        minSendable is! int ||
        maxSendable is! int ||
        minSendable < 0 ||
        maxSendable < 0) {
      throw const LnurlPayLimitsInvalidException(
        'Unsupported LNURL payment request',
      );
    }

    return LnurlPayLimits.fromMsats(
      minSendableMsat: minSendable,
      maxSendableMsat: maxSendable,
    );
  }

  Future<String> _fetch(Uri uri) async {
    try {
      return await _fetcher(uri);
    } on LnurlPayLimitsException {
      rethrow;
    } catch (_) {
      throw const LnurlPayLimitsUnavailableException();
    }
  }

  Uri _metadataUri(String value) {
    final lower = value.toLowerCase();
    if (lower.startsWith('lnurl')) {
      final decoded = _decodeLnurl(value);
      final uri = Uri.tryParse(decoded);
      if (uri == null || !_isHttpUri(uri)) {
        throw const LnurlPayLimitsInvalidException('Invalid LNURL');
      }
      return uri;
    }

    final at = value.indexOf('@');
    if (at > 0 && at < value.length - 1) {
      final username = value.substring(0, at);
      final domain = value.substring(at + 1);
      return Uri(
        scheme: 'https',
        host: domain,
        pathSegments: ['.well-known', 'lnurlp', username],
      );
    }

    throw const LnurlPayLimitsInvalidException('Invalid LNURL');
  }

  bool _isHttpUri(Uri uri) => uri.scheme == 'https' || uri.scheme == 'http';

  String _decodeLnurl(String value) {
    try {
      final decoded = bech32.decode(value, value.length);
      if (decoded.hrp != 'lnurl') {
        throw const LnurlPayLimitsInvalidException('Invalid LNURL');
      }
      return utf8.decode(_convertBits(decoded.data, from: 5, to: 8));
    } catch (_) {
      throw const LnurlPayLimitsInvalidException('Invalid LNURL');
    }
  }

  List<int> _convertBits(List<int> data, {required int from, required int to}) {
    var acc = 0;
    var bits = 0;
    final result = <int>[];
    final maxValue = (1 << to) - 1;

    for (final value in data) {
      if (value < 0 || (value >> from) != 0) {
        throw const LnurlPayLimitsInvalidException('Invalid LNURL');
      }
      acc = (acc << from) | value;
      bits += from;
      while (bits >= to) {
        bits -= to;
        result.add((acc >> bits) & maxValue);
      }
    }

    if (bits >= from || ((acc << (to - bits)) & maxValue) != 0) {
      throw const LnurlPayLimitsInvalidException('Invalid LNURL');
    }

    return result;
  }
}
