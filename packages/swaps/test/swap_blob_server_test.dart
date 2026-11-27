import 'dart:convert';

import 'package:flutter_test/flutter_test.dart' show TestWidgetsFlutterBinding;
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show NetworkEnv;
import 'package:swaps/src/data/boltz_api.dart';
import 'package:swaps/src/data/swap_storage.dart';
import 'package:swaps/swaps.dart' show SwapServerCredentials;
import 'package:test/test.dart';

import 'support/real_swap_backends.dart';

class _MockRowStore extends Mock implements SwapRowStore {}

String _blob(String boltzUrl) =>
    jsonEncode({'id': 'swap', 'out_amount': 50000, 'boltz_url': boltzUrl});

String? _address(String blob) =>
    (jsonDecode(blob) as Map<String, dynamic>)['boltz_url'] as String?;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const current = 'https://bull:new@boltz.example.com/v2';

  test('a swap created without credentials uses the current ones', () {
    final blob = swapBlobOnServer(
      _blob('https://boltz.example.com/v2'),
      current: current,
    );

    expect(_address(blob), current);
    expect((jsonDecode(blob) as Map<String, dynamic>)['out_amount'], 50000);
  });

  test('a swap created with old credentials uses the current ones', () {
    expect(
      _address(
        swapBlobOnServer(
          _blob('https://bull:old@boltz.example.com/v2'),
          current: current,
        ),
      ),
      current,
    );
  });

  test('removed credentials are removed from the swap too', () {
    expect(
      _address(
        swapBlobOnServer(
          _blob('https://bull:old@boltz.example.com/v2'),
          current: 'https://boltz.example.com/v2',
        ),
      ),
      'https://boltz.example.com/v2',
    );
  });

  test('a swap on another server keeps its own address', () {
    for (final stored in [
      'https://other.example.com/v2',
      'https://bull:old@other.example.com/v2',
      'https://boltz.example.com:8443/v2',
      'http://boltz.example.com/v2',
      'https://boltz.example.com/api/v2',
    ]) {
      final blob = _blob(stored);
      expect(swapBlobOnServer(blob, current: current), blob);
    }
  });

  test('a blob that is not a swap is left as it is', () {
    for (final blob in ['not json', '[]', '{"id":"swap"}']) {
      expect(swapBlobOnServer(blob, current: current), blob);
    }
  });

  test('the engine points stored swaps at its own server', () {
    final storage = SwapStorage(
      rows: _MockRowStore(),
      secrets: ReproKeychainBackend().capability,
    );
    final boltz = BoltzDatasource(
      environment: NetworkEnv.mainnet,
      url: 'boltz.example.com/v2',
      credentials: const SwapServerCredentials(
        username: 'bull',
        password: 'new',
      ),
      boltzStore: storage,
    );
    addTearDown(boltz.dispose);

    expect(
      _address(storage.blobOnLoad(_blob('https://boltz.example.com/v2'))),
      current,
    );
    expect(
      _address(storage.blobOnLoad(_blob('https://other.example.com/v2'))),
      'https://other.example.com/v2',
    );
  });
}
