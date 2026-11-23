import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/sp/presentation/sp_cubit.dart';
import 'package:bb_mobile/features/sp/presentation/sp_state.dart';
import 'package:bb_mobile/features/sp/ui/screens/sp_receive_screen.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullQrCode, BullSegmented, BullShimmerBox, BullViewerActionButton;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../sp_cubit_harness.dart';
import '../../sp_test_streams.dart';

import 'package:bb_mobile/localizations.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_wallet_data.dart';

class _MockSpCubit extends Mock implements SpCubit {}

Widget _buildPage(SpCubit cubit) => MaterialApp(
  theme: AppTheme.themeData(AppThemeType.light),
  localizationsDelegates: appLocalizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: BlocProvider<SpCubit>.value(
    value: cubit,
    child: const SpReceiveScreen(),
  ),
);

Widget _buildMockPage(_MockSpCubit cubit) => MaterialApp(
  theme: AppTheme.themeData(AppThemeType.light),
  localizationsDelegates: appLocalizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: BlocProvider<SpCubit>.value(
    value: cubit,
    child: const SpReceiveScreen(),
  ),
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
    when(() => harness.watchUsecase.execute())
        .thenAnswer((_) => openSpNotificationStream());

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

    expect(find.byType(BullSegmented), findsOneWidget);
    expect(find.text('sp1qtestaddress'), findsOneWidget);
  });

  testWidgets('opens the full address and copies from either surface', (
    tester,
  ) async {
    final address = 'sp1q'.padRight(95, 'q');
    final mockCubit = _MockSpCubit();
    when(() => mockCubit.state).thenReturn(SpState(spAddress: address));
    when(() => mockCubit.stream).thenAnswer((_) => const Stream.empty());
    final copied = <String>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map<Object?, Object?>)['text'] as String);
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await tester.pumpWidget(_buildMockPage(mockCubit));
    await tester.pumpAndSettle();
    final loc = AppLocalizations.of(
      tester.element(find.byType(SpReceiveScreen)),
    );
    final preview = find.widgetWithText(SelectableText, address);
    final closeLabel = MaterialLocalizations.of(
      tester.element(find.byType(SpReceiveScreen)),
    ).closeButtonLabel;
    final close = find.widgetWithText(BullViewerActionButton, closeLabel);
    await tester.tap(find.text(address));
    await tester.pumpAndSettle();
    expect(preview, findsOneWidget);

    await tester.tap(
      find.widgetWithText(BullViewerActionButton, loc.copyDialogButton),
    );
    await tester.pumpAndSettle();
    expect(copied, [address]);
    expect(preview, findsNothing);
    expect(find.text(loc.copiedToClipboard), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    final viewAction = find.byTooltip(loc.receiveViewDetails);
    expect(tester.getSize(viewAction).shortestSide, greaterThanOrEqualTo(48));
    await tester.tap(viewAction);
    await tester.pumpAndSettle();
    expect(preview, findsOneWidget);
    await tester.tap(close);
    await tester.pumpAndSettle();

    final copyAction = find.byTooltip(loc.copyDialogButton);
    expect(tester.getSize(copyAction).shortestSide, greaterThanOrEqualTo(48));
    await tester.tap(copyAction);
    await tester.pumpAndSettle();
    expect(copied, [address, address]);
    expect(find.text(loc.copiedToClipboard), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });

  testWidgets('SP tab shows loading content without empty address widgets', (
    tester,
  ) async {
    final mockCubit = _MockSpCubit();
    when(() => mockCubit.state).thenReturn(const SpState(isLoading: true));
    when(() => mockCubit.stream).thenAnswer((_) => const Stream.empty());

    await tester.pumpWidget(_buildMockPage(mockCubit));
    await tester.pump();

    expect(find.byType(BullShimmerBox), findsOneWidget);
    expect(find.byType(BullQrCode), findsNothing);
    expect(find.byIcon(Icons.copy_sharp), findsNothing);
    expect(find.byIcon(Icons.visibility_outlined), findsNothing);
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
    expect(find.byType(BullQrCode), findsNothing);
    expect(find.byIcon(Icons.copy_sharp), findsNothing);
    expect(find.byIcon(Icons.visibility_outlined), findsNothing);
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
      when(() => generateUsecase.execute()).thenAnswer(
        (_) async => const Ok<String, SpFailure>('bcrt1ptaprootnew'),
      );

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
