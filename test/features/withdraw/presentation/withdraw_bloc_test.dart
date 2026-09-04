import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_view_model.dart';
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

const _recipient = RecipientViewModel(
  id: 'recipient-1',
  type: RecipientType.interacEmailCad,
);

const _failure = WithdrawBelowMinAmountFailure(minAmount: 25, currency: 'CAD');

void main() {
  late _MockLoadWithdrawContextUsecase loadContext;
  late _MockCreateWithdrawOrderUsecase createOrder;
  late _MockConfirmWithdrawOrderUsecase confirmOrder;

  _SeedableWithdrawBloc build() => _SeedableWithdrawBloc(
    loadWithdrawContextUsecase: loadContext,
    createWithdrawOrderUsecase: createOrder,
    confirmWithdrawOrderUsecase: confirmOrder,
  );

  setUpAll(() => registerFallbackValue(RecipientType.interacEmailCad));

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

  group('WithdrawRecipientSelected', () {
    setUp(() {
      when(
        () => createOrder.execute(
          fiatAmount: any(named: 'fiatAmount'),
          recipientId: any(named: 'recipientId'),
          recipientType: any(named: 'recipientType'),
        ),
      ).thenAnswer(
        (_) async => const Err<WithdrawOrder, WithdrawFailure>(_failure),
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

    test('a failed confirmation stays on the confirmation state', () async {
      when(
        () => confirmOrder.execute(orderId: any(named: 'orderId')),
      ).thenAnswer(
        (_) async => const Err<WithdrawOrder, WithdrawFailure>(
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
      final order = _MockWithdrawOrder();
      when(
        () => confirmOrder.execute(orderId: any(named: 'orderId')),
      ).thenAnswer((_) async => Ok<WithdrawOrder, WithdrawFailure>(order));
      final bloc = build()..seed(confirmation());

      bloc.add(const WithdrawEvent.confirmed());
      await expectLater(bloc.stream, emitsThrough(isA<WithdrawSuccessState>()));
    });
  });
}
