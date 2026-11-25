import 'package:bull_exchange/src/payout/domain/usecases/find_virtual_iban_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

final class _VirtualIbans implements ExchangeVirtualIbans {
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

FindVirtualIbanUsecase _usecase(
  Result<VirtualIban?, ExchangeFailure> answer, [
  List<ExchangeEnvironment>? asked,
]) => FindVirtualIbanUsecase(
  exchangeForTesting(
    virtualIbans: _VirtualIbans(
      find: (environment) async {
        asked?.add(environment);
        return answer;
      },
      create: (_) => throw StateError('no create'),
    ),
  ),
);

void main() {
  test('no virtual IBAN yet is a read of null in the session '
      'environment', () async {
    final asked = <ExchangeEnvironment>[];
    final read = await _usecase(const Ok(null), asked).execute(_testnet);
    expect(
      read,
      isA<ReadGot<VirtualIban?>>().having((r) => r.value, 'value', isNull),
    );
    expect(asked, [ExchangeEnvironment.testnet]);
  });

  test('a failed lookup is never read as no IBAN', () async {
    expect(
      await _usecase(const Err(ExchangeNetworkFailure())).execute(_testnet),
      isA<ReadUnreachable<VirtualIban?>>(),
    );
  });
}
