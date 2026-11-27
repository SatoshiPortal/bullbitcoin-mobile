import 'package:bull_exchange/src/payout/domain/usecases/load_virtual_iban_context_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

final class _VirtualIbans implements VirtualIbansRepository {
  final Future<Result<VirtualIban?, ExchangeFailure>> Function(
    ExchangeEnvironment environment,
  )
  _find;
  final Future<Result<VirtualIban, ExchangeFailure>> Function(
    ExchangeEnvironment environment,
  )
  _create;

  _VirtualIbans({required this._find, required this._create});

  @override
  Future<Result<VirtualIban?, ExchangeFailure>> find(
    ExchangeEnvironment environment,
  ) => _find(environment);

  @override
  Future<Result<VirtualIban, ExchangeFailure>> create(
    ExchangeEnvironment environment,
  ) => _create(environment);
}

const _testnet = ExchangeSession(
  environment: ExchangeEnvironment.testnet,
  epoch: 1,
  sessionId: 's',
);

UserSummary _summary(String first, String last) => UserSummary(
  userNumber: 7,
  groups: const [],
  profile: UserProfile(firstName: first, lastName: last),
  email: 'ada@example.com',
  balances: const [],
  currency: 'EUR',
  dca: const UserDca(isActive: false),
  autoBuy: const UserAutoBuy(
    isActive: false,
    addresses: UserAutoBuyAddresses(),
  ),
);

LoadVirtualIbanContextUsecase _usecase({
  required Result<UserSummary, ExchangeFailure> summary,
  required Result<VirtualIban?, ExchangeFailure> iban,
  List<ExchangeEnvironment?>? asked,
}) => LoadVirtualIbanContextUsecase(
  exchangeForTesting(
    getUserSummary: (environment) async {
      asked?.add(environment);
      return summary;
    },
    virtualIbans: _VirtualIbans(
      find: (environment) async {
        asked?.add(environment);
        return iban;
      },
      create: (_) => throw StateError('no create'),
    ),
  ),
);

void main() {
  test('reads the virtual IBAN and the trimmed owner name of the session '
      'account', () async {
    final asked = <ExchangeEnvironment?>[];
    final read = await _usecase(
      summary: Ok(_summary(' Ada ', 'Lovelace ')),
      iban: const Ok(null),
      asked: asked,
    ).execute(_testnet);
    expect(
      read,
      isA<ReadGot<VirtualIbanContext>>().having(
        (r) => r.value,
        'value',
        const VirtualIbanContext(virtualIban: null, ownerName: 'Ada Lovelace'),
      ),
    );
    expect(asked, [ExchangeEnvironment.testnet, ExchangeEnvironment.testnet]);
  });

  test('a rejected session on either read wins', () async {
    final read = await _usecase(
      summary: const Err(ExchangeNetworkFailure()),
      iban: const Err(ExchangeSessionRejectedFailure()),
    ).execute(_testnet);
    expect(read, isA<ReadSessionRejected<VirtualIbanContext>>());
  });

  test('any other failed read is the answer, never a context', () async {
    final summaryFailed = await _usecase(
      summary: const Err(ExchangeNetworkFailure()),
      iban: const Ok(null),
    ).execute(_testnet);
    expect(
      summaryFailed,
      isA<ReadUnreachable<VirtualIbanContext>>().having(
        (r) => r.isNetwork,
        'isNetwork',
        true,
      ),
    );
    final ibanFailed = await _usecase(
      summary: Ok(_summary('Ada', 'Lovelace')),
      iban: const Err(ExchangeUnexpectedFailure()),
    ).execute(_testnet);
    expect(ibanFailed, isA<ReadUnreachable<VirtualIbanContext>>());
  });
}
