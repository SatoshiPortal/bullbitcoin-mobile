import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

const _session = ExchangeSession(
  environment: ExchangeEnvironment.testnet,
  epoch: 3,
  sessionId: 'a',
);
const _next = ExchangeSession(
  environment: ExchangeEnvironment.testnet,
  epoch: 4,
  sessionId: 'b',
);

// Every stored preference differs from the patches below.
const _account = UserSummary(
  userNumber: 1,
  groups: [],
  profile: UserProfile(firstName: 'Sat', lastName: 'Oshi'),
  email: 'sat@example.com',
  balances: [],
  language: 'en',
  currency: 'CAD',
  dca: UserDca(isActive: true),
  autoBuy: UserAutoBuy(isActive: false, addresses: UserAutoBuyAddresses()),
);

typedef _Sent = ({
  ExchangeEnvironment environment,
  String? language,
  String? currency,
  bool? dcaEnabled,
  String? autoBuyEnabled,
  bool? emailNotificationsEnabled,
});

const _kept = (
  environment: ExchangeEnvironment.testnet,
  language: 'en',
  currency: 'CAD',
  dcaEnabled: true,
  autoBuyEnabled: 'false',
  emailNotificationsEnabled: true,
);

final class _Account {
  ExchangeSession? current = _session;
  Result<UserSummary, ExchangeFailure> summary = const Ok(_account);
  Result<void, ExchangeFailure> answer = const Ok(null);
  final reads = <ExchangeEnvironment>[];
  final sent = <_Sent>[];
  void Function()? onRead;

  UpdateExchangePreferences get writer => UpdateExchangePreferences(
    readSummary: (environment) async {
      reads.add(environment);
      onRead?.call();
      return summary;
    },
    write:
        (
          environment, {
          language,
          currency,
          dcaEnabled,
          autoBuyEnabled,
          emailNotificationsEnabled,
        }) async {
          sent.add((
            environment: environment,
            language: language,
            currency: currency,
            dcaEnabled: dcaEnabled,
            autoBuyEnabled: autoBuyEnabled,
            emailNotificationsEnabled: emailNotificationsEnabled,
          ));
          return answer;
        },
    currentSession: () => current,
  );
}

void main() {
  group('only the patched fields change; the rest are sent as read', () {
    for (final (name, patch, expected)
        in <(String, ExchangePreferencesPatch, _Sent)>[
          (
            'stop DCA',
            const ExchangePreferencesPatch(dcaEnabled: false),
            (
              environment: _kept.environment,
              language: _kept.language,
              currency: _kept.currency,
              dcaEnabled: false,
              autoBuyEnabled: _kept.autoBuyEnabled,
              emailNotificationsEnabled: _kept.emailNotificationsEnabled,
            ),
          ),
          (
            'AutoBuy on',
            const ExchangePreferencesPatch(autoBuyEnabled: true),
            (
              environment: _kept.environment,
              language: _kept.language,
              currency: _kept.currency,
              dcaEnabled: _kept.dcaEnabled,
              autoBuyEnabled: 'true',
              emailNotificationsEnabled: _kept.emailNotificationsEnabled,
            ),
          ),
          (
            'currency sync',
            const ExchangePreferencesPatch(currency: 'EUR'),
            (
              environment: _kept.environment,
              language: _kept.language,
              currency: 'EUR',
              dcaEnabled: _kept.dcaEnabled,
              autoBuyEnabled: _kept.autoBuyEnabled,
              emailNotificationsEnabled: _kept.emailNotificationsEnabled,
            ),
          ),
          (
            'preferences screen',
            const ExchangePreferencesPatch(
              language: 'fr',
              emailNotificationsEnabled: false,
            ),
            (
              environment: _kept.environment,
              language: 'fr',
              currency: _kept.currency,
              dcaEnabled: _kept.dcaEnabled,
              autoBuyEnabled: _kept.autoBuyEnabled,
              emailNotificationsEnabled: false,
            ),
          ),
        ]) {
      test(name, () async {
        final account = _Account();

        final result = await account.writer.execute(_session, patch);

        expect(result, isA<Ok<void, ExchangeFailure>>());
        expect(account.reads, [ExchangeEnvironment.testnet]);
        expect(account.sent, [expected]);
      });
    }
  });

  for (final (name, patch) in [
    ('an empty patch', const ExchangePreferencesPatch()),
    (
      'a patch the account already has',
      const ExchangePreferencesPatch(currency: 'CAD', dcaEnabled: true),
    ),
  ]) {
    test('$name sends nothing', () async {
      final account = _Account();

      expect(
        await account.writer.execute(_session, patch),
        isA<Ok<void, ExchangeFailure>>(),
      );
      expect(account.sent, isEmpty);
    });
  }

  test(
    'a session that is not current is refused before reading (INT-14)',
    () async {
      final account = _Account()..current = _next;

      final result = await account.writer.execute(
        _session,
        const ExchangePreferencesPatch(dcaEnabled: false),
      );

      expect(
        (result as Err<void, ExchangeFailure>).failure,
        isA<ExchangeOperationStaleFailure>(),
      );
      expect(account.reads, isEmpty);
      expect(account.sent, isEmpty);
    },
  );

  test('a session that ends during the read sends nothing', () async {
    final account = _Account();
    account.onRead = () => account.current = _next;

    final result = await account.writer.execute(
      _session,
      const ExchangePreferencesPatch(dcaEnabled: false),
    );

    expect(
      (result as Err<void, ExchangeFailure>).failure,
      isA<ExchangeOperationStaleFailure>(),
    );
    expect(account.sent, isEmpty);
  });

  for (final (read, expected) in <(ExchangeFailure, Type)>[
    (const ExchangeNetworkFailure(), ExchangeNetworkFailure),
    (const ExchangeNotAuthenticatedFailure(), ExchangeNotAuthenticatedFailure),
    (const ExchangeAccountUnavailableFailure(), ExchangePreferencesSaveFailure),
  ]) {
    test(
      'a failed summary read (${read.runtimeType}) aborts the write',
      () async {
        final account = _Account()..summary = Err(read);

        final result = await account.writer.execute(
          _session,
          const ExchangePreferencesPatch(currency: 'EUR'),
        );

        expect(
          (result as Err<void, ExchangeFailure>).failure.runtimeType,
          expected,
        );
        expect(account.sent, isEmpty);
      },
    );
  }

  for (final (answer, expected) in <(ExchangeFailure, Type)>[
    (const ExchangeNetworkFailure(), ExchangeNetworkFailure),
    (
      const ExchangePreferencesSaveOutcomeUnknownFailure(),
      ExchangePreferencesSaveOutcomeUnknownFailure,
    ),
    (const ExchangeSessionRejectedFailure(), ExchangePreferencesSaveFailure),
  ]) {
    test('a failed write (${answer.runtimeType}) is $expected', () async {
      final account = _Account()..answer = Err(answer);

      final result = await account.writer.execute(
        _session,
        const ExchangePreferencesPatch(currency: 'EUR'),
      );

      expect(
        (result as Err<void, ExchangeFailure>).failure.runtimeType,
        expected,
      );
    });
  }

  test(
    'updateCurrentPreferences without a session is not authenticated',
    () async {
      final exchange = exchangeForTesting(
        access: fixedAccessForTesting(
          const ExchangeAccessSignedOut(ExchangeEnvironment.testnet),
        ),
      );

      final result = await exchange.updateCurrentPreferences(
        const ExchangePreferencesPatch(dcaEnabled: false),
      );

      expect(
        (result as Err<void, ExchangeFailure>).failure,
        isA<ExchangeNotAuthenticatedFailure>(),
      );
    },
  );

  test('a patch names only the fields it changes', () {
    expect(
      const ExchangePreferencesPatch(
        language: 'en',
        currency: 'EUR',
      ).changesFrom(_account),
      const ExchangePreferencesPatch(currency: 'EUR'),
    );
  });
}
