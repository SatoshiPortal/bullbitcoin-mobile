import 'dart:convert';

import 'package:bbx_api/bbx_api.dart' show BbxCredentialUnavailableFailure;
import 'package:exchange/exchange.dart';
import 'package:exchange/src/data/bbx_api_exchange_recipient_repository.dart';
import 'package:dio/dio.dart' show DioExceptionType;
import 'package:test/test.dart';
import 'package:primitives/primitives.dart';

import 'bbx_api_test_http.dart';

const _bitcoin = {
  'recipientId': 'btc',
  'userId': 'u-1',
  'recipientType': 'OUT_BITCOIN_ADDRESS',
  'address': 'bc1qaddress',
  'isOwner': true,
  'isDefault': true,
};

const _lightning = {
  'recipientId': 'ln',
  'recipientType': 'OUT_LIGHTNING_ADDRESS',
  'lightningAddress': 'sat@example.com',
  'isDefault': true,
};

const _liquid = {
  'recipientId': 'lq',
  'recipientType': 'OUT_LIQUID_ADDRESS',
  'liquidAddress': 'lq1address',
};

const _rpcError = {
  'error': {'code': -32602, 'message': 'invalid address bc1qsecret'},
};

BbxApiExchangeRecipientRepository _repository(FakeBbxHttp http) =>
    BbxApiExchangeRecipientRepository(api: http.client());

List<(String, String, Object?)> _sent(FakeBbxHttp http) => [
  for (final r in http.requests)
    (r.path, jsonEncode(r.data), r.headers['x-api-version']),
];

(String?, BtcNetwork, String, bool) _fields(DefaultWallet? wallet) {
  if (wallet == null) {
    fail('Expected a default wallet');
  }
  return (
    wallet.recipientId,
    wallet.walletType,
    wallet.address,
    wallet.isDefault,
  );
}

T _value<T>(Result<T, ExchangeFailure> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => fail('Expected success, got ${failure.runtimeType}'),
};

T _written<T>(ExchangeWrite<T> write) => switch (write) {
  WriteDone(:final value) => value,
  _ => fail('Expected a done write, got ${write.runtimeType}'),
};

Matcher _failure<T>(Matcher matcher) => isA<Err<T, ExchangeFailure>>().having(
  (result) => result.failure,
  'failure',
  matcher,
);

void main() {
  group('the requests are the ones the old repository sent, as recorded', () {
    final calls =
        <String, Future<void> Function(BbxApiExchangeRecipientRepository)>{
          'getDefaultWallets': (r) => r.getDefaultWallets(),
          'saveDefaultWallet, new': (r) => r.saveDefaultWallet(
            walletType: BtcNetwork.lightning,
            address: 'sat@example.com',
          ),
          'saveDefaultWallet, empty id': (r) => r.saveDefaultWallet(
            walletType: BtcNetwork.liquid,
            address: 'lq1address',
            existingRecipientId: '',
          ),
          'saveDefaultWallet, existing': (r) => r.saveDefaultWallet(
            walletType: BtcNetwork.bitcoin,
            address: 'bc1qaddress',
            existingRecipientId: 'btc',
          ),
          'deleteDefaultWallet': (r) => r.deleteDefaultWallet(
            recipientId: 'btc',
            walletType: BtcNetwork.bitcoin,
            address: 'bc1qaddress',
          ),
        };
    for (final MapEntry(key: name, value: call) in calls.entries) {
      test(name, () async {
        final body = {
          'result': {
            'element': _bitcoin,
            'elements': [_bitcoin],
          },
        };
        final http = FakeBbxHttp(body: body);

        await call(_repository(http));

        expect(_sent(http), _oldSent[name]);
        expect(_sent(http).single.$3, isNull);
      });
    }

    test('getDefaultWallets asks for the default address recipients', () async {
      final http = FakeBbxHttp(body: {'result': <String, Object?>{}});

      await _repository(http).getDefaultWallets();

      expect(
        _sent(http).single.$2,
        '{"jsonrpc":"2.0","id":"0","method":"listMyRecipients","params":'
        '{"filters":{"recipientTypes":["OUT_BITCOIN_ADDRESS",'
        '"OUT_LIGHTNING_ADDRESS","OUT_LIQUID_ADDRESS"],"isDefault":true}}}',
      );
    });

    test('saveDefaultWallet updates an existing recipient', () async {
      final http = FakeBbxHttp(
        body: {
          'result': {'element': _bitcoin},
        },
      );

      await _repository(http).saveDefaultWallet(
        walletType: BtcNetwork.bitcoin,
        address: 'bc1qaddress',
        existingRecipientId: 'btc',
      );

      expect(
        _sent(http).single.$2,
        '{"jsonrpc":"2.0","id":"0","method":"updateMyRecipient","params":'
        '{"element":{"recipientId":"btc","recipientType":"OUT_BITCOIN_ADDRESS",'
        '"isOwner":true,"address":"bc1qaddress","isDefault":true}}}',
      );
    });
  });

  group('mapping', () {
    test('reads each wallet from the field of its type', () async {
      final body = {
        'result': {
          'elements': [_bitcoin, _lightning, _liquid],
        },
      };

      final wallets = _value(
        await _repository(FakeBbxHttp(body: body)).getDefaultWallets(),
      );

      expect(_fields(wallets.bitcoin), (
        'btc',
        BtcNetwork.bitcoin,
        'bc1qaddress',
        true,
      ));
      expect(_fields(wallets.lightning), (
        'ln',
        BtcNetwork.lightning,
        'sat@example.com',
        true,
      ));
      expect(_fields(wallets.liquid), (
        'lq',
        BtcNetwork.liquid,
        'lq1address',
        false,
      ));
    });

    test('a listed recipient of an unknown type is skipped, not read as '
        'Bitcoin', () async {
      final wallets = _value(
        await _repository(
          FakeBbxHttp(
            body: {
              'result': {
                'elements': [
                  {
                    'recipientId': 'x',
                    'recipientType': 'OUT_OTHER',
                    'address': 'other',
                    'isDefault': true,
                  },
                  _liquid,
                ],
              },
            },
          ),
        ).getDefaultWallets(),
      );

      expect(wallets.bitcoin, isNull);
      expect(wallets.lightning, isNull);
      expect(wallets.liquid?.address, 'lq1address');
    });

    test('no element list is no default wallet', () async {
      final wallets = _value(
        await _repository(FakeBbxHttp(body: {'result': <String, Object?>{}}))
            .getDefaultWallets(),
      );

      expect(wallets.bitcoin, isNull);
      expect(wallets.lightning, isNull);
      expect(wallets.liquid, isNull);
    });

    test(
      'a saved wallet keeps the rail it was saved on, whatever type comes back',
      () async {
        final wallet = await _repository(
          FakeBbxHttp(
            body: {
              'result': {
                'element': {'recipientId': 'x', 'recipientType': 'OUT_OTHER'},
              },
            },
          ),
        ).saveDefaultWallet(walletType: BtcNetwork.liquid, address: 'a');

        expect(_fields(_written(wallet)), ('x', BtcNetwork.liquid, '', false));
      },
    );
  });

  group('failures', () {
    test('a JSON-RPC error retains its code but not its message', () async {
      expect(
        await _repository(FakeBbxHttp(body: _rpcError)).getDefaultWallets(),
        _failure<DefaultWallets>(
          isA<ExchangeUnexpectedFailure>().having(
            (failure) => failure.logMessage,
            'log message',
            allOf(contains('-32602'), isNot(contains('bc1qsecret'))),
          ),
        ),
      );
    });

    test('an invalid element is a typed failure', () async {
      expect(
        await _repository(
          FakeBbxHttp(
            body: {
              'result': {
                'elements': [
                  {'recipientId': 1},
                ],
              },
            },
          ),
        ).getDefaultWallets(),
        _failure<DefaultWallets>(isA<ExchangeUnexpectedFailure>()),
      );
    });

    test('a failed save and delete return a typed failure', () async {
      final repository = _repository(FakeBbxHttp(body: _rpcError));

      expect(
        await repository.saveDefaultWallet(
          walletType: BtcNetwork.bitcoin,
          address: 'bc1q',
        ),
        isA<WriteRefused<DefaultWallet>>(),
      );
      expect(
        await repository.deleteDefaultWallet(
          recipientId: 'btc',
          walletType: BtcNetwork.bitcoin,
          address: 'bc1q',
        ),
        _failure<void>(isA<ExchangeUnexpectedFailure>()),
      );
    });

    test('no credential is a missing API key', () async {
      final http = FakeBbxHttp();
      final repository = BbxApiExchangeRecipientRepository(
        api: http.client(readApiKey: () async => const Ok(null)),
      );

      expect(
        await repository.getDefaultWallets(),
        _failure<DefaultWallets>(isA<ExchangeNotAuthenticatedFailure>()),
      );
      expect(http.requests, isEmpty);
    });

    test('an unreadable credential is unavailable', () async {
      final repository = BbxApiExchangeRecipientRepository(
        api: FakeBbxHttp().client(
          readApiKey: () async => const Err(BbxCredentialUnavailableFailure()),
        ),
      );

      expect(
        await repository.saveDefaultWallet(
          walletType: BtcNetwork.bitcoin,
          address: 'bc1q',
        ),
        isA<WriteNotSent<DefaultWallet>>().having(
          (w) => w.reason,
          'reason',
          ExchangeNotSentReason.credentialUnavailable,
        ),
      );
    });

    for (final (name, http) in [
      (
        'a timeout after sending',
        FakeBbxHttp(error: DioExceptionType.receiveTimeout),
      ),
      ('a gateway timeout', FakeBbxHttp(status: 504, body: const {})),
      ('an unreadable reply', FakeBbxHttp(body: {'result': 'x'})),
    ]) {
      test('$name on a save is an unknown outcome (DW-2)', () async {
        expect(
          await _repository(
            http,
          ).saveDefaultWallet(walletType: BtcNetwork.bitcoin, address: 'bc1q'),
          isA<WriteOutcomeUnknown<DefaultWallet>>(),
        );
      });
    }
  });
}

/// What the removed ExchangeRecipientRepositoryImpl sent: path, JSON text
/// and `x-api-version`.
const _oldSent = <String, List<(String, String, Object?)>>{
  'getDefaultWallets': [
    (
      '/ak/api-recipients',
      '{"jsonrpc":"2.0","id":"0","method":"listMyRecipients","params":{"filters":{"recipientTypes":["OUT_BITCOIN_ADDRESS","OUT_LIGHTNING_ADDRESS","OUT_LIQUID_ADDRESS"],"isDefault":true}}}',
      null,
    ),
  ],
  'saveDefaultWallet, new': [
    (
      '/ak/api-recipients',
      '{"jsonrpc":"2.0","id":"0","method":"createMyRecipient","params":{"element":{"recipientType":"OUT_LIGHTNING_ADDRESS","isOwner":true,"isDefault":true,"address":"sat@example.com"}}}',
      null,
    ),
  ],
  'saveDefaultWallet, empty id': [
    (
      '/ak/api-recipients',
      '{"jsonrpc":"2.0","id":"0","method":"createMyRecipient","params":{"element":{"recipientType":"OUT_LIQUID_ADDRESS","isOwner":true,"isDefault":true,"address":"lq1address"}}}',
      null,
    ),
  ],
  'saveDefaultWallet, existing': [
    (
      '/ak/api-recipients',
      '{"jsonrpc":"2.0","id":"0","method":"updateMyRecipient","params":{"element":{"recipientId":"btc","recipientType":"OUT_BITCOIN_ADDRESS","isOwner":true,"address":"bc1qaddress","isDefault":true}}}',
      null,
    ),
  ],
  'deleteDefaultWallet': [
    (
      '/ak/api-recipients',
      '{"jsonrpc":"2.0","id":"0","method":"updateMyRecipient","params":{"element":{"recipientId":"btc","recipientType":"OUT_BITCOIN_ADDRESS","isOwner":true,"address":"bc1qaddress","isDefault":false}}}',
      null,
    ),
  ],
};
