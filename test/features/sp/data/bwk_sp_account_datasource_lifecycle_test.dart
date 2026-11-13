import 'package:bb_mobile/features/sp/data/datasources/bwk_sp_account_datasource.dart';
import 'package:bull_sdk/bwk.dart';
import 'package:bull_sdk/src/rust/frb_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

class _Account extends Mock implements SpAccount {}

class _Sdk implements BullSdkApi {
  late SpAccount account;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      Future<SpAccount>.value(account);
}

void main() {
  late _Account account;
  late BwkSpAccountDatasource datasource;
  late Secret secret;
  final sdk = _Sdk();

  setUpAll(() => BullSdk.initMock(api: sdk));
  tearDownAll(BullSdk.dispose);
  setUp(() async {
    FakeSecureStoragePlatform().install();
    account = _Account();
    when(() => account.spAddress()).thenReturn('same account');
    sdk.account = account;
    final secrets = Secrets(scratchDirectory: () async => '/tmp');
    final result = await secrets.import(
      words: [...List.filled(11, 'abandon'), 'about'],
    );
    secret = (result as Ok<Secret, SecretFailure>).value;
    datasource = BwkSpAccountDatasource();
    await datasource.createFromSecret(
      network: SpNetwork.signet,
      expectedAddress: 'same account',
      secret: secret,
      blindbitUrl: '',
      electrumUrl: '',
      dataDir: '/tmp',
      fetchConcurrencyFactor: 1,
      matchConcurrencyFactor: 1,
      headerCheckpoint: null,
    );
    datasource.publish();
  });

  test('disposes then releases before clearing the session', () async {
    when(() => account.dispose()).thenAnswer((_) async {
      expect(datasource.hasSession, isTrue);
    });
    when(() => account.release()).thenAnswer((_) async {
      expect(datasource.hasSession, isTrue);
    });

    await datasource.dispose();

    verifyInOrder([() => account.dispose(), () => account.release()]);
    expect(datasource.hasSession, isFalse);
  });

  test('a dispose failure retains the session and does not release', () async {
    const failure = SpError_DisposeTimedOut();
    when(() => account.spAddress()).thenReturn('same account');
    when(() => account.dispose()).thenThrow(failure);

    await expectLater(datasource.dispose(), throwsA(same(failure)));

    verify(() => account.dispose()).called(1);
    verifyNever(() => account.release());
    expect(datasource.hasSession, isTrue);
    expect(datasource.spAddress(), 'same account');
  });

  test(
    'a release failure is propagated without silently replacing the session',
    () async {
      final failure = Exception('release failed');
      when(() => account.dispose()).thenAnswer((_) async {});
      when(() => account.release()).thenThrow(failure);

      await expectLater(datasource.dispose(), throwsA(same(failure)));

      verifyInOrder([() => account.dispose(), () => account.release()]);
      expect(datasource.hasSession, isTrue);
    },
  );

  test(
    'mismatched account is not published and failed release retains it',
    () async {
      when(() => account.dispose()).thenAnswer((_) async {});
      when(() => account.release()).thenAnswer((_) async {});
      await datasource.dispose();
      datasource = BwkSpAccountDatasource();
      when(() => account.spAddress()).thenReturn('different address');
      when(() => account.dispose()).thenThrow(const SpError.disposeTimedOut());
      await expectLater(
        datasource.createFromSecret(
          network: SpNetwork.signet,
          expectedAddress: 'expected address',
          secret: secret,
          blindbitUrl: '',
          electrumUrl: '',
          dataDir: '/tmp',
          fetchConcurrencyFactor: 1,
          matchConcurrencyFactor: 1,
          headerCheckpoint: null,
        ),
        throwsA(isA<SpAccountAddressMismatch>()),
      );
      expect(datasource.hasSession, isFalse);
      expect(datasource.hasRetainedHandle, isTrue);
      expect(() => datasource.spAddress(), throwsStateError);
      when(() => account.dispose()).thenAnswer((_) async {});
      await datasource.dispose();
      expect(datasource.hasRetainedHandle, isFalse);
    },
  );
}
