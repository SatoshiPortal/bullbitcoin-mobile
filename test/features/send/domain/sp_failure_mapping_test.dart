import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/domain/sp_failure_mapping.dart';
import 'package:bb_mobile/features/send/domain/usecases/get_sp_network_for_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_sp_payment_for_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/refresh_sp_wallet_for_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/send_sp_payment_for_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/validate_sp_amount_for_send_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/validate_sp_recipient_for_send_usecase.dart';
import 'package:bb_mobile/features/sp/public/sp_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockSpFacade extends Mock implements SpFacade {}

class _MockGetSpNetworkForSendUsecase extends Mock
    implements GetSpNetworkForSendUsecase {}

void main() {
  late _MockSpFacade facade;

  setUp(() {
    facade = _MockSpFacade();
  });

  SendFailure failureOf(Result<Object?, SendFailure> result) =>
      (result as Err<Object?, SendFailure>).failure;
  group('SpFailure.toSendFailure', () {
    test('an amount below the minimum reports out-of-bounds from one sat', () {
      final failure =
          const SpAmountBelowMinimum('below').toSendFailure()
              as SendAmountOutOfBoundsFailure;

      expect(failure.minimumSat, BigInt.one);
      expect(failure.logMessage, 'below');
    });

    test('an amount over the balance reports insufficient balance', () {
      final failure = const SpAmountExceedsBalance('exceeds').toSendFailure();

      expect(failure, isA<SendInsufficientBalanceFailure>());
      expect(failure!.logMessage, 'exceeds');
    });

    test('a wrong-network address reports the mismatch', () {
      final failure = const SpAddressNetworkMismatch(
        'wrong network',
      ).toSendFailure();

      expect(failure, isA<SendAddressNetworkMismatchFailure>());
      expect(failure!.logMessage, 'wrong network');
    });

    test('an unrecognized address reports an invalid payment request', () {
      final failure = const SpInvalidAddress('unsupported').toSendFailure();

      expect(failure, isA<SendInvalidPaymentRequestFailure>());
      expect(failure!.logMessage, 'unsupported');
    });

    test('the failures the user cannot act on map to nothing', () {
      expect(const SpUnexpected('boom').toSendFailure(), isNull);
      expect(const SpNotSetUp().toSendFailure(), isNull);
      expect(const SpSessionBusy().toSendFailure(), isNull);
      expect(const SpBackendUnreachable('down').toSendFailure(), isNull);
      expect(const SpSimulationDrifted('drift').toSendFailure(), isNull);
    });
  });

  // Each wrapper picks its own generic for a failure the mapping leaves
  // unmapped, so the send flow never shows a raw SP message.
  group('wrapper fallbacks', () {
    test('the network read reports an unexpected failure', () {
      when(
        facade.network,
      ).thenReturn(const Err<BitcoinNetwork?, SpFailure>(SpUnexpected('read')));

      final result = GetSpNetworkForSendUsecase(facade).execute();

      expect(failureOf(result), isA<SendUnexpectedFailure>());
      expect(failureOf(result).logMessage, 'read');
    });

    test('the wallet refresh reports an unexpected failure', () async {
      when(facade.refresh).thenAnswer(
        (_) async => const Err<SpWallet?, SpFailure>(SpUnexpected('refresh')),
      );

      final result = await RefreshSpWalletForSendUsecase(
        facade,
        _MockGetSpNetworkForSendUsecase(),
      ).execute();

      expect(failureOf(result), isA<SendUnexpectedFailure>());
    });

    test('the amount check reports an unexpected failure', () {
      when(
        () => facade.validateAmount(Sats.zero),
      ).thenReturn(const Err<Sats, SpFailure>(SpNotSetUp()));

      final result = ValidateSpAmountForSendUsecase(facade).execute(Sats.zero);

      expect(failureOf(result), isA<SendUnexpectedFailure>());
    });

    test('the recipient check reports an invalid payment request', () async {
      when(
        () => facade.validateRecipient(
          input: 'sp1qexample',
          amountSat: Sats.zero,
          isMax: false,
        ),
      ).thenAnswer(
        (_) async => const Err<SpRecipient, SpFailure>(SpSessionBusy()),
      );

      final result = await ValidateSpRecipientForSendUsecase(
        facade,
      ).execute(input: 'sp1qexample', amountSat: Sats.zero, isMax: false);

      expect(failureOf(result), isA<SendInvalidPaymentRequestFailure>());
    });

    test('a prepare failure reports a build failure', () async {
      when(
        () => facade.preparePayment(
          recipients: const [],
          feerateSatVb: BigInt.one,
        ),
      ).thenAnswer(
        (_) async =>
            const Err<SpTxDraft, SpFailure>(SpBackendUnreachable('down')),
      );

      final result = await PrepareSpPaymentForSendUsecase(
        facade,
      ).execute(recipients: const [], fee: null);

      expect(failureOf(result), isA<SendTransactionBuildFailure>());
      expect(failureOf(result).logMessage, 'down');
    });

    test('every broadcast failure reports a broadcast failure', () async {
      final draft = SpTxDraft(
        id: 'draft-1',
        inputs: const [],
        outputs: const [],
        feeSat: Sats.zero,
        changeSat: Sats.zero,
      );
      when(() => facade.sendPayment(draft: draft)).thenAnswer(
        (_) async =>
            const Err<String, SpFailure>(SpAmountExceedsBalance('exceeds')),
      );

      final result = await SendSpPaymentForSendUsecase(
        facade,
      ).execute(draft: draft);

      final failure = failureOf(result) as SendTransactionConfirmationFailure;
      expect(failure.isBroadcastFailure, isTrue);
      expect(failure.logMessage, 'exceeds');
    });
  });
}
