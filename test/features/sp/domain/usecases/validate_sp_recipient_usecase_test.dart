import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_recipient.dart';
import 'package:bb_mobile/features/sp/domain/ports/sp_recipient_address_validator_port.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_network_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/validate_sp_recipient_usecase.dart';
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

  SpFailure? failureOf(Result<SpRecipient, SpFailure> r) =>
      r is Err<SpRecipient, SpFailure> ? r.failure : null;

  test('accepts a matching-network silent payment address', () async {
    when(
      () => networkUsecase.execute(),
    ).thenReturn(const Ok(BitcoinNetwork.mainnet));
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
    expect(result, isA<Ok<SpRecipient, SpFailure>>());
    expect((result as Ok<SpRecipient, SpFailure>).value, isA<SpRecipientSp>());
  });

  test('rejects a testnet address on a mainnet wallet', () async {
    when(
      () => networkUsecase.execute(),
    ).thenReturn(const Ok(BitcoinNetwork.mainnet));
    when(
      () => validator.validateRecipientAddress(
        'tsp1qexample',
        BitcoinNetwork.mainnet,
      ),
    ).thenAnswer((_) async => const Err(SpAddressNetworkMismatch()));
    final result = await usecase.execute(
      input: 'tsp1qexample',
      amountSat: Sats.zero,
      isMax: false,
    );
    expect(failureOf(result), isA<SpAddressNetworkMismatch>());
  });

  test('rejects an sprt1 address on a testnet wallet', () async {
    when(
      () => networkUsecase.execute(),
    ).thenReturn(const Ok(BitcoinNetwork.testnet));
    when(
      () => validator.validateRecipientAddress(
        'sprt1qexample',
        BitcoinNetwork.testnet,
      ),
    ).thenAnswer((_) async => const Err(SpAddressNetworkMismatch()));
    final result = await usecase.execute(
      input: 'sprt1qexample',
      amountSat: Sats.zero,
      isMax: false,
    );
    expect(failureOf(result), isA<SpAddressNetworkMismatch>());
  });

  test('fails closed on a network read error', () async {
    when(
      () => networkUsecase.execute(),
    ).thenReturn(const Err(SpUnexpected('read')));
    final result = await usecase.execute(
      input: 'sp1qexample',
      amountSat: Sats.zero,
      isMax: false,
    );
    // Forwarded unchanged: the guard must never be skipped on a read error.
    expect(failureOf(result), isA<SpUnexpected>());
    verifyNever(() => validator.validateRecipientAddress(any(), any()));
  });

  test('accepts a standard bitcoin address on a matching network', () async {
    when(
      () => networkUsecase.execute(),
    ).thenReturn(const Ok(BitcoinNetwork.mainnet));
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
    expect(result, isA<Ok<SpRecipient, SpFailure>>());
    expect(
      (result as Ok<SpRecipient, SpFailure>).value,
      isA<SpRecipientStandard>(),
    );
  });

  test('rejects a standard bitcoin address from another network', () async {
    when(
      () => networkUsecase.execute(),
    ).thenReturn(const Ok(BitcoinNetwork.testnet));
    when(
      () => validator.validateRecipientAddress(
        'bc1qexample',
        BitcoinNetwork.testnet,
      ),
    ).thenAnswer((_) async => const Err(SpAddressNetworkMismatch()));
    final result = await usecase.execute(
      input: 'bc1qexample',
      amountSat: Sats.fromInt(500),
      isMax: false,
    );
    expect(failureOf(result), isA<SpAddressNetworkMismatch>());
  });

  test('rejects an unrecognized address with SpInvalidAddress', () async {
    when(
      () => networkUsecase.execute(),
    ).thenReturn(const Ok(BitcoinNetwork.mainnet));
    when(
      () => validator.validateRecipientAddress(
        'lnbc1qexample',
        BitcoinNetwork.mainnet,
      ),
    ).thenAnswer((_) async => const Err(SpInvalidAddress('invalid')));
    final result = await usecase.execute(
      input: 'lnbc1qexample',
      amountSat: Sats.fromInt(500),
      isMax: false,
    );
    expect(failureOf(result), isA<SpInvalidAddress>());
  });
}
