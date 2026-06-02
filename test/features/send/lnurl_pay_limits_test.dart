import 'dart:convert';

import 'package:bb_mobile/features/send/application/resolve_lnurl_pay_limits_usecase.dart';
import 'package:bb_mobile/features/send/domain/lnurl_pay_limits.dart';
import 'package:bech32/bech32.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const issueLnurl =
      'LNURL1DP68GURN8GHJ7CN5VDCXZ7FWD3JKYATWDDJHYTNVD9MX2T6Z23PJ742FF38925JV9ACXZ7F0V9C8QT63F3VHVUNGDPY9XJN0WPNH5A65VYMRVJP4DYM954M62QHHGETNWSKKUMEDD45KU6GP2SRC9';

  group('ResolveLnurlPayLimitsUsecase', () {
    test('resolves bech32 LNURL pay metadata', () async {
      Uri? requestedUri;
      final usecase = ResolveLnurlPayLimitsUsecase(
        fetcher: (uri) async {
          requestedUri = uri;
          return '{"callback":"https://example.com/callback","tag":"payRequest","minSendable":5000000,"maxSendable":612000000000}';
        },
      );

      final limits = await usecase.execute(issueLnurl);

      expect(
        requestedUri.toString(),
        'https://btcpay.lebunker.live/BTC/UILNURL/pay/app/QLYvrhhHSJopgzwTa66H5i6ZWzP/test-no-mini',
      );
      expect(limits.minSendableSat, 5000);
      expect(limits.maxSendableSat, 612000000);
    });

    test('resolves lightning address metadata URL', () async {
      Uri? requestedUri;
      final usecase = ResolveLnurlPayLimitsUsecase(
        fetcher: (uri) async {
          requestedUri = uri;
          return '{"callback":"https://example.com/callback","tag":"payRequest","minSendable":1000,"maxSendable":5000000}';
        },
      );

      final limits = await usecase.execute('alice@example.com');

      expect(
        requestedUri.toString(),
        'https://example.com/.well-known/lnurlp/alice',
      );
      expect(limits.minSendableSat, 1);
      expect(limits.maxSendableSat, 5000);
    });

    test('resolves lightning address usernames that start with lnurl', () async {
      Uri? requestedUri;
      final usecase = ResolveLnurlPayLimitsUsecase(
        fetcher: (uri) async {
          requestedUri = uri;
          return '{"callback":"https://example.com/callback","tag":"payRequest","minSendable":1000,"maxSendable":5000000}';
        },
      );

      await usecase.execute('lnurlpay@example.com');

      expect(
        requestedUri.toString(),
        'https://example.com/.well-known/lnurlp/lnurlpay',
      );
    });

    test('uses HTTP for onion lightning address metadata URLs', () async {
      Uri? requestedUri;
      final usecase = ResolveLnurlPayLimitsUsecase(
        fetcher: (uri) async {
          requestedUri = uri;
          return '{"callback":"http://exampleonionaddress.onion/callback","tag":"payRequest","minSendable":1000,"maxSendable":5000000}';
        },
      );

      await usecase.execute('alice@exampleonionaddress.onion');

      expect(
        requestedUri.toString(),
        'http://exampleonionaddress.onion/.well-known/lnurlp/alice',
      );
    });

    test('rejects clearnet HTTP LNURLs', () async {
      final usecase = ResolveLnurlPayLimitsUsecase(
        fetcher: (_) async {
          fail('fetcher should not be called for invalid LNURL');
        },
      );

      expect(
        usecase.execute(_lnurlFor('http://example.com/lnurlp/alice')),
        throwsA(isA<LnurlPayLimitsInvalidException>()),
      );
    });

    test('allows HTTP onion LNURLs', () async {
      Uri? requestedUri;
      final usecase = ResolveLnurlPayLimitsUsecase(
        fetcher: (uri) async {
          requestedUri = uri;
          return '{"callback":"http://exampleonionaddress.onion/callback","tag":"payRequest","minSendable":1000,"maxSendable":5000000}';
        },
      );

      await usecase.execute(
        _lnurlFor('http://exampleonionaddress.onion/lnurlp/alice'),
      );

      expect(
        requestedUri.toString(),
        'http://exampleonionaddress.onion/lnurlp/alice',
      );
    });

    test('rounds min msats up and max msats down', () async {
      final usecase = ResolveLnurlPayLimitsUsecase(
        fetcher: (_) async {
          return '{"callback":"https://example.com/callback","tag":"payRequest","minSendable":1001,"maxSendable":5999}';
        },
      );

      final limits = await usecase.execute('alice@example.com');

      expect(limits.minSendableSat, 2);
      expect(limits.maxSendableSat, 5);
    });

    test('rejects unsupported metadata', () async {
      final usecase = ResolveLnurlPayLimitsUsecase(
        fetcher: (_) async {
          return '{"tag":"withdrawRequest","minWithdrawable":1000,"maxWithdrawable":1000}';
        },
      );

      expect(
        usecase.execute('alice@example.com'),
        throwsA(isA<LnurlPayLimitsInvalidException>()),
      );
    });

    test('rejects metadata without a callback', () async {
      final usecase = ResolveLnurlPayLimitsUsecase(
        fetcher: (_) async {
          return '{"tag":"payRequest","minSendable":1000,"maxSendable":5000000}';
        },
      );

      expect(
        usecase.execute('alice@example.com'),
        throwsA(isA<LnurlPayLimitsInvalidException>()),
      );
    });

    test('rejects metadata with a clearnet HTTP callback', () async {
      final usecase = ResolveLnurlPayLimitsUsecase(
        fetcher: (_) async {
          return '{"callback":"http://example.com/callback","tag":"payRequest","minSendable":1000,"maxSendable":5000000}';
        },
      );

      expect(
        usecase.execute('alice@example.com'),
        throwsA(isA<LnurlPayLimitsInvalidException>()),
      );
    });

    test('rejects zero minSendable', () async {
      final usecase = ResolveLnurlPayLimitsUsecase(
        fetcher: (_) async {
          return '{"callback":"https://example.com/callback","tag":"payRequest","minSendable":0,"maxSendable":5000000}';
        },
      );

      expect(
        usecase.execute('alice@example.com'),
        throwsA(isA<LnurlPayLimitsInvalidException>()),
      );
    });

    test('rejects maxSendable lower than minSendable', () async {
      final usecase = ResolveLnurlPayLimitsUsecase(
        fetcher: (_) async {
          return '{"callback":"https://example.com/callback","tag":"payRequest","minSendable":5000000,"maxSendable":1000}';
        },
      );

      expect(
        usecase.execute('alice@example.com'),
        throwsA(isA<LnurlPayLimitsInvalidException>()),
      );
    });

    test('rejects ranges that cannot be represented in sats', () async {
      final usecase = ResolveLnurlPayLimitsUsecase(
        fetcher: (_) async {
          return '{"callback":"https://example.com/callback","tag":"payRequest","minSendable":1001,"maxSendable":1999}';
        },
      );

      expect(
        usecase.execute('alice@example.com'),
        throwsA(isA<LnurlPayLimitsInvalidException>()),
      );
    });

    test('maps transport failures to unavailable', () async {
      final usecase = ResolveLnurlPayLimitsUsecase(
        fetcher: (_) async => throw Exception('offline'),
      );

      expect(
        usecase.execute('alice@example.com'),
        throwsA(isA<LnurlPayLimitsUnavailableException>()),
      );
    });
  });
}

String _lnurlFor(String url) {
  return bech32.encode(
    Bech32('lnurl', _convertBits(utf8.encode(url), from: 8, to: 5, pad: true)),
    1024,
  );
}

List<int> _convertBits(
  List<int> data, {
  required int from,
  required int to,
  required bool pad,
}) {
  var acc = 0;
  var bits = 0;
  final result = <int>[];
  final maxValue = (1 << to) - 1;

  for (final value in data) {
    acc = (acc << from) | value;
    bits += from;
    while (bits >= to) {
      bits -= to;
      result.add((acc >> bits) & maxValue);
    }
  }

  if (pad && bits > 0) {
    result.add((acc << (to - bits)) & maxValue);
  }

  return result;
}
