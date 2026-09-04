import 'dart:async';

import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/features/recipients/public/recipients_facade.dart';
import 'package:bb_mobile/features/withdraw/domain/confirm_withdraw_order_usecase.dart';
import 'package:bb_mobile/features/withdraw/domain/create_withdraw_order_usecase.dart';
import 'package:bb_mobile/features/withdraw/domain/load_withdraw_context_usecase.dart';
import 'package:bb_mobile/features/withdraw/domain/withdraw_failure.dart';
import 'package:bb_mobile/features/withdraw/presentation/withdraw_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockLoadWithdrawContextUsecase extends Mock
    implements LoadWithdrawContextUsecase {}

class _MockCreateWithdrawOrderUsecase extends Mock
    implements CreateWithdrawOrderUsecase {}

class _MockConfirmWithdrawOrderUsecase extends Mock
    implements ConfirmWithdrawOrderUsecase {}

const _userSummary = UserSummary(
  userNumber: 1,
  groups: ["KYC_IDENTITY_VERIFIED"],
  profile: UserProfile(firstName: "Sat", lastName: "Oshi"),
  email: "sat@example.com",
  balances: [],
  dca: UserDca(isActive: false),
  autoBuy: UserAutoBuy(isActive: false, addresses: UserAutoBuyAddresses()),
);

class _MockWithdrawOrder extends Mock implements WithdrawOrder {}

class _SeedableWithdrawBloc extends WithdrawBloc {
  _SeedableWithdrawBloc({
    required super.loadWithdrawContextUsecase,
    required super.createWithdrawOrderUsecase,
    required super.confirmWithdrawOrderUsecase,
  });

  void seed(WithdrawState state) => emit(state);
}

const _recipient = RecipientSelection(
  id: 'recipient-1',
  type: RecipientType.billPaymentCad,
);

const _interacRecipient = RecipientSelection(
  id: 'recipient-1',
  type: RecipientType.interacEmailCad,
  email: 'person@example.com',
  securityQuestion: 'Favourite city?',
  securityAnswer: 'Montreal',
);

final _interacSecurityDetails = _ok(
  InteracSecurityDetails.create(
    recipientId: _interacRecipient.id,
    email: _interacRecipient.email!,
    securityQuestion: 'Favourite city?',
    securityAnswer: 'Montreal',
  ),
);

const _failure = WithdrawBelowMinAmountFailure(minAmount: 25, currency: 'CAD');

/// The value of an [Ok], failing the test on an [Err].
T _ok<T, F extends Failure>(Result<T, F> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => fail('expected Ok, got $failure'),
};

void main() {
  late _MockLoadWithdrawContextUsecase loadContext;
  late _MockCreateWithdrawOrderUsecase createOrder;
  late _MockConfirmWithdrawOrderUsecase confirmOrder;

  _SeedableWithdrawBloc build() => _SeedableWithdrawBloc(
    loadWithdrawContextUsecase: loadContext,
    createWithdrawOrderUsecase: createOrder,
    confirmWithdrawOrderUsecase: confirmOrder,
  );

  setUpAll(() => registerFallbackValue(_interacSecurityDetails));

  setUp(() {
    loadContext = _MockLoadWithdrawContextUsecase();
    createOrder = _MockCreateWithdrawOrderUsecase();
    confirmOrder = _MockConfirmWithdrawOrderUsecase();
  });

  group('WithdrawStarted', () {
    test('moves to the amount input on a loaded summary', () async {
      when(loadContext.userSummary).thenAnswer(
        (_) async => const Ok<UserSummary, WithdrawFailure>(_userSummary),
      );
      final bloc = build();

      bloc.add(const WithdrawEvent.started());
      await expectLater(
        bloc.stream,
        emitsThrough(isA<WithdrawAmountInputState>()),
      );
    });

    test('keeps the typed failure on the initial state', () async {
      when(loadContext.userSummary).thenAnswer(
        (_) async => const Err<UserSummary, WithdrawFailure>(
          WithdrawUnexpectedFailure('DioException apikey=secret123'),
        ),
      );
      final bloc = build();

      bloc.add(const WithdrawEvent.started());
      await expectLater(
        bloc.stream,
        emitsThrough(
          isA<WithdrawInitialState>().having(
            (s) => s.failure,
            'failure',
            isA<WithdrawUnexpectedFailure>(),
          ),
        ),
      );
    });
  });

  group('WithdrawStarted, re-dispatched as a retry', () {
    test('clears the previous failure and can then succeed', () async {
      // The amount screen's Retry button re-dispatches WithdrawStarted, so a
      // second attempt must not leave the old failure on the state.
      var attempt = 0;
      when(loadContext.userSummary).thenAnswer((_) async {
        attempt++;
        return attempt == 1
            ? const Err<UserSummary, WithdrawFailure>(
                WithdrawUnexpectedFailure('first attempt'),
              )
            : const Ok<UserSummary, WithdrawFailure>(_userSummary);
      });
      final bloc = build();

      bloc.add(const WithdrawEvent.started());
      await expectLater(
        bloc.stream,
        emitsThrough(
          isA<WithdrawInitialState>().having(
            (s) => s.failure,
            'failure',
            isNotNull,
          ),
        ),
      );

      bloc.add(const WithdrawEvent.started());
      await expectLater(
        bloc.stream,
        emitsThrough(isA<WithdrawAmountInputState>()),
      );
      expect(attempt, 2);
    });
  });

  group('WithdrawRecipientSelected', () {
    setUp(() {
      when(
        () => createOrder.execute(
          fiatAmount: any(named: 'fiatAmount'),
          recipientId: any(named: 'recipientId'),
        ),
      ).thenAnswer(
        (_) async =>
            const Err<CreateWithdrawOrderResult, WithdrawFailure>(_failure),
      );
    });

    WithdrawRecipientInputState recipientInput() => WithdrawRecipientInputState(
      userSummary: _userSummary,
      amount: FiatAmount(100),
      currency: FiatCurrency.cad,
    );

    test('a new recipient gets the failure and the flag goes down', () async {
      final bloc = build()..seed(recipientInput());

      bloc.add(WithdrawEvent.recipientSelected(_recipient, isNew: true));
      await expectLater(
        bloc.stream,
        emitsThrough(
          isA<WithdrawRecipientInputState>()
              .having(
                (s) => s.newRecipientFailure,
                'newRecipientFailure',
                _failure,
              )
              .having(
                (s) => s.selectedRecipientFailure,
                'selectedRecipientFailure',
                isNull,
              )
              .having(
                (s) => s.isCreatingWithdrawOrder,
                'isCreatingWithdrawOrder',
                isFalse,
              ),
        ),
      );
    });

    test('an existing recipient gets the failure on its own slot', () async {
      final bloc = build()..seed(recipientInput());

      bloc.add(WithdrawEvent.recipientSelected(_recipient, isNew: false));
      await expectLater(
        bloc.stream,
        emitsThrough(
          isA<WithdrawRecipientInputState>()
              .having(
                (s) => s.selectedRecipientFailure,
                'selectedRecipientFailure',
                _failure,
              )
              .having(
                (s) => s.newRecipientFailure,
                'newRecipientFailure',
                isNull,
              ),
        ),
      );
    });
  });

  group('WithdrawConfirmed', () {
    WithdrawConfirmationState confirmation() {
      final order = _MockWithdrawOrder();
      when(() => order.orderId).thenReturn('order-1');
      return WithdrawConfirmationState(
        userSummary: _userSummary,
        amount: FiatAmount(100),
        currency: FiatCurrency.cad,
        recipient: _recipient,
        order: order,
      );
    }

    void whenConfirm(Result<WithdrawOrder, WithdrawFailure> result) => when(
      () => confirmOrder.execute(
        orderId: any(named: 'orderId'),
        interacSecurityDetails: any(named: 'interacSecurityDetails'),
        saveSecurityDetailsAsDefault: any(
          named: 'saveSecurityDetailsAsDefault',
        ),
      ),
    ).thenAnswer((_) async => result);

    test('a failed confirmation stays on the confirmation state', () async {
      whenConfirm(
        const Err<WithdrawOrder, WithdrawFailure>(
          WithdrawUnauthenticatedFailure('apikey=secret123'),
        ),
      );
      final bloc = build()..seed(confirmation());

      bloc.add(const WithdrawEvent.confirmed());
      await expectLater(
        bloc.stream,
        emitsThrough(
          isA<WithdrawConfirmationState>()
              .having(
                (s) => s.failure,
                'failure',
                isA<WithdrawUnauthenticatedFailure>(),
              )
              .having(
                (s) => s.isConfirmingWithdrawal,
                'isConfirmingWithdrawal',
                isFalse,
              ),
        ),
      );
    });

    test('a confirmed order moves to success', () async {
      whenConfirm(Ok<WithdrawOrder, WithdrawFailure>(_MockWithdrawOrder()));
      final bloc = build()..seed(confirmation());

      bloc.add(const WithdrawEvent.confirmed());
      await expectLater(bloc.stream, emitsThrough(isA<WithdrawSuccessState>()));
    });
  });

  group('Interac security details', () {
    late _SeedableWithdrawBloc bloc;

    setUp(() => bloc = build());

    tearDown(() => bloc.close());

    void whenCreate(
      Future<Result<CreateWithdrawOrderResult, WithdrawFailure>> Function()
      answer,
    ) => when(
      () => createOrder.execute(
        fiatAmount: any(named: 'fiatAmount'),
        recipientId: any(named: 'recipientId'),
        recipientEmail: any(named: 'recipientEmail'),
        securityQuestion: any(named: 'securityQuestion'),
        securityAnswer: any(named: 'securityAnswer'),
      ),
    ).thenAnswer((_) => answer());

    Ok<CreateWithdrawOrderResult, WithdrawFailure> created(
      WithdrawOrder order,
    ) => Ok(
      CreateWithdrawOrderResult(
        order: order,
        interacSecurityDetails: _interacSecurityDetails,
      ),
    );

    test('asks for payment details before creating an Interac order', () async {
      bloc.seed(
        const WithdrawRecipientInputState(
          userSummary: _userSummary,
          amount: FiatAmount(125),
          currency: FiatCurrency.cad,
        ),
      );
      final nextState = bloc.stream.firstWhere(
        (state) => state is WithdrawPaymentDetailsInputState,
      );

      bloc.add(
        const WithdrawRecipientSelected(_interacRecipient, isNew: false),
      );

      expect(await nextState, isA<WithdrawPaymentDetailsInputState>());
      verifyZeroInteractions(createOrder);
    });

    test(
      'reopens payment details after returning to recipient state',
      () async {
        bloc.seed(
          const WithdrawPaymentDetailsInputState(
            userSummary: _userSummary,
            amount: FiatAmount(125),
            currency: FiatCurrency.cad,
            recipient: _interacRecipient,
          ),
        );
        final emittedStates = bloc.stream.take(2).toList();

        bloc.add(
          const WithdrawRecipientSelected(_interacRecipient, isNew: false),
        );

        expect(await emittedStates, [
          isA<WithdrawRecipientInputState>(),
          isA<WithdrawPaymentDetailsInputState>(),
        ]);
        verifyZeroInteractions(createOrder);
      },
    );

    test('submits entered details and the save-default choice', () async {
      final order = _MockWithdrawOrder();
      whenCreate(() async => created(order));
      bloc.seed(
        const WithdrawPaymentDetailsInputState(
          userSummary: _userSummary,
          amount: FiatAmount(125),
          currency: FiatCurrency.cad,
          recipient: _interacRecipient,
        ),
      );
      final confirmationState = bloc.stream.firstWhere(
        (state) => state is WithdrawConfirmationState,
      );

      bloc.add(
        const WithdrawInteracSecurityDetailsSubmitted(
          securityQuestion: 'Favourite city?',
          securityAnswer: 'Montreal',
          saveAsDefault: true,
        ),
      );

      final state = await confirmationState as WithdrawConfirmationState;
      expect(state.interacSecurityDetails, same(_interacSecurityDetails));
      expect(state.saveSecurityDetailsAsDefault, isTrue);
      verify(
        () => createOrder.execute(
          fiatAmount: 125,
          recipientId: 'recipient-1',
          recipientEmail: 'person@example.com',
          securityQuestion: 'Favourite city?',
          securityAnswer: 'Montreal',
        ),
      ).called(1);
    });

    test('keeps a failed submission on the payment details state', () async {
      whenCreate(
        () async =>
            const Err<CreateWithdrawOrderResult, WithdrawFailure>(_failure),
      );
      bloc.seed(
        const WithdrawPaymentDetailsInputState(
          userSummary: _userSummary,
          amount: FiatAmount(125),
          currency: FiatCurrency.cad,
          recipient: _interacRecipient,
        ),
      );

      bloc.add(
        const WithdrawInteracSecurityDetailsSubmitted(
          securityQuestion: 'Favourite city?',
          securityAnswer: 'Montreal',
          saveAsDefault: true,
        ),
      );
      await expectLater(
        bloc.stream,
        emitsThrough(
          isA<WithdrawPaymentDetailsInputState>()
              .having((s) => s.failure, 'failure', _failure)
              .having(
                (s) => s.isCreatingWithdrawOrder,
                'isCreatingWithdrawOrder',
                isFalse,
              ),
        ),
      );
    });

    test('drops a repeated submission while creating an order', () async {
      final order = _MockWithdrawOrder();
      final completer =
          Completer<Result<CreateWithdrawOrderResult, WithdrawFailure>>();
      whenCreate(() => completer.future);
      bloc.seed(
        const WithdrawPaymentDetailsInputState(
          userSummary: _userSummary,
          amount: FiatAmount(125),
          currency: FiatCurrency.cad,
          recipient: _interacRecipient,
        ),
      );
      const submission = WithdrawInteracSecurityDetailsSubmitted(
        securityQuestion: 'Favourite city?',
        securityAnswer: 'Montreal',
        saveAsDefault: true,
      );

      bloc
        ..add(submission)
        ..add(submission);
      await untilCalled(
        () => createOrder.execute(
          fiatAmount: any(named: 'fiatAmount'),
          recipientId: any(named: 'recipientId'),
          recipientEmail: any(named: 'recipientEmail'),
          securityQuestion: any(named: 'securityQuestion'),
          securityAnswer: any(named: 'securityAnswer'),
        ),
      );
      completer.complete(created(order));
      await bloc.stream.firstWhere(
        (state) => state is WithdrawConfirmationState,
      );

      verify(
        () => createOrder.execute(
          fiatAmount: any(named: 'fiatAmount'),
          recipientId: any(named: 'recipientId'),
          recipientEmail: any(named: 'recipientEmail'),
          securityQuestion: any(named: 'securityQuestion'),
          securityAnswer: any(named: 'securityAnswer'),
        ),
      ).called(1);
    });

    test('resubmits after returning from confirmation', () async {
      final previousOrder = _MockWithdrawOrder();
      final replacementOrder = _MockWithdrawOrder();
      whenCreate(() async => created(replacementOrder));
      bloc.seed(
        WithdrawConfirmationState(
          userSummary: _userSummary,
          amount: const FiatAmount(125),
          currency: FiatCurrency.cad,
          recipient: _interacRecipient,
          order: previousOrder,
          interacSecurityDetails: _interacSecurityDetails,
          saveSecurityDetailsAsDefault: true,
        ),
      );
      final confirmationState = bloc.stream.firstWhere(
        (state) =>
            state is WithdrawConfirmationState &&
            identical(state.order, replacementOrder),
      );

      bloc.add(
        const WithdrawInteracSecurityDetailsSubmitted(
          securityQuestion: 'Favourite city?',
          securityAnswer: 'Montreal',
          saveAsDefault: false,
        ),
      );

      final state = await confirmationState as WithdrawConfirmationState;
      expect(state.saveSecurityDetailsAsDefault, isFalse);
      verify(
        () => createOrder.execute(
          fiatAmount: 125,
          recipientId: 'recipient-1',
          recipientEmail: 'person@example.com',
          securityQuestion: 'Favourite city?',
          securityAnswer: 'Montreal',
        ),
      ).called(1);
    });

    test('forwards the saved details and choice to confirmation', () async {
      final order = _MockWithdrawOrder();
      when(() => order.orderId).thenReturn('order-1');
      when(
        () => confirmOrder.execute(
          orderId: any(named: 'orderId'),
          interacSecurityDetails: any(named: 'interacSecurityDetails'),
          saveSecurityDetailsAsDefault: any(
            named: 'saveSecurityDetailsAsDefault',
          ),
        ),
      ).thenAnswer((_) async => Ok<WithdrawOrder, WithdrawFailure>(order));
      bloc.seed(
        WithdrawConfirmationState(
          userSummary: _userSummary,
          amount: const FiatAmount(125),
          currency: FiatCurrency.cad,
          recipient: _interacRecipient,
          order: order,
          interacSecurityDetails: _interacSecurityDetails,
          saveSecurityDetailsAsDefault: true,
        ),
      );

      bloc.add(const WithdrawEvent.confirmed());
      await bloc.stream.firstWhere((state) => state is WithdrawSuccessState);

      verify(
        () => confirmOrder.execute(
          orderId: 'order-1',
          interacSecurityDetails: _interacSecurityDetails,
          saveSecurityDetailsAsDefault: true,
        ),
      ).called(1);
    });

    test('does not print Interac credentials in events or recipients', () {
      const event = WithdrawInteracSecurityDetailsSubmitted(
        securityQuestion: 'Favourite city?',
        securityAnswer: 'Montreal',
        saveAsDefault: true,
      );

      expect(event.toString(), isNot(contains('Montreal')));
      expect(_interacRecipient.toString(), isNot(contains('Montreal')));
    });
  });
}
