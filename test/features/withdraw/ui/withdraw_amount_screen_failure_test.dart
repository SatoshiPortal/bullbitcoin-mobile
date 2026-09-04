import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/withdraw/domain/confirm_withdraw_order_usecase.dart';
import 'package:bb_mobile/features/withdraw/domain/create_withdraw_order_usecase.dart';
import 'package:bb_mobile/features/withdraw/domain/load_withdraw_context_usecase.dart';
import 'package:bb_mobile/features/withdraw/domain/withdraw_failure.dart';
import 'package:bb_mobile/features/withdraw/presentation/withdraw_bloc.dart';
import 'package:bb_mobile/features/withdraw/ui/screens/withdraw_amount_screen.dart';
import 'package:bb_mobile/features/withdraw/ui/widgets/withdraw_amount_input_fields.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockLoadWithdrawContextUsecase extends Mock
    implements LoadWithdrawContextUsecase {}

class _MockCreateWithdrawOrderUsecase extends Mock
    implements CreateWithdrawOrderUsecase {}

class _MockConfirmWithdrawOrderUsecase extends Mock
    implements ConfirmWithdrawOrderUsecase {}

const _userSummary = UserSummary(
  userNumber: 1,
  groups: ['KYC_IDENTITY_VERIFIED'],
  profile: UserProfile(firstName: 'Sat', lastName: 'Oshi'),
  email: 'sat@example.com',
  balances: [UserBalance(amount: 500, currencyCode: 'CAD')],
  currency: 'CAD',
  dca: UserDca(isActive: false),
  autoBuy: UserAutoBuy(isActive: false, addresses: UserAutoBuyAddresses()),
);

void main() {
  late _MockLoadWithdrawContextUsecase loadContext;

  WithdrawBloc buildBloc() => WithdrawBloc(
    loadWithdrawContextUsecase: loadContext,
    createWithdrawOrderUsecase: _MockCreateWithdrawOrderUsecase(),
    confirmWithdrawOrderUsecase: _MockConfirmWithdrawOrderUsecase(),
  );

  // The real screen sits behind a GoRoute and its AppBar calls
  // context.canPop(), so a bare MaterialApp is not enough.
  Widget app(WithdrawBloc bloc) => MaterialApp.router(
    theme: AppTheme.themeData(AppThemeType.light),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => BlocProvider.value(
            value: bloc,
            child: const WithdrawAmountScreen(),
          ),
        ),
      ],
    ),
  );

  setUp(() => loadContext = _MockLoadWithdrawContextUsecase());

  testWidgets('a failed summary load replaces the form with a reason', (
    tester,
  ) async {
    when(loadContext.userSummary).thenAnswer(
      (_) async => const Err<UserSummary, WithdrawFailure>(
        WithdrawUnexpectedFailure('DioException apikey=secret123'),
      ),
    );
    final bloc = buildBloc()..add(const WithdrawEvent.started());
    addTearDown(bloc.close);

    await tester.pumpWidget(app(bloc));
    await tester.pumpAndSettle();

    // The amount fields shimmer on `isLoading` forever while the summary is
    // missing, so the failure branch must take their place entirely.
    expect(find.byType(WithdrawAmountInputFields), findsNothing);
    expect(
      find.text(
        'Your withdrawal could not be completed right now. '
        'Please try again or contact support.',
      ),
      findsOneWidget,
    );
    // And never the raw reason.
    expect(find.textContaining('secret123'), findsNothing);
    expect(find.textContaining('DioException'), findsNothing);
  });

  testWidgets('Retry reloads in place and reveals the form on success', (
    tester,
  ) async {
    var attempt = 0;
    when(loadContext.userSummary).thenAnswer((_) async {
      attempt++;
      return attempt == 1
          ? const Err<UserSummary, WithdrawFailure>(
              WithdrawUnexpectedFailure('first attempt'),
            )
          : const Ok<UserSummary, WithdrawFailure>(_userSummary);
    });
    final bloc = buildBloc()..add(const WithdrawEvent.started());
    addTearDown(bloc.close);

    await tester.pumpWidget(app(bloc));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    // WithdrawStarted is dispatched once by the router, so without this button
    // the only recovery would be leaving the flow entirely.
    expect(attempt, 2);
    expect(find.text('Retry'), findsNothing);
    expect(find.byType(WithdrawAmountInputFields), findsOneWidget);
  });
}
