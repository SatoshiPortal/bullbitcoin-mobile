import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/usecases/load_sp_wallet_data_usecase.dart';
import 'package:bb_mobile/features/sp/presentation/sp_cubit.dart';
import 'package:bb_mobile/features/sp/presentation/sp_state.dart';
import 'package:bb_mobile/features/sp/ui/screens/sp_receive_screen.dart';
import 'package:bb_mobile/core/widgets/inputs/copy_input.dart';
import 'package:bb_mobile/core/widgets/loading/loading_box_content.dart';
import 'package:bb_mobile/core/widgets/qr_display_widget.dart';
import 'package:bb_mobile/core/widgets/segment/segmented_full.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../sp_cubit_harness.dart';
import '../../sp_test_streams.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';

class _MockSpCubit extends Mock implements SpCubit {}

Widget _buildPage(SpCubit cubit) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: BlocProvider<SpCubit>.value(value: cubit, child: const SpReceiveScreen()),
);

Widget _buildMockPage(_MockSpCubit cubit) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: BlocProvider<SpCubit>.value(value: cubit, child: const SpReceiveScreen()),
);

void main() {
  late SpCubitHarness harness;
  late MockLoadSpWalletDataUsecase loadUsecase;
  late MockGenerateTaprootAddressUsecase generateUsecase;
  late SpCubit cubit;

  setUp(() {
    harness = SpCubitHarness();
    loadUsecase = harness.loadUsecase;
    generateUsecase = harness.generateUsecase;
    when(() => loadUsecase.execute()).thenAnswer(
      (_) async => Ok<SpWalletData, SpFailure>(
        spWalletData(spAddress: 'sp1qtestaddress'),
      ),
    );
    when(
      () => harness.watchUsecase.execute(),
    ).thenAnswer((_) => openSpNotificationStream());

    cubit = harness.build();
  });

  tearDown(() => cubit.close());

  testWidgets('renders Receive title', (tester) async {
    await tester.pumpWidget(_buildPage(cubit));

    expect(find.text('Receive'), findsOneWidget);
  });

  testWidgets('renders Silent Payment and Taproot tabs (no Segwit)', (
    tester,
  ) async {
    await tester.pumpWidget(_buildPage(cubit));

    expect(find.text('Silent Payment'), findsOneWidget);
    expect(find.text('Taproot'), findsOneWidget);
    expect(find.text('Segwit'), findsNothing);
  });

  testWidgets('shows manual scan callout on SP tab', (tester) async {
    await cubit.load();
    await tester.pumpWidget(_buildPage(cubit));
    await tester.pump();

    expect(find.text('Manual scan required'), findsOneWidget);
    expect(
      find.text('This address is reusable. Funds arrive after you tap Scan.'),
      findsOneWidget,
    );
  });

  testWidgets('SP tab shows the reusable address', (tester) async {
    await cubit.load();
    await tester.pumpWidget(_buildPage(cubit));
    await tester.pump();

    expect(find.byType(BBSegmentFull), findsOneWidget);
    expect(find.text('sp1qtestaddress'), findsOneWidget);
  });

  testWidgets('SP tab shows loading content without empty address widgets', (
    tester,
  ) async {
    final mockCubit = _MockSpCubit();
    when(() => mockCubit.state).thenReturn(const SpState(isLoading: true));
    when(() => mockCubit.stream).thenAnswer((_) => const Stream.empty());

    await tester.pumpWidget(_buildMockPage(mockCubit));
    await tester.pump();

    expect(find.byType(LoadingBoxContent), findsOneWidget);
    expect(find.byType(QrDisplayWidget), findsNothing);
    expect(find.byType(CopyInput), findsNothing);
  });

  testWidgets('SP tab empty address state does not render QR or copy input', (
    tester,
  ) async {
    final mockCubit = _MockSpCubit();
    when(() => mockCubit.state).thenReturn(const SpState());
    when(() => mockCubit.stream).thenAnswer((_) => const Stream.empty());

    await tester.pumpWidget(_buildMockPage(mockCubit));
    await tester.pump();

    expect(
      find.text(
        'Reusable address unavailable. Pull to refresh or reopen the wallet.',
      ),
      findsOneWidget,
    );
    expect(find.byType(QrDisplayWidget), findsNothing);
    expect(find.byType(CopyInput), findsNothing);
  });

  testWidgets(
    'Taproot tab initially shows a Generate address button (no address)',
    (tester) async {
      await tester.pumpWidget(_buildPage(cubit));
      await tester.pump();

      await tester.tap(find.text('Taproot'));
      await tester.pumpAndSettle();

      expect(find.text('Generate address'), findsOneWidget);
      // No address revealed yet.
      expect(find.text('bcrt1ptaprootnew'), findsNothing);
    },
  );

  testWidgets(
    'tapping Generate address calls the usecase and reveals the address',
    (tester) async {
      when(
        () => generateUsecase.execute(),
      ).thenAnswer((_) async => const Ok<String, SpFailure>('bcrt1ptaprootnew'));

      await tester.pumpWidget(_buildPage(cubit));
      await tester.pump();

      await tester.tap(find.text('Taproot'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Generate address'));
      await tester.pumpAndSettle();

      verify(() => generateUsecase.execute()).called(1);
      // The freshly generated address is rendered (QR + copy input).
      expect(find.text('bcrt1ptaprootnew'), findsWidgets);
      // Button now offers a fresh address.
      expect(find.text('Generate new address'), findsOneWidget);
    },
  );
}
