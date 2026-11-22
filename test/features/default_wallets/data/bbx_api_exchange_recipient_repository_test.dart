import 'dart:convert';

import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/domain/entity/default_wallet.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_api_key_failure.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_recipient_repository.dart';
import 'package:bb_mobile/features/default_wallets/data/bbx_api_exchange_recipient_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../../exchange/data/bbx_api_test_http.dart';

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

(String?, WalletAddressType, String, bool) _fields(DefaultWallet? wallet) {
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

void main() {
  group('the requests are the ones the old repository sent, as recorded', () {
    final calls = <String, Future<void> Function(ExchangeRecipientRepository)>{
      'getDefaultWallets': (r) => r.getDefaultWallets(),
      'saveDefaultWallet, new': (r) => r.saveDefaultWallet(
        walletType: WalletAddressType.lightning,
        address: 'sat@example.com',
      ),
      'saveDefaultWallet, empty id': (r) => r.saveDefaultWallet(
        walletType: WalletAddressType.liquid,
        address: 'lq1address',
        existingRecipientId: '',
      ),
      'saveDefaultWallet, existing': (r) => r.saveDefaultWallet(
        walletType: WalletAddressType.bitcoin,
        address: 'bc1qaddress',
        existingRecipientId: 'btc',
      ),
      'deleteDefaultWallet': (r) => r.deleteDefaultWallet(
        recipientId: 'btc',
        walletType: WalletAddressType.bitcoin,
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
        walletType: WalletAddressType.bitcoin,
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

      final wallets = await _repository(FakeBbxHttp(body: body))
          .getDefaultWallets();

      expect(_fields(wallets.bitcoin), (
        'btc',
        WalletAddressType.bitcoin,
        'bc1qaddress',
        true,
      ));
      expect(_fields(wallets.lightning), (
        'ln',
        WalletAddressType.lightning,
        'sat@example.com',
        true,
      ));
      expect(_fields(wallets.liquid), (
        'lq',
        WalletAddressType.liquid,
        'lq1address',
        false,
      ));
    });

    test('no element list is no default wallet', () async {
      final wallets = await _repository(
        FakeBbxHttp(body: {'result': <String, Object?>{}}),
      ).getDefaultWallets();

      expect(wallets.bitcoin, isNull);
      expect(wallets.lightning, isNull);
      expect(wallets.liquid, isNull);
    });

    test(
      'an unknown type without an address is an empty Bitcoin wallet',
      () async {
        final wallet =
            await _repository(
              FakeBbxHttp(
                body: {
                  'result': {
                    'element': {
                      'recipientId': 'x',
                      'recipientType': 'OUT_OTHER',
                    },
                  },
                },
              ),
            ).saveDefaultWallet(
              walletType: WalletAddressType.bitcoin,
              address: 'a',
            );

        expect(_fields(wallet), ('x', WalletAddressType.bitcoin, '', false));
      },
    );
  });

  group('failures', () {
    test('a JSON-RPC error throws without its message', () async {
      await expectLater(
        _repository(FakeBbxHttp(body: _rpcError)).getDefaultWallets(),
        throwsA(
          isA<Exception>().having(
            (e) => '$e',
            'message',
            allOf(
              startsWith('Exception: Failed to get default wallets'),
              isNot(contains('bc1qsecret')),
            ),
          ),
        ),
      );
    });

    test('an invalid element throws', () async {
      await expectLater(
        _repository(
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
        throwsA(isA<Exception>()),
      );
    });

    test('a failed save and delete throw', () async {
      final repository = _repository(FakeBbxHttp(body: _rpcError));

      await expectLater(
        repository.saveDefaultWallet(
          walletType: WalletAddressType.bitcoin,
          address: 'bc1q',
        ),
        throwsA(
          isA<Exception>().having(
            (e) => '$e',
            'message',
            startsWith('Exception: Failed to save default wallet'),
          ),
        ),
      );
      await expectLater(
        repository.deleteDefaultWallet(
          recipientId: 'btc',
          walletType: WalletAddressType.bitcoin,
          address: 'bc1q',
        ),
        throwsA(
          isA<Exception>().having(
            (e) => '$e',
            'message',
            startsWith('Exception: Failed to delete default wallet'),
          ),
        ),
      );
    });

    test('no credential is a missing API key', () async {
      final http = FakeBbxHttp();
      final repository = BbxApiExchangeRecipientRepository(
        api: http.client(readApiKey: () async => const Ok(null)),
      );

      await expectLater(
        repository.getDefaultWallets(),
        throwsA(isA<ApiKeyNotFoundException>()),
      );
      expect(http.requests, isEmpty);
    });

    test('an unreadable credential is unavailable', () async {
      final repository = BbxApiExchangeRecipientRepository(
        api: FakeBbxHttp().client(
          readApiKey: () async => const Err(ExchangeApiKeyReadFailure()),
        ),
      );

      await expectLater(
        repository.saveDefaultWallet(
          walletType: WalletAddressType.bitcoin,
          address: 'bc1q',
        ),
        throwsA(isA<ExchangeCredentialUnavailableException>()),
      );
    });
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
