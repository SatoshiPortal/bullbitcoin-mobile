import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secrets/src/data/legacy_keystore_datasource.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.bullbitcoin.secrets/legacy_reader');
  const datasource = LegacyKeystoreDatasource();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'only read operations cross the channel, with no caller-supplied path',
    () async {
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        expect(call.arguments, isNull);
        return call.method == 'inspect'
            ? {'format': 'esp', 'sourcePresent': true, 'priorStoreHint': true}
            : {
                'format': 'esp',
                'entries': {'pin_code': 'synthetic'},
              };
      });
      final inventory = await datasource.inspect();
      expect(inventory.format, LegacyKeystoreFormat.esp);
      expect(inventory.sourcePresent, isTrue);
      expect(inventory.priorStoreHint, isTrue);
      final read = await datasource.readLegacy();
      expect(read.entries, {'pin_code': 'synthetic'});
      expect(() => read.entries.clear(), throwsUnsupportedError);
      expect(calls, ['inspect', 'readLegacy']);
    },
  );

  test(
    'locked and unreadable platform failures never become absence',
    () async {
      for (final problem in LegacyKeystoreProblem.values) {
        messenger.setMockMethodCallHandler(channel, (_) async {
          throw PlatformException(
            code: problem.name,
            message: 'private sentinel',
            details: 'private sentinel',
          );
        });
        try {
          await datasource.readLegacy();
          fail('a platform failure must be reported');
        } on LegacyKeystoreReadException catch (error) {
          expect(error.problem, problem);
          expect(error.toString(), isNot(contains('private sentinel')));
        }
      }
    },
  );

  test(
    'invalid or empty inventory cannot produce a usable legacy read',
    () async {
      for (final response in <Object?>[
        null,
        {'format': 'empty', 'entries': <String, String>{}},
        {'format': 'gcm', 'entries': <String, String>{}},
        {
          'format': 'mixed',
          'entries': {'a': 'synthetic'},
        },
        {
          'format': 'esp',
          'entries': {'a': 1},
        },
        {
          'format': 'esp',
          'entries': {'': 'synthetic'},
        },
        {
          'format': 'unexpected',
          'entries': {'a': 'synthetic'},
        },
      ]) {
        messenger.setMockMethodCallHandler(channel, (_) async => response);
        await expectLater(
          datasource.readLegacy(),
          throwsA(isA<LegacyKeystoreReadException>()),
        );
      }
    },
  );

  test('authenticated GCM is inventory only', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => {
        'format': 'gcm',
        'sourcePresent': true,
        'priorStoreHint': true,
      },
    );
    final inventory = await datasource.inspect();
    expect(inventory.format, LegacyKeystoreFormat.gcm);
    expect(inventory.priorStoreHint, isTrue);
  });

  test(
    'missing native support is unavailable, not a fresh installation',
    () async {
      await expectLater(
        datasource.inspect(),
        throwsA(
          isA<LegacyKeystoreReadException>().having(
            (error) => error.problem,
            'problem',
            LegacyKeystoreProblem.unavailable,
          ),
        ),
      );
    },
  );
}
