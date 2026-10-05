import 'package:bb_mobile/core/widgets/inputs/labeled_text_input.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_backend_defaults_usecase.dart';
import 'package:bb_mobile/features/sp/presentation/sp_backend_form.dart';
import 'package:bb_mobile/features/sp/presentation/sp_setup_cubit.dart';
import 'package:bb_mobile/features/sp/domain/usecases/test_sp_backend_usecase.dart';
import 'package:bb_mobile/features/sp/presentation/sp_connection_status.dart';
import 'package:bb_mobile/features/sp/presentation/sp_setup_state.dart';
import 'package:bb_mobile/features/sp/ui/screens/sp_setup_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// bloc_test is not a dependency in this repo, so we build the mock directly on
// mocktail's Mock and stub the BlocBase surface (state + stream + close) that
// BlocProvider/BlocConsumer rely on.
class _MockSpSetupCubit extends Mock implements SpSetupCubit {}

class _FakeSpSetupCubit extends Cubit<SpSetupState> implements SpSetupCubit {
  _FakeSpSetupCubit(super.initialState);

  // Drives a programmatic state change (defaults landing, network switch) so a
  // test can assert the URL fields follow the state.
  void pushState(SpSetupState state) => emit(state);

  @override
  Future<void> create() async {}

  @override
  Future<void> fetchRegtestDefaults() async {}

  @override
  void setBlindbitUrl(String url) {}

  @override
  void setElectrumUrl(String url) {}

  @override
  Future<void> setNetwork(BitcoinNetwork n) async {}

  @override
  void setScanStart(SpScanStart scanStart) =>
      emit(state.copyWith(scanStart: scanStart));

  @override
  Future<void> testBlindbit() async {}

  @override
  Future<void> testElectrum() async {}

  @override
  TestSpBackendUsecase get backendTestUsecase => throw UnimplementedError();

  @override
  GetSpBackendDefaultsUsecase get getBackendDefaultsUsecase =>
      throw UnimplementedError();
}

Widget _buildPage(_FakeSpSetupCubit cubit) => MaterialApp(
  theme: AppTheme.themeData(AppThemeType.light),
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: BlocProvider<SpSetupCubit>.value(
    value: cubit,
    child: const SpSetupScreen(successRedirectPath: '/wallet'),
  ),
);

void main() {
  group('SpSetupScreen', () {
    testWidgets('renders title and Create button', (tester) async {
      final cubit = _FakeSpSetupCubit(
        const SpSetupState(
          form: SpBackendForm(
            blindbitUrl: 'http://b.local',
            electrumUrl: 'tcp://e.local:1',
          ),
        ),
      );

      await tester.pumpWidget(_buildPage(cubit));

      expect(find.text('Create Silent Payments Wallet'), findsOneWidget);
      expect(find.text('Create'), findsOneWidget);
    });

    testWidgets('renders network dropdown', (tester) async {
      final cubit = _FakeSpSetupCubit(const SpSetupState());

      await tester.pumpWidget(_buildPage(cubit));

      expect(
        find.byType(DropdownButtonFormField<BitcoinNetwork>),
        findsOneWidget,
      );
    });

    testWidgets('shows Fetch defaults button for regtest network', (
      tester,
    ) async {
      final cubit = _FakeSpSetupCubit(
        const SpSetupState(
          form: SpBackendForm(network: BitcoinNetwork.regtest),
        ),
      );

      await tester.pumpWidget(_buildPage(cubit));

      expect(find.text('Fetch regtest defaults'), findsOneWidget);
    });

    testWidgets('hides Fetch defaults button for bitcoin network', (
      tester,
    ) async {
      final cubit = _FakeSpSetupCubit(
        const SpSetupState(
          form: SpBackendForm(network: BitcoinNetwork.mainnet),
        ),
      );

      await tester.pumpWidget(_buildPage(cubit));

      expect(find.text('Fetch regtest defaults'), findsNothing);
    });

    testWidgets('shows progress indicator when isCreating', (tester) async {
      final cubit = _FakeSpSetupCubit(const SpSetupState(isCreating: true));

      await tester.pumpWidget(_buildPage(cubit));

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('shows progress indicator when isFetchingDefaults', (
      tester,
    ) async {
      final cubit = _FakeSpSetupCubit(
        const SpSetupState(
          form: SpBackendForm(
            network: BitcoinNetwork.regtest,
            isFetchingDefaults: true,
          ),
        ),
      );

      await tester.pumpWidget(_buildPage(cubit));

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error banner when error is non-null', (tester) async {
      final cubit = _FakeSpSetupCubit(
        const SpSetupState(
          form: SpBackendForm(error: SpUnexpected('diagnostic detail')),
        ),
      );

      await tester.pumpWidget(_buildPage(cubit));

      // The catch-all failure renders the generic localized message, never the
      // raw logMessage.
      expect(find.text('Oops! Something went wrong'), findsOneWidget);
    });

    testWidgets('shows two text inputs for the URLs', (tester) async {
      final cubit = _FakeSpSetupCubit(const SpSetupState());

      await tester.pumpWidget(_buildPage(cubit));

      expect(find.byType(LabeledTextInput), findsNWidgets(2));
    });

    testWidgets('the URL inputs stay on one line', (tester) async {
      final cubit = _FakeSpSetupCubit(const SpSetupState());

      await tester.pumpWidget(_buildPage(cubit));

      // Left unbounded the fields wrap and grow as the URL gets longer.
      final inputs = tester.widgetList<LabeledTextInput>(
        find.byType(LabeledTextInput),
      );
      expect(inputs.map((input) => input.maxLines), everyElement(1));
    });

    testWidgets('URL fields fill when defaults land programmatically', (
      tester,
    ) async {
      final cubit = _FakeSpSetupCubit(
        const SpSetupState(form: SpBackendForm(isFetchingDefaults: true)),
      );

      await tester.pumpWidget(_buildPage(cubit));
      expect(
        find.widgetWithText(LabeledTextInput, 'http://b.default'),
        findsNothing,
      );

      cubit.pushState(
        const SpSetupState(
          form: SpBackendForm(
            blindbitUrl: 'http://b.default',
            electrumUrl: 'tcp://e.default:1',
          ),
        ),
      );
      await tester.pump();

      expect(
        find.widgetWithText(LabeledTextInput, 'http://b.default'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(LabeledTextInput, 'tcp://e.default:1'),
        findsOneWidget,
      );
    });

    testWidgets('URL fields follow a network switch', (tester) async {
      final cubit = _FakeSpSetupCubit(
        const SpSetupState(
          form: SpBackendForm(
            network: BitcoinNetwork.regtest,
            blindbitUrl: 'http://regtest.blindbit',
            electrumUrl: 'tcp://regtest.electrum:1',
          ),
        ),
      );

      await tester.pumpWidget(_buildPage(cubit));
      expect(
        find.widgetWithText(LabeledTextInput, 'http://regtest.blindbit'),
        findsOneWidget,
      );

      cubit.pushState(
        const SpSetupState(
          form: SpBackendForm(
            network: BitcoinNetwork.mainnet,
            blindbitUrl: 'http://bitcoin.blindbit',
            electrumUrl: 'ssl://bitcoin.electrum:2',
          ),
        ),
      );
      await tester.pump();

      expect(
        find.widgetWithText(LabeledTextInput, 'http://regtest.blindbit'),
        findsNothing,
      );
      expect(
        find.widgetWithText(LabeledTextInput, 'http://bitcoin.blindbit'),
        findsOneWidget,
      );
    });

    testWidgets('Create button is visible', (tester) async {
      final cubit = _FakeSpSetupCubit(
        const SpSetupState(
          form: SpBackendForm(
            blindbitUrl: 'http://b.local',
            electrumUrl: 'tcp://e.local:1',
          ),
        ),
      );

      await tester.pumpWidget(_buildPage(cubit));

      expect(find.text('Create'), findsOneWidget);
    });
  });

  group('SpSetupScreen interactions', () {
    late _MockSpSetupCubit cubit;

    setUpAll(() {
      registerFallbackValue(BitcoinNetwork.regtest);
    });

    Widget buildMockPage(_MockSpSetupCubit c) => MaterialApp(
      theme: AppTheme.themeData(AppThemeType.light),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider<SpSetupCubit>.value(
        value: c,
        child: const SpSetupScreen(successRedirectPath: '/wallet'),
      ),
    );

    void seed(SpSetupState state) {
      when(() => cubit.state).thenReturn(state);
      when(
        () => cubit.stream,
      ).thenAnswer((_) => const Stream<SpSetupState>.empty());
    }

    setUp(() {
      cubit = _MockSpSetupCubit();
      when(() => cubit.close()).thenAnswer((_) async {});
      when(() => cubit.create()).thenAnswer((_) async {});
      when(() => cubit.fetchRegtestDefaults()).thenAnswer((_) async {});
      when(() => cubit.setNetwork(any())).thenAnswer((_) async {});
      when(() => cubit.setBlindbitUrl(any())).thenReturn(null);
      when(() => cubit.setElectrumUrl(any())).thenReturn(null);
    });

    testWidgets('tapping Create calls cubit.create() once', (tester) async {
      // Create button is only enabled when both URLs are non-empty and tested.
      seed(
        const SpSetupState(
          form: SpBackendForm(
            blindbitUrl: 'http://b.local',
            electrumUrl: 'tcp://e.local:1',
            blindbitStatus: SpConnectionStatus.ok,
            electrumStatus: SpConnectionStatus.ok,
          ),
        ),
      );

      await tester.pumpWidget(buildMockPage(cubit));

      expect(find.text('Create'), findsOneWidget);
      // The themed form is taller than the test surface, so Create starts
      // below the fold.
      await tester.ensureVisible(find.text('Create'));
      await tester.tap(find.text('Create'));
      await tester.pump();

      verify(() => cubit.create()).called(1);
    });

    testWidgets('typing in Blindbit field calls setBlindbitUrl', (
      tester,
    ) async {
      seed(const SpSetupState());

      await tester.pumpWidget(buildMockPage(cubit));

      final field = find.widgetWithText(LabeledTextInput, 'Blindbit URL');
      expect(field, findsOneWidget);
      await tester.enterText(field, 'http://typed.blindbit');

      verify(() => cubit.setBlindbitUrl('http://typed.blindbit')).called(1);
    });

    testWidgets('typing in Electrum field calls setElectrumUrl', (
      tester,
    ) async {
      seed(const SpSetupState());

      await tester.pumpWidget(buildMockPage(cubit));

      final field = find.widgetWithText(LabeledTextInput, 'Electrum URL');
      expect(field, findsOneWidget);
      await tester.enterText(field, 'tcp://typed.electrum:50001');

      verify(
        () => cubit.setElectrumUrl('tcp://typed.electrum:50001'),
      ).called(1);
    });

    testWidgets('selecting a network calls cubit.setNetwork', (tester) async {
      seed(
        const SpSetupState(
          form: SpBackendForm(network: BitcoinNetwork.regtest),
        ),
      );

      await tester.pumpWidget(buildMockPage(cubit));

      expect(
        find.byType(DropdownButtonFormField<BitcoinNetwork>),
        findsOneWidget,
      );
      await tester.tap(find.byType(DropdownButtonFormField<BitcoinNetwork>));
      await tester.pumpAndSettle();

      // The dropdown menu lists every network; pick one that differs from
      // the current selection. Menu items render the network name as text.
      await tester.tap(find.text(BitcoinNetwork.mainnet.name).last);
      await tester.pumpAndSettle();

      verify(() => cubit.setNetwork(BitcoinNetwork.mainnet)).called(1);
    });

    testWidgets('tapping Fetch regtest defaults calls fetchRegtestDefaults', (
      tester,
    ) async {
      seed(
        const SpSetupState(
          form: SpBackendForm(network: BitcoinNetwork.regtest),
        ),
      );

      await tester.pumpWidget(buildMockPage(cubit));

      expect(find.text('Fetch regtest defaults'), findsOneWidget);
      await tester.tap(find.text('Fetch regtest defaults'));
      await tester.pump();

      verify(() => cubit.fetchRegtestDefaults()).called(1);
    });
  });
}
