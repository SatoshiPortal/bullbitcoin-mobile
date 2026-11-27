import 'dart:async';
import 'dart:convert';

import 'package:bull_recoverbull/src/data/passkey_demo_repository_impl.dart';
import 'package:bull_recoverbull/src/domain/passkey_demo_operation.dart';
import 'package:bull_recoverbull/src/domain/repositories/passkey_demo_repository.dart';
import 'package:bull_recoverbull/src/domain/usecases/run_passkey_demo_usecase.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:primitives/primitives.dart';

final class _Repository implements PasskeyDemoRepository {
  int registrations = 0;
  String? openedAccount;
  void Function()? duringOpen;

  @override
  Future<Result<String, PasskeyDemoFailure>> register(
    PasskeyDemoOperation operation,
  ) async {
    registrations++;
    return const Ok('test-account');
  }

  @override
  Future<Result<String, PasskeyDemoFailure>> open(
    String accountId,
    PasskeyDemoOperation operation,
  ) async {
    openedAccount = accountId;
    duringOpen?.call();
    return const Ok('sample data');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(
    'com.bullbitcoin.mobile/recoverbull_passkey_demo',
  );
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'redirect responses do not trigger another request or native call',
    () async {
      for (var status = 300; status < 400; status++) {
        var requests = 0;
        var nativeCalls = 0;
        messenger.setMockMethodCallHandler(channel, (_) async {
          nativeCalls++;
          return null;
        });
        final client = MockClient((request) async {
          requests++;
          expect(
            request.url.toString(),
            'http://127.0.0.1:8443/register/options',
          );
          expect(request.followRedirects, isFalse);
          return http.Response(
            '',
            status,
            headers: {'location': 'http://example.com'},
          );
        });
        final demo = RunPasskeyDemoUsecase(
          () async => true,
          PasskeyDemoRepositoryImpl(clientFactory: () => client),
        );
        expect(await demo.execute(), isA<Err<String, PasskeyDemoFailure>>());
        expect(requests, 1);
        expect(nativeCalls, 0);
      }
    },
  );

  test('authentication accepts only the exact dummy marker', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => '{}');
    for (final content in [
      'Dummy RecoverBull content: no wallet, secret, or backup.',
      'untrusted server content',
    ]) {
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/options')) {
          return http.Response(
            jsonEncode({'sessionId': 'session', 'options': <String, Object>{}}),
            200,
          );
        }
        return http.Response(jsonEncode({'content': content}), 200);
      });
      final demo = RunPasskeyDemoUsecase(
        () async => true,
        PasskeyDemoRepositoryImpl(clientFactory: () => client),
      );
      final result = await demo.execute(accountId: 'account');
      if (content.startsWith('Dummy')) {
        expect(result, isA<Ok<String, PasskeyDemoFailure>>());
      } else {
        expect(result, isA<Err<String, PasskeyDemoFailure>>());
      }
    }
  });

  test('both settings are required', () async {
    for (final superuser in [false, true]) {
      for (final devMode in [false, true]) {
        final repository = _Repository();
        final demo = RunPasskeyDemoUsecase(
          () async => superuser && devMode,
          repository,
        );
        await demo.execute();
        expect(repository.registrations, superuser && devMode ? 1 : 0);
      }
    }
  });

  test('disabling after options prevents native invocation', () async {
    var enabled = true;
    var nativeCalls = 0;
    messenger.setMockMethodCallHandler(channel, (_) async {
      nativeCalls++;
      return null;
    });
    final client = MockClient((request) async {
      enabled = false;
      return http.Response(
        jsonEncode({'sessionId': 'session', 'options': <String, Object>{}}),
        200,
      );
    });
    final repository = PasskeyDemoRepositoryImpl(clientFactory: () => client);
    final demo = RunPasskeyDemoUsecase(() async => enabled, repository);
    final result = await demo.execute();
    expect(result, isA<Err<String, PasskeyDemoFailure>>());
    expect(nativeCalls, 0);
  });

  test('disabling during native response prevents verify', () async {
    var enabled = true;
    final paths = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      enabled = false;
      return '{}';
    });
    final client = MockClient((request) async {
      paths.add(request.url.path);
      return http.Response(
        jsonEncode({'sessionId': 'session', 'options': <String, Object>{}}),
        200,
      );
    });
    final repository = PasskeyDemoRepositoryImpl(clientFactory: () => client);
    final demo = RunPasskeyDemoUsecase(() async => enabled, repository);
    expect(await demo.execute(), isA<Err<String, PasskeyDemoFailure>>());
    expect(paths, ['/register/options']);
  });

  test(
    'cancellation signals the matching native request and prevents verify',
    () async {
      final started = Completer<void>();
      final native = Completer<String?>();
      final paths = <String>[];
      String? id;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'create') {
          id = (call.arguments as Map)['id'] as String;
          started.complete();
          return native.future;
        }
        expect(call.method, 'cancel');
        expect(call.arguments, id);
        native.complete('{}');
        return null;
      });
      final client = MockClient((request) async {
        paths.add(request.url.path);
        return http.Response(
          jsonEncode({'sessionId': 'session', 'options': <String, Object>{}}),
          200,
        );
      });
      final repository = PasskeyDemoRepositoryImpl(clientFactory: () => client);
      final demo = RunPasskeyDemoUsecase(() async => true, repository);
      final operation = demo.newOperation();
      final result = demo.execute(operation: operation);
      await started.future;
      operation.cancel();
      expect(await result, isA<Err<String, PasskeyDemoFailure>>());
      expect(paths, ['/register/options']);
    },
  );

  test('cancellation while verify is in flight ignores its result', () async {
    final started = Completer<void>();
    final verify = Completer<http.Response>();
    messenger.setMockMethodCallHandler(channel, (_) async => '{}');
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/options')) {
        return http.Response(
          jsonEncode({'sessionId': 'session', 'options': <String, Object>{}}),
          200,
        );
      }
      started.complete();
      return verify.future;
    });
    final repository = PasskeyDemoRepositoryImpl(clientFactory: () => client);
    final demo = RunPasskeyDemoUsecase(() async => true, repository);
    final operation = demo.newOperation();
    final result = demo.execute(operation: operation);
    await started.future;
    operation.cancel();
    verify.complete(http.Response('{"accountId":"account"}', 200));
    expect(await result, isA<Err<String, PasskeyDemoFailure>>());
  });

  test('disabled settings prevent starting a ceremony', () async {
    final repository = _Repository();
    final demo = RunPasskeyDemoUsecase(() async => false, repository);

    expect(
      await demo.execute(),
      isA<Err<String, PasskeyDemoFailure>>().having(
        (result) => result.failure,
        'failure',
        PasskeyDemoFailure.disabled,
      ),
    );
    expect(repository.registrations, 0);
  });

  test('registration and opening require separate ceremonies', () async {
    final repository = _Repository();
    final demo = RunPasskeyDemoUsecase(() async => true, repository);

    expect(
      await demo.execute(),
      isA<Ok<String, PasskeyDemoFailure>>().having(
        (result) => result.value,
        'value',
        'test-account',
      ),
    );
    expect(repository.openedAccount, isNull);
    expect(
      await demo.execute(accountId: 'test-account'),
      isA<Ok<String, PasskeyDemoFailure>>().having(
        (result) => result.value,
        'value',
        'sample data',
      ),
    );
    expect(repository.openedAccount, 'test-account');
  });

  test(
    'disabling the settings during authentication discards the result',
    () async {
      var enabled = true;
      final repository = _Repository()..duringOpen = () => enabled = false;
      final demo = RunPasskeyDemoUsecase(() async => enabled, repository);

      expect(
        await demo.execute(accountId: 'test-account'),
        isA<Err<String, PasskeyDemoFailure>>().having(
          (result) => result.failure,
          'failure',
          PasskeyDemoFailure.disabled,
        ),
      );
    },
  );
}
