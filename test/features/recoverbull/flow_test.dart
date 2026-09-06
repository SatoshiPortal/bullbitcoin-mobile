import 'package:bb_mobile/core/recoverbull/domain/repositories/recoverbull_repository.dart';
import 'package:bb_mobile/core/recoverbull/recoverbull_locator.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/recoverbull/flow.dart';
import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:bb_mobile/features/recoverbull/ui/pages/connecting_page.dart';
import 'package:bb_mobile/features/recoverbull/ui/pages/settings_page.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Repository extends Mock implements RecoverBullRepository {}

class _Bloc extends Fake implements RecoverBullBloc {
  _Bloc(RecoverBullFlow flow) : state = RecoverBullState(flow: flow);

  @override
  final RecoverBullState state;
  final events = <RecoverBullEvent>[];

  @override
  Stream<RecoverBullState> get stream => const Stream.empty();

  @override
  void add(RecoverBullEvent event) => events.add(event);
}

void main() {
  setUp(() {
    final repository = _Repository();
    when(
      repository.fetchUrl,
    ).thenAnswer((_) async => Uri.parse('https://example.com'));
    locator.registerSingleton<RecoverBullRepository>(repository);
    RecoverbullLocator.registerUsecases(locator);
  });
  tearDown(locator.reset);

  for (final flow in RecoverBullFlow.values) {
    testWidgets('$flow mounts and initializes at most once', (tester) async {
      final bloc = _Bloc(flow);
      Widget app() => MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            Device.init(context);
            return BlocProvider<RecoverBullBloc>.value(
              value: bloc,
              child: const RecoverBullFlowNavigator(),
            );
          },
        ),
      );
      await tester.pumpWidget(app());
      await tester.pump();
      await tester.pumpWidget(app());
      await tester.pump();
      expect(tester.takeException(), isNull);
      if (flow == RecoverBullFlow.settings) {
        expect(find.byType(SettingsPage), findsOneWidget);
        expect(bloc.events, isEmpty);
      } else {
        expect(find.byType(ConnectingPage), findsOneWidget);
        expect(bloc.events, [isA<OnTorInitialization>()]);
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
}
