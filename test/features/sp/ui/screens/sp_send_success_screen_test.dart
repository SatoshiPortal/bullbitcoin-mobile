import 'package:bb_mobile/features/sp/domain/usecases/get_sp_balance_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_network_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/prepare_sp_payment_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/send_sp_payment_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/validate_sp_amount_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/validate_sp_recipient_usecase.dart';
import 'package:bb_mobile/features/sp/presentation/sp_send_cubit.dart';
import 'package:bb_mobile/features/sp/presentation/sp_send_state.dart';
import 'package:bb_mobile/core/widgets/address_viewer.dart';
import 'package:bb_mobile/features/sp/ui/screens/sp_send_success_screen.dart';
import 'package:flutter/material.dart';
import 'package:gif/gif.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';

class _MockPrepareSpPaymentUsecase extends Mock
    implements PrepareSpPaymentUsecase {}

class _MockSendSpPaymentUsecase extends Mock implements SendSpPaymentUsecase {}

class _MockGetSpNetworkUsecase extends Mock implements GetSpNetworkUsecase {}

class _MockGetSpBalanceUsecase extends Mock implements GetSpBalanceUsecase {}

class _TestSpSendCubit extends SpSendCubit {
  _TestSpSendCubit({
    required super.prepareSpPaymentUsecase,
    required super.sendSpPaymentUsecase,
    required super.validateSpRecipientUsecase,
    required super.validateSpAmountUsecase,
  });

  void emitTestState(SpSendState state) => emit(state);
}

Widget _buildPage(_TestSpSendCubit cubit) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: BlocProvider<SpSendCubit>.value(
    value: cubit,
    child: const SpSendSuccessScreen(),
  ),
);

void main() {
  late _TestSpSendCubit cubit;

  setUp(() {
    cubit = _TestSpSendCubit(
      prepareSpPaymentUsecase: _MockPrepareSpPaymentUsecase(),
      sendSpPaymentUsecase: _MockSendSpPaymentUsecase(),
      validateSpRecipientUsecase: ValidateSpRecipientUsecase(
        getSpNetworkUsecase: _MockGetSpNetworkUsecase(),
      ),
      validateSpAmountUsecase: ValidateSpAmountUsecase(
        getSpBalanceUsecase: _MockGetSpBalanceUsecase(),
      ),
    );
  });

  tearDown(() => cubit.close());

  testWidgets('renders Sent text', (tester) async {
    cubit.emitTestState(const SpSendState(txid: 'aabbccddeeff00112233'));
    await tester.pumpWidget(_buildPage(cubit));
    await tester.pump();

    expect(find.text('Sent'), findsOneWidget);
  });

  testWidgets('renders success animation', (tester) async {
    cubit.emitTestState(const SpSendState(txid: 'aabbccddeeff00112233'));
    await tester.pumpWidget(_buildPage(cubit));
    await tester.pump();

    expect(find.byType(Gif), findsOneWidget);
  });

  testWidgets('shows Done button', (tester) async {
    cubit.emitTestState(const SpSendState(txid: 'aabbccddeeff00112233'));
    await tester.pumpWidget(_buildPage(cubit));
    await tester.pump();

    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('shows txid in an AddressViewer', (tester) async {
    cubit.emitTestState(
      const SpSendState(
        txid:
            'aabbccddeeff001122334455667788990011223344556677889900112233445566',
      ),
    );
    await tester.pumpWidget(_buildPage(cubit));
    await tester.pump();

    expect(find.byType(AddressViewer), findsOneWidget);
  });

  testWidgets(
    'R4: wraps body in PopScope with canPop=false so system-back cannot land on the confirm page with a stale simulation',
    (tester) async {
      // Seed a "post-broadcast" state that still has txid set, mimicking the
      // moment the user lands on the success page.
      cubit.emitTestState(const SpSendState(txid: 'aabbccddeeff00112233'));
      await tester.pumpWidget(_buildPage(cubit));
      await tester.pump();

      // MaterialApp installs its own PopScope internally, so scope the find
      // to the canPop=false one our page declares.
      final blockingPopScope = find.byWidgetPredicate(
        (w) => w is PopScope && w.canPop == false,
      );
      expect(
        blockingPopScope,
        findsOneWidget,
        reason: 'success page must block raw pops so we can clear send flow '
            'and route to wallet detail instead of stranding the user on '
            'the confirm page.',
      );
      final popScope = tester.widget<PopScope>(blockingPopScope);
      expect(popScope.onPopInvokedWithResult, isNotNull);
    },
  );
}
