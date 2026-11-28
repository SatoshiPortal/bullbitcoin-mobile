import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_recoverbull/src/data/android_passkey_credentials.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.bullbitcoin.mobile/recoverbull_passkey');
  const credentials = AndroidPasskeyCredentials('passkey.example.com');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('create returns public credential and a random 32-byte salt', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'create');
      return Uint8List.fromList([1, 2, 3]);
    });
    final result = await credentials.create();
    final passkey = (result as Ok<VaultPasskey, RecoverBullFailure>).value;
    expect(passkey.credentialId, [1, 2, 3]);
    expect(passkey.prfSalt, hasLength(32));
    expect(passkey.rpId, 'passkey.example.com');
  });

  test('get passes only the exact ID and salt to native code', () async {
    final passkey = VaultPasskey(
      rpId: 'passkey.example.com',
      credentialId: [1, 2, 3],
      prfSalt: List.filled(32, 4),
    );
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'get');
      final args = call.arguments as Map<Object?, Object?>;
      expect(args.keys.toSet(), {'credentialId', 'salt'});
      expect(args['credentialId'], [1, 2, 3]);
      expect(args['salt'], List.filled(32, 4));
      return Uint8List(32);
    });
    final result = await credentials.get(passkey);
    final prf = (result as Ok<Uint8List, RecoverBullFailure>).value;
    prf.fillRange(0, prf.length, 0);
    expect(prf, everyElement(0));
  });

  test(
    'get returns an erasable PRF when the channel response is read-only',
    () async {
      final passkey = VaultPasskey(
        rpId: 'passkey.example.com',
        credentialId: [1],
        prfSalt: List.filled(32, 4),
      );
      messenger.setMockMessageHandler(channel.name, (_) async {
        return const StandardMethodCodec()
            .encodeSuccessEnvelope(Uint8List.fromList(List.filled(32, 7)))
            .asUnmodifiableView();
      });
      final result = await credentials.get(passkey);
      final prf = (result as Ok<Uint8List, RecoverBullFailure>).value;
      prf.fillRange(0, prf.length, 0);
      expect(prf, everyElement(0));
    },
  );

  test(
    'rejects a vault with a different RP before invoking native code',
    () async {
      messenger.setMockMethodCallHandler(channel, (_) async {
        fail('must not invoke native code');
      });
      final result = await credentials.get(
        VaultPasskey(
          rpId: 'other.example.com',
          credentialId: [1],
          prfSalt: List.filled(32, 4),
        ),
      );
      expect(result, isA<Err<Uint8List, RecoverBullFailure>>());
    },
  );

  test('missing PRF and cancellation are explicit failures', () async {
    final passkey = VaultPasskey(
      rpId: 'passkey.example.com',
      credentialId: [1],
      prfSalt: List.filled(32, 4),
    );
    messenger.setMockMethodCallHandler(channel, (_) async => Uint8List(31));
    final missing = await credentials.get(passkey);
    expect(
      (missing as Err<Uint8List, RecoverBullFailure>).failure,
      isA<VaultPasskeyUnavailableFailure>(),
    );
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'cancelled');
    });
    final cancelled = await credentials.get(passkey);
    expect(
      (cancelled as Err<Uint8List, RecoverBullFailure>).failure,
      isA<VaultCancelledFailure>(),
    );
  });
}
