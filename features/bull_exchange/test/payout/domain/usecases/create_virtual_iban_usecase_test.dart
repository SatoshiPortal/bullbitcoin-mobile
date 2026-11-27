import 'package:bull_exchange/src/payout/domain/usecases/create_virtual_iban_usecase.dart';
import 'package:exchange/exchange.dart';
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

CreateVirtualIbanUsecase _usecase(
  Result<VirtualIban, ExchangeFailure> answer, [
  List<ExchangeEnvironment>? asked,
]) => CreateVirtualIbanUsecase(
  exchangeForTesting(
    virtualIbans: _VirtualIbans(
      find: (_) => throw StateError('no find'),
      create: (environment) async {
        asked?.add(environment);
        return answer;
      },
    ),
  ),
);

void main() {
  test('creates the virtual IBAN in the session environment', () async {
    final asked = <ExchangeEnvironment>[];
    final iban = VirtualIban.fromBankDetails();
    final write = await _usecase(Ok(iban), asked).execute(_testnet);
    expect(
      write,
      isA<WriteDone<VirtualIban>>().having((w) => w.value, 'value', iban),
    );
    expect(asked, [ExchangeEnvironment.testnet]);
  });

  test('a failure that may have reached the exchange is unknown, a refusal '
      'is refused', () async {
    expect(
      await _usecase(const Err(ExchangeNetworkFailure())).execute(_testnet),
      isA<WriteOutcomeUnknown<VirtualIban>>(),
    );
    expect(
      await _usecase(const Err(ExchangeVirtualIbanNotAvailableFailure()))
          .execute(_testnet),
      isA<WriteRefused<VirtualIban>>(),
    );
  });
}
