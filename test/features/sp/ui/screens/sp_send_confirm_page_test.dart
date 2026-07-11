import 'package:bb_mobile/features/sp/domain/entities/sp_coin.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_recipient.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_tx_draft.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_balance_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_network_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/prepare_sp_payment_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/send_sp_payment_usecase.dart';
import 'package:bb_mobile/features/sp/presentation/sp_send_cubit.dart';
import 'package:bb_mobile/features/sp/presentation/sp_send_state.dart';
import 'package:bb_mobile/features/sp/ui/screens/sp_send_confirm_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';

class _MockPrepareSpPaymentUsecase extends Mock
    implements PrepareSpPaymentUsecase {}

class _MockSendSpPaymentUsecase extends Mock implements SendSpPaymentUsecase {}

class _MockGetSpNetworkUsecase extends Mock implements GetSpNetworkUsecase {}

class _MockGetSpBalanceUsecase extends Mock implements GetSpBalanceUsecase {}

// Exposes emit for testing
class _TestSpSendCubit extends SpSendCubit {
  _TestSpSendCubit({
    required super.prepareSpPaymentUsecase,
    required super.sendSpPaymentUsecase,
    required super.getSpNetworkUsecase,
    required super.getSpBalanceUsecase,
  });

  void emitTestState(SpSendState state) => emit(state);
}

Widget _buildPage(_TestSpSendCubit cubit) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: BlocProvider<SpSendCubit>.value(
    value: cubit,
    child: const SpSendConfirmPage(),
  ),
);

void main() {
  setUpAll(() {
    registerFallbackValue(<SpRecipient>[]);
    registerFallbackValue(BigInt.zero);
  });

  late _TestSpSendCubit cubit;

  final fakeTxSimulation = SpTxDraft(
    id: '0',
    inputs: [
      SpCoin(
        source: SpCoinSource.segwit,
        outpoint: 'abc123:0',
        amountSat: BigInt.from(10000),
        status: SpCoinStatus.unspent,
      ),
    ],
    outputs: [],
    feeSat: BigInt.from(200),
    changeSat: BigInt.from(4800),
  );

  setUp(() {
    cubit = _TestSpSendCubit(
      prepareSpPaymentUsecase: _MockPrepareSpPaymentUsecase(),
      sendSpPaymentUsecase: _MockSendSpPaymentUsecase(),
      getSpNetworkUsecase: _MockGetSpNetworkUsecase(),
      getSpBalanceUsecase: _MockGetSpBalanceUsecase(),
    );
  });

  tearDown(() => cubit.close());

  testWidgets('renders Confirm title', (tester) async {
    await tester.pumpWidget(_buildPage(cubit));

    expect(find.text('Confirm'), findsOneWidget);
  });

  testWidgets('shows Sign and Broadcast button', (tester) async {
    await tester.pumpWidget(_buildPage(cubit));

    expect(find.text('Sign & Broadcast'), findsOneWidget);
  });

  testWidgets('shows amount from state', (tester) async {
    cubit.emitTestState(
      SpSendState(
        amountSat: BigInt.from(5000),
        recipient: SpRecipientStandard(
          address: 'bc1qtestrecipient',
          amountSat: BigInt.from(5000),
          isMax: false,
        ),
        txSimulation: fakeTxSimulation,
      ),
    );
    await tester.pumpWidget(_buildPage(cubit));
    await tester.pump();

    expect(find.textContaining('5 000 sats'), findsWidgets);
  });

  testWidgets('shows input source badge in inputs section', (tester) async {
    cubit.emitTestState(
      SpSendState(
        amountSat: BigInt.from(5000),
        recipient: SpRecipientStandard(
          address: 'bc1qtestrecipient',
          amountSat: BigInt.from(5000),
          isMax: false,
        ),
        txSimulation: fakeTxSimulation,
      ),
    );
    await tester.pumpWidget(_buildPage(cubit));
    await tester.pump();

    // Inputs section header is visible
    expect(find.textContaining('Inputs'), findsOneWidget);
  });

  testWidgets('shows fee row', (tester) async {
    cubit.emitTestState(
      SpSendState(
        amountSat: BigInt.from(5000),
        txSimulation: fakeTxSimulation,
      ),
    );
    await tester.pumpWidget(_buildPage(cubit));
    await tester.pump();

    expect(find.text('Fee'), findsOneWidget);
  });
}
