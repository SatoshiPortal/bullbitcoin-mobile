import 'package:primitives/primitives.dart';
import 'package:silent/src/domain/entities/sp_recipient.dart';
import 'package:silent/src/domain/ports/sp_recipient_address_validator_port.dart';
import 'package:silent/src/domain/silent_failure.dart';
import 'package:silent/src/domain/usecases/get_sp_network_usecase.dart';
import 'package:silent/src/domain/usecases/validate_sp_recipient_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetSpNetworkUsecase extends Mock implements GetSpNetworkUsecase {}

class _MockSpRecipientAddressValidatorPort extends Mock
    implements SpRecipientAddressValidatorPort {}

void main() {
  late _MockGetSpNetworkUsecase networkUsecase;
  late _MockSpRecipientAddressValidatorPort validator;
  late ValidateSpRecipientUsecase usecase;

  setUpAll(() {
    registerFallbackValue(BitcoinNetwork.mainnet);
  });

  setUp(() {
    networkUsecase = _MockGetSpNetworkUsecase();
    validator = _MockSpRecipientAddressValidatorPort();
    usecase = ValidateSpRecipientUsecase(
      getSpNetworkUsecase: networkUsecase,
      validator: validator,
    );
  });

  SilentFailure? failureOf(Result<SilentRecipient, SilentFailure> r) =>
      r is Err<SilentRecipient, SilentFailure> ? r.failure : null;

  test('accepts a matching-network silent payment address', () async {
    when(() => networkUsecase.execute())
        .thenReturn(const Ok(BitcoinNetwork.mainnet));
    when(
      () => validator.validateRecipientAddress(
        'sp1qexample',
        BitcoinNetwork.mainnet,
      ),
    ).thenAnswer((_) async => const Ok(SpRecipientAddressType.silentPayment));
    final result = await usecase.execute(
      input: 'sp1qexample',
      amountSat: Sats.fromInt(1000),
      isMax: false,
    );
    expect(result, isA<Ok<SilentRecipient, SilentFailure>>());
    expect(
      (result as Ok<SilentRecipient, SilentFailure>).value,
      isA<SilentRecipientSp>(),
    );
  });

  test('rejects a testnet address on a mainnet wallet', () async {
    when(() => networkUsecase.execute())
        .thenReturn(const Ok(BitcoinNetwork.mainnet));
    when(
      () => validator.validateRecipientAddress(
        'tsp1qexample',
        BitcoinNetwork.mainnet,
      ),
    ).thenAnswer((_) async => const Err(SilentAddressNetworkMismatch()));
    final result = await usecase.execute(
      input: 'tsp1qexample',
      amountSat: Sats.zero,
      isMax: false,
    );
    expect(failureOf(result), isA<SilentAddressNetworkMismatch>());
  });

  test('rejects an sprt1 address on a testnet wallet', () async {
    when(() => networkUsecase.execute())
        .thenReturn(const Ok(BitcoinNetwork.testnet));
    when(
      () => validator.validateRecipientAddress(
        'sprt1qexample',
        BitcoinNetwork.testnet,
      ),
    ).thenAnswer((_) async => const Err(SilentAddressNetworkMismatch()));
    final result = await usecase.execute(
      input: 'sprt1qexample',
      amountSat: Sats.zero,
      isMax: false,
    );
    expect(failureOf(result), isA<SilentAddressNetworkMismatch>());
  });

  test('fails closed on a network read error', () async {
    when(() => networkUsecase.execute())
        .thenReturn(const Err(SilentUnexpected('read')));
    final result = await usecase.execute(
      input: 'sp1qexample',
      amountSat: Sats.zero,
      isMax: false,
    );
    // Forwarded unchanged: the guard must never be skipped on a read error.
    expect(failureOf(result), isA<SilentUnexpected>());
    verifyNever(() => validator.validateRecipientAddress(any(), any()));
  });

  test('accepts a standard bitcoin address on a matching network', () async {
    when(() => networkUsecase.execute())
        .thenReturn(const Ok(BitcoinNetwork.mainnet));
    when(
      () => validator.validateRecipientAddress(
        'bc1qexample',
        BitcoinNetwork.mainnet,
      ),
    ).thenAnswer((_) async => const Ok(SpRecipientAddressType.standard));
    final result = await usecase.execute(
      input: 'bc1qexample',
      amountSat: Sats.fromInt(500),
      isMax: false,
    );
    expect(result, isA<Ok<SilentRecipient, SilentFailure>>());
    expect(
      (result as Ok<SilentRecipient, SilentFailure>).value,
      isA<SilentRecipientStandard>(),
    );
  });

  test('rejects a standard bitcoin address from another network', () async {
    when(() => networkUsecase.execute())
        .thenReturn(const Ok(BitcoinNetwork.testnet));
    when(
      () => validator.validateRecipientAddress(
        'bc1qexample',
        BitcoinNetwork.testnet,
      ),
    ).thenAnswer((_) async => const Err(SilentAddressNetworkMismatch()));
    final result = await usecase.execute(
      input: 'bc1qexample',
      amountSat: Sats.fromInt(500),
      isMax: false,
    );
    expect(failureOf(result), isA<SilentAddressNetworkMismatch>());
  });

  test('rejects an unrecognized address with SilentInvalidAddress', () async {
    when(() => networkUsecase.execute())
        .thenReturn(const Ok(BitcoinNetwork.mainnet));
    when(
      () => validator.validateRecipientAddress(
        'lnbc1qexample',
        BitcoinNetwork.mainnet,
      ),
    ).thenAnswer((_) async => const Err(SilentInvalidAddress('invalid')));
    final result = await usecase.execute(
      input: 'lnbc1qexample',
      amountSat: Sats.fromInt(500),
      isMax: false,
    );
    expect(failureOf(result), isA<SilentInvalidAddress>());
  });
}
