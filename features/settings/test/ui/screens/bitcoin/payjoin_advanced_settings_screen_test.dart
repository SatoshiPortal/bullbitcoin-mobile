import 'package:bull_ui/app_theme.dart';
import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:settings/testing.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSettingsCubit extends Mock implements SettingsCubit {}

Widget _buildPage(SettingsCubit settingsCubit) => MaterialApp(
  theme: AppTheme.themeData(AppThemeType.light),
  localizationsDelegates: settingsTestLocalizationsDelegates,
  supportedLocales: SettingsLocalizations.supportedLocales,
  home: BlocProvider<SettingsCubit>.value(
    value: settingsCubit,
    child: const PayjoinAdvancedSettingsScreen(),
  ),
);

/// Every semantics node reachable from the root, merged nodes included.
List<SemanticsNode> _semanticsNodes(WidgetTester tester) {
  final nodes = <SemanticsNode>[];
  for (final view in tester.binding.renderViews) {
    final root = view.owner?.semanticsOwner?.rootSemanticsNode;
    if (root == null) continue;
    void visit(SemanticsNode node) {
      nodes.add(node);
      node.visitChildren((child) {
        visit(child);
        return true;
      });
    }

    visit(root);
  }
  return nodes;
}

/// The field must be the one node named [title]: the caption is its name, not
/// a separate text announced beside an unnamed edit box.
void _expectFieldLabelled(
  WidgetTester tester, {
  required String title,
  required String value,
}) {
  final matches = _semanticsNodes(tester)
      .where((node) => node.getSemanticsData().label == title)
      .toList();
  expect(matches, hasLength(1), reason: '"$title" must be announced once');
  final data = matches.single.getSemanticsData();
  expect(
    data.flagsCollection.isTextField,
    isTrue,
    reason: '"$title" must name the editable field itself',
  );
  expect(data.value, value);
}

void main() {
  late _MockSettingsCubit settingsCubit;

  Finder minAmountField() => find.byType(TextField).at(0);
  Finder expiryField() => find.byType(TextField).at(1);

  setUp(() {
    settingsCubit = _MockSettingsCubit();
    when(() => settingsCubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => settingsCubit.state)
        .thenReturn(SettingsState(payjoinPolicy: PayjoinPolicy.defaults()));
    when(() => settingsCubit.setPayjoinMinAmount(any()))
        .thenAnswer((_) async {});
    when(() => settingsCubit.setPayjoinExpireAfterSec(any()))
        .thenAnswer((_) async {});
  });

  testWidgets('shows the stored expiry in minutes with its units', (
    tester,
  ) async {
    await tester.pumpWidget(_buildPage(settingsCubit));

    expect(find.text('1440'), findsOneWidget);
    expect(find.text('10000'), findsOneWidget);
    expect(find.text('min'), findsOneWidget);
    expect(find.text('sats'), findsOneWidget);
  });

  testWidgets('rounds a stored expiry that is not whole minutes', (
    tester,
  ) async {
    when(() => settingsCubit.state).thenReturn(
      SettingsState(
        payjoinPolicy: PayjoinPolicy.defaults().copyWith(
          sessionLifetime: const Duration(seconds: 90),
        ),
      ),
    );

    await tester.pumpWidget(_buildPage(settingsCubit));

    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('saves an expiry typed in minutes as seconds', (tester) async {
    await tester.pumpWidget(_buildPage(settingsCubit));

    await tester.enterText(expiryField(), '30');
    await tester.pump(const Duration(seconds: 1));

    verify(() => settingsCubit.setPayjoinExpireAfterSec(1800)).called(1);
  });

  testWidgets('rejects an expiry above 24 hours', (tester) async {
    await tester.pumpWidget(_buildPage(settingsCubit));

    await tester.enterText(expiryField(), '1441');
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Must be between 1 and 1440 minutes'), findsOneWidget);
    verifyNever(() => settingsCubit.setPayjoinExpireAfterSec(any()));
  });

  testWidgets('keeps only digits in the minimum amount', (tester) async {
    await tester.pumpWidget(_buildPage(settingsCubit));

    await tester.enterText(minAmountField(), '-12.5,00');
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('12500'), findsOneWidget);
    verify(() => settingsCubit.setPayjoinMinAmount(12500)).called(1);
  });

  /// The semantics handle is disposed inside the test body: the end-of-test
  /// check runs before teardown callbacks.
  Future<void> withSemantics(
    WidgetTester tester,
    Future<void> Function() body,
  ) async {
    final handle = tester.ensureSemantics();
    try {
      await body();
    } finally {
      handle.dispose();
    }
  }

  testWidgets('names the minimum amount field with its title', (tester) async {
    await withSemantics(tester, () async {
      await tester.pumpWidget(_buildPage(settingsCubit));
      await tester.pump();

      _expectFieldLabelled(tester, title: 'Minimum amount', value: '10000');
    });
  });

  testWidgets('names the session expiry field with its title', (tester) async {
    await withSemantics(tester, () async {
      await tester.pumpWidget(_buildPage(settingsCubit));
      await tester.pump();

      _expectFieldLabelled(tester, title: 'Session expiry', value: '1440');
    });
  });
}
