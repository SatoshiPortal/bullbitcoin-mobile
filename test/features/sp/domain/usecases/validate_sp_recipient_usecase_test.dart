import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_network.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_recipient.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_network_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/validate_sp_recipient_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetSpNetworkUsecase extends Mock implements GetSpNetworkUsecase {}

void main() {
  late _MockGetSpNetworkUsecase networkUsecase;
  late ValidateSpRecipientUsecase usecase;

  setUp(() {
    networkUsecase = _MockGetSpNetworkUsecase();
    usecase = ValidateSpRecipientUsecase(getSpNetworkUsecase: networkUsecase);
  });

  SpFailure? failureOf(Result<SpRecipient, SpFailure> r) =>
      r is Err<SpRecipient, SpFailure> ? r.failure : null;

  test('accepts a matching-network silent payment address', () {
    when(() => networkUsecase.execute()).thenReturn(SpNetwork.bitcoin);
    final result = usecase.execute(
      input: 'sp1qexample',
      amountSat: BigInt.from(1000),
      isMax: false,
    );
    expect(result, isA<Ok<SpRecipient, SpFailure>>());
    expect((result as Ok<SpRecipient, SpFailure>).value, isA<SpRecipientSp>());
  });

  test('rejects a testnet address on a mainnet wallet', () {
    when(() => networkUsecase.execute()).thenReturn(SpNetwork.bitcoin);
    final result = usecase.execute(
      input: 'tsp1qexample',
      amountSat: BigInt.zero,
      isMax: false,
    );
    expect(failureOf(result), isA<SpAddressNetworkMismatch>());
  });

  test('rejects an sprt1 address on a testnet wallet', () {
    when(() => networkUsecase.execute()).thenReturn(SpNetwork.testnet);
    final result = usecase.execute(
      input: 'sprt1qexample',
      amountSat: BigInt.zero,
      isMax: false,
    );
    expect(failureOf(result), isA<SpAddressNetworkMismatch>());
  });

  test('fails closed with SpUnexpected on a network read error', () {
    when(() => networkUsecase.execute()).thenThrow(Exception('read'));
    final result = usecase.execute(
      input: 'sp1qexample',
      amountSat: BigInt.zero,
      isMax: false,
    );
    expect(failureOf(result), isA<SpUnexpected>());
  });

  test('accepts a standard bitcoin address without a network check', () {
    final result = usecase.execute(
      input: 'bc1qexample',
      amountSat: BigInt.from(500),
      isMax: false,
    );
    expect(result, isA<Ok<SpRecipient, SpFailure>>());
    expect(
      (result as Ok<SpRecipient, SpFailure>).value,
      isA<SpRecipientStandard>(),
    );
    verifyNever(() => networkUsecase.execute());
  });
}
