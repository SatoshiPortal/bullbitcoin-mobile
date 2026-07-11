import 'package:bb_mobile/features/sp/domain/usecases/get_sp_balance_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_network_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/prepare_sp_payment_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/send_sp_payment_usecase.dart';
import 'package:bb_mobile/features/sp/presentation/sp_send_cubit.dart';
import 'package:bb_mobile/features/sp/ui/screens/sp_send_recipient_page.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPrepareSpPaymentUsecase extends Mock
    implements PrepareSpPaymentUsecase {}

class _MockSendSpPaymentUsecase extends Mock implements SendSpPaymentUsecase {}

class _MockGetSpNetworkUsecase extends Mock implements GetSpNetworkUsecase {}

class _MockGetSpBalanceUsecase extends Mock implements GetSpBalanceUsecase {}

Widget _buildPage(SpSendCubit cubit) => MaterialApp(
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: BlocProvider<SpSendCubit>.value(
    value: cubit,
    child: const SpSendRecipientPage(),
  ),
);

void main() {
  late SpSendCubit cubit;

  setUp(() {
    cubit = SpSendCubit(
      prepareSpPaymentUsecase: _MockPrepareSpPaymentUsecase(),
      sendSpPaymentUsecase: _MockSendSpPaymentUsecase(),
      getSpNetworkUsecase: _MockGetSpNetworkUsecase(),
      getSpBalanceUsecase: _MockGetSpBalanceUsecase(),
    );
  });

  tearDown(() => cubit.close());

  testWidgets('renders Send title', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildPage(cubit));
    await tester.pumpAndSettle();

    expect(find.text('Send'), findsOneWidget);
  });

  testWidgets('shows recipient address input hint', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildPage(cubit));
    await tester.pumpAndSettle();

    expect(
      find.text('Silent payment address or Bitcoin address'),
      findsOneWidget,
    );
  });

  testWidgets('shows Continue button', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildPage(cubit));
    await tester.pumpAndSettle();

    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('shows SP badge for sp1 address', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildPage(cubit));
    await tester.pumpAndSettle();

    // Enter a silent payment address
    await tester.enterText(find.byType(TextField), 'sp1qabcdef');
    await tester.pump();

    expect(find.text('Silent Payment'), findsOneWidget);
  });

  testWidgets('shows Bitcoin Address badge for bc1 address', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildPage(cubit));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'bc1qabcdef');
    await tester.pump();

    expect(find.text('Bitcoin Address'), findsOneWidget);
  });

  testWidgets('shows Unrecognized badge for unknown input', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildPage(cubit));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'xyz_not_an_address');
    await tester.pump();

    expect(find.text('Unrecognized'), findsOneWidget);
  });
}
