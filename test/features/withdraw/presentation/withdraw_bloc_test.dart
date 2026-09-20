import 'dart:async';

import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/public/recipients_facade.dart';
import 'package:bb_mobile/features/withdraw/domain/confirm_withdraw_order_usecase.dart';
import 'package:bb_mobile/features/withdraw/domain/create_withdraw_order_usecase.dart';
import 'package:bb_mobile/features/withdraw/presentation/withdraw_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetExchangeUserSummaryUsecase extends Mock
    implements GetExchangeUserSummaryUsecase {}

class _MockCreateWithdrawOrderUsecase extends Mock
    implements CreateWithdrawOrderUsecase {}

class _MockConfirmWithdrawOrderUsecase extends Mock
    implements ConfirmWithdrawOrderUsecase {}

class _MockWithdrawOrder extends Mock implements WithdrawOrder {}

class _SeedableWithdrawBloc extends WithdrawBloc {
  _SeedableWithdrawBloc({
    required super.createWithdrawUsecase,
    required super.getExchangeUserSummaryUsecase,
    required super.confirmWithdrawUsecase,
  });

  void seed(WithdrawState state) => emit(state);
}

void main() {
  const userSummary = UserSummary(
    userNumber: 1,
    groups: [],
    profile: UserProfile(firstName: 'Sat', lastName: 'Oshi'),
    email: 'sat@example.com',
    balances: [],
    dca: UserDca(isActive: false),
    autoBuy: UserAutoBuy(isActive: false, addresses: UserAutoBuyAddresses()),
  );
  const recipient = RecipientSelection(
    id: 'recipient-1',
    type: RecipientType.interacEmailCad,
    email: 'person@example.com',
    securityQuestion: 'Favourite city?',
    securityAnswer: 'Montreal',
  );
  final interacSecurityDetails =
      (InteracSecurityDetails.create(
                recipientId: recipient.id,
                email: recipient.email!,
                securityQuestion: 'Favourite city?',
                securityAnswer: 'Montreal',
              )
              as Ok<InteracSecurityDetails, RecipientsFailure>)
          .value;

  late _MockCreateWithdrawOrderUsecase createWithdrawOrder;
  late _SeedableWithdrawBloc bloc;

  setUp(() {
    createWithdrawOrder = _MockCreateWithdrawOrderUsecase();
    bloc = _SeedableWithdrawBloc(
      createWithdrawUsecase: createWithdrawOrder,
      getExchangeUserSummaryUsecase: _MockGetExchangeUserSummaryUsecase(),
      confirmWithdrawUsecase: _MockConfirmWithdrawOrderUsecase(),
    );
  });

  tearDown(() => bloc.close());

  test('asks for payment details before creating an Interac order', () async {
    bloc.seed(
      const WithdrawRecipientInputState(
        userSummary: userSummary,
        amount: FiatAmount(125),
        currency: FiatCurrency.cad,
      ),
    );
    final nextState = bloc.stream.firstWhere(
      (state) => state is WithdrawPaymentDetailsInputState,
    );

    bloc.add(const WithdrawRecipientSelected(recipient, isNew: false));

    expect(await nextState, isA<WithdrawPaymentDetailsInputState>());
    verifyZeroInteractions(createWithdrawOrder);
  });

  test('reopens payment details after returning to recipient state', () async {
    bloc.seed(
      const WithdrawPaymentDetailsInputState(
        userSummary: userSummary,
        amount: FiatAmount(125),
        currency: FiatCurrency.cad,
        recipient: recipient,
      ),
    );
    final emittedStates = bloc.stream.take(2).toList();

    bloc.add(const WithdrawRecipientSelected(recipient, isNew: false));

    expect(await emittedStates, [
      isA<WithdrawRecipientInputState>(),
      isA<WithdrawPaymentDetailsInputState>(),
    ]);
    verifyZeroInteractions(createWithdrawOrder);
  });

  test('submits entered details and the save-default choice', () async {
    final order = _MockWithdrawOrder();
    when(
      () => createWithdrawOrder.execute(
        fiatAmount: any(named: 'fiatAmount'),
        recipientId: any(named: 'recipientId'),
        recipientEmail: any(named: 'recipientEmail'),
        securityQuestion: any(named: 'securityQuestion'),
        securityAnswer: any(named: 'securityAnswer'),
      ),
    ).thenAnswer(
      (_) async => CreateWithdrawOrderResult(
        order: order,
        interacSecurityDetails: interacSecurityDetails,
      ),
    );
    bloc.seed(
      const WithdrawPaymentDetailsInputState(
        userSummary: userSummary,
        amount: FiatAmount(125),
        currency: FiatCurrency.cad,
        recipient: recipient,
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
    expect(state.interacSecurityDetails, same(interacSecurityDetails));
    expect(state.saveSecurityDetailsAsDefault, isTrue);
    verify(
      () => createWithdrawOrder.execute(
        fiatAmount: 125,
        recipientId: 'recipient-1',
        recipientEmail: 'person@example.com',
        securityQuestion: 'Favourite city?',
        securityAnswer: 'Montreal',
      ),
    ).called(1);
  });

  test('drops a repeated submission while creating an order', () async {
    final order = _MockWithdrawOrder();
    final completer = Completer<CreateWithdrawOrderResult>();
    when(
      () => createWithdrawOrder.execute(
        fiatAmount: any(named: 'fiatAmount'),
        recipientId: any(named: 'recipientId'),
        recipientEmail: any(named: 'recipientEmail'),
        securityQuestion: any(named: 'securityQuestion'),
        securityAnswer: any(named: 'securityAnswer'),
      ),
    ).thenAnswer((_) => completer.future);
    bloc.seed(
      const WithdrawPaymentDetailsInputState(
        userSummary: userSummary,
        amount: FiatAmount(125),
        currency: FiatCurrency.cad,
        recipient: recipient,
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
      () => createWithdrawOrder.execute(
        fiatAmount: any(named: 'fiatAmount'),
        recipientId: any(named: 'recipientId'),
        recipientEmail: any(named: 'recipientEmail'),
        securityQuestion: any(named: 'securityQuestion'),
        securityAnswer: any(named: 'securityAnswer'),
      ),
    );
    completer.complete(
      CreateWithdrawOrderResult(
        order: order,
        interacSecurityDetails: interacSecurityDetails,
      ),
    );
    await bloc.stream.firstWhere((state) => state is WithdrawConfirmationState);

    verify(
      () => createWithdrawOrder.execute(
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
    when(
      () => createWithdrawOrder.execute(
        fiatAmount: any(named: 'fiatAmount'),
        recipientId: any(named: 'recipientId'),
        recipientEmail: any(named: 'recipientEmail'),
        securityQuestion: any(named: 'securityQuestion'),
        securityAnswer: any(named: 'securityAnswer'),
      ),
    ).thenAnswer(
      (_) async => CreateWithdrawOrderResult(
        order: replacementOrder,
        interacSecurityDetails: interacSecurityDetails,
      ),
    );
    bloc.seed(
      WithdrawConfirmationState(
        userSummary: userSummary,
        amount: const FiatAmount(125),
        currency: FiatCurrency.cad,
        recipient: recipient,
        order: previousOrder,
        interacSecurityDetails: interacSecurityDetails,
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
      () => createWithdrawOrder.execute(
        fiatAmount: 125,
        recipientId: 'recipient-1',
        recipientEmail: 'person@example.com',
        securityQuestion: 'Favourite city?',
        securityAnswer: 'Montreal',
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
    expect(recipient.toString(), isNot(contains('Montreal')));
  });
}
