import 'package:bb_mobile/features/sp/domain/entities/sp_network.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_backend_defaults_usecase.dart';
import 'package:bb_mobile/features/sp/presentation/sp_setup_cubit.dart';
import 'package:bb_mobile/features/sp/domain/usecases/test_sp_backend_usecase.dart';
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

  @override
  Future<void> create() async {}

  @override
  Future<void> fetchRegtestDefaults() async {}

  @override
  void setBlindbitUrl(String url) {}

  @override
  void setElectrumUrl(String url) {}

  @override
  Future<void> setNetwork(SpNetwork n) async {}

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
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: BlocProvider<SpSetupCubit>.value(
    value: cubit,
    child: const SpSetupScreen(),
  ),
);

void main() {
  group('SpSetupScreen', () {
    testWidgets('renders title and Create button', (tester) async {
      final cubit = _FakeSpSetupCubit(
        const SpSetupState(
          blindbitUrl: 'http://b.local',
          electrumUrl: 'tcp://e.local:1',
        ),
      );

      await tester.pumpWidget(_buildPage(cubit));

      expect(find.text('Create SP Wallet'), findsOneWidget);
      expect(find.text('Create'), findsOneWidget);
    });

    testWidgets('renders network dropdown', (tester) async {
      final cubit = _FakeSpSetupCubit(const SpSetupState());

      await tester.pumpWidget(_buildPage(cubit));

      expect(find.byType(DropdownButtonFormField<SpNetwork>), findsOneWidget);
    });

    testWidgets('shows Fetch defaults button for regtest network', (
      tester,
    ) async {
      final cubit = _FakeSpSetupCubit(
        const SpSetupState(network: SpNetwork.regtest),
      );

      await tester.pumpWidget(_buildPage(cubit));

      expect(find.text('Fetch regtest defaults'), findsOneWidget);
    });

    testWidgets('hides Fetch defaults button for bitcoin network', (
      tester,
    ) async {
      final cubit = _FakeSpSetupCubit(
        const SpSetupState(network: SpNetwork.bitcoin),
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
          network: SpNetwork.regtest,
          isFetchingDefaults: true,
        ),
      );

      await tester.pumpWidget(_buildPage(cubit));

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error banner when error is non-null', (tester) async {
      final cubit = _FakeSpSetupCubit(
        const SpSetupState(error: SpUnexpected('diagnostic detail')),
      );

      await tester.pumpWidget(_buildPage(cubit));

      // The catch-all failure renders the generic localized message, never the
      // raw logMessage.
      expect(find.text('Oops! Something went wrong'), findsOneWidget);
    });

    testWidgets('shows two TextFormFields for URL inputs', (tester) async {
      final cubit = _FakeSpSetupCubit(const SpSetupState());

      await tester.pumpWidget(_buildPage(cubit));

      expect(find.byType(TextFormField), findsNWidgets(2));
    });

    testWidgets('Create button is visible', (tester) async {
      final cubit = _FakeSpSetupCubit(
        const SpSetupState(
          blindbitUrl: 'http://b.local',
          electrumUrl: 'tcp://e.local:1',
        ),
      );

      await tester.pumpWidget(_buildPage(cubit));

      expect(find.text('Create'), findsOneWidget);
    });
  });

  group('SpSetupScreen interactions', () {
    late _MockSpSetupCubit cubit;

    setUpAll(() {
      registerFallbackValue(SpNetwork.regtest);
    });

    Widget buildMockPage(_MockSpSetupCubit c) => MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider<SpSetupCubit>.value(
        value: c,
        child: const SpSetupScreen(),
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
          blindbitUrl: 'http://b.local',
          electrumUrl: 'tcp://e.local:1',
          blindbitTest: SpConnTest.ok,
          electrumTest: SpConnTest.ok,
        ),
      );

      await tester.pumpWidget(buildMockPage(cubit));

      expect(find.text('Create'), findsOneWidget);
      await tester.tap(find.text('Create'));
      await tester.pump();

      verify(() => cubit.create()).called(1);
    });

    testWidgets('typing in Blindbit field calls setBlindbitUrl', (
      tester,
    ) async {
      seed(const SpSetupState());

      await tester.pumpWidget(buildMockPage(cubit));

      final field = find.byKey(ValueKey('blindbit_${SpNetwork.regtest.name}'));
      expect(field, findsOneWidget);
      await tester.enterText(field, 'http://typed.blindbit');

      verify(() => cubit.setBlindbitUrl('http://typed.blindbit')).called(1);
    });

    testWidgets('typing in Electrum field calls setElectrumUrl', (
      tester,
    ) async {
      seed(const SpSetupState());

      await tester.pumpWidget(buildMockPage(cubit));

      final field = find.byKey(ValueKey('electrum_${SpNetwork.regtest.name}'));
      expect(field, findsOneWidget);
      await tester.enterText(field, 'tcp://typed.electrum:50001');

      verify(
        () => cubit.setElectrumUrl('tcp://typed.electrum:50001'),
      ).called(1);
    });

    testWidgets('selecting a network calls cubit.setNetwork', (tester) async {
      seed(const SpSetupState(network: SpNetwork.regtest));

      await tester.pumpWidget(buildMockPage(cubit));

      expect(find.byType(DropdownButtonFormField<SpNetwork>), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<SpNetwork>));
      await tester.pumpAndSettle();

      // The dropdown menu lists every network; pick one that differs from
      // the current selection. Menu items render the network name as text.
      await tester.tap(find.text(SpNetwork.bitcoin.name).last);
      await tester.pumpAndSettle();

      verify(() => cubit.setNetwork(SpNetwork.bitcoin)).called(1);
    });

    testWidgets('tapping Fetch regtest defaults calls fetchRegtestDefaults', (
      tester,
    ) async {
      seed(const SpSetupState(network: SpNetwork.regtest));

      await tester.pumpWidget(buildMockPage(cubit));

      expect(find.text('Fetch regtest defaults'), findsOneWidget);
      await tester.tap(find.text('Fetch regtest defaults'));
      await tester.pump();

      verify(() => cubit.fetchRegtestDefaults()).called(1);
    });
  });
}
