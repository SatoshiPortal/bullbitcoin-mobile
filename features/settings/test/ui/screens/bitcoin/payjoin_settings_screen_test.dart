import 'dart:ui' show Tristate;

import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:flutter/rendering.dart' show SemanticsAction, SemanticsNode;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:settings/testing.dart';

class _MockSettingsCubit extends Mock implements SettingsCubit {}

Widget _buildPage(SettingsCubit settingsCubit) => MaterialApp(
  theme: AppTheme.themeData(AppThemeType.light),
  localizationsDelegates: settingsTestLocalizationsDelegates,
  supportedLocales: SettingsLocalizations.supportedLocales,
  home: BlocProvider<SettingsCubit>.value(
    value: settingsCubit,
    child: const PayjoinSettingsScreen(),
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

/// The single node carrying [label]: the caption names the control, never a
/// caption node announced beside an unnamed switch.
SemanticsNode _nodeLabelled(WidgetTester tester, String label) =>
    _semanticsNodes(tester)
        .singleWhere((node) => node.getSemanticsData().label == label);

const _captions = {
  PayjoinAction.send: 'Send',
  PayjoinAction.receive: 'Receive',
  PayjoinAction.buy: 'Buy',
  PayjoinAction.sell: 'Sell and pay bills',
};

void main() {
  late _MockSettingsCubit settingsCubit;

  setUp(() {
    settingsCubit = _MockSettingsCubit();
    when(() => settingsCubit.stream).thenAnswer((_) => const Stream.empty());
  });

  Future<void> pumpWithPolicy(WidgetTester tester, PayjoinPolicy policy) async {
    when(() => settingsCubit.state)
        .thenReturn(SettingsState(payjoinPolicy: policy));
    await tester.pumpWidget(_buildPage(settingsCubit));
    await tester.pump();
  }

  /// Runs [body] with the semantics tree enabled, disposing the handle inside
  /// the test body: the end-of-test check runs before the teardown callbacks.
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

  testWidgets('names each payjoin switch with its caption and its state', (
    tester,
  ) async {
    await withSemantics(tester, () async {
      await pumpWithPolicy(tester, PayjoinPolicy.defaults());

      for (final MapEntry(key: action, value: caption) in _captions.entries) {
        final data = _nodeLabelled(tester, caption).getSemanticsData();
        expect(
          data.flagsCollection.isToggled,
          PayjoinPolicy.defaults().allows(action)
              ? Tristate.isTrue
              : Tristate.isFalse,
          reason: '$caption must expose the stored state',
        );
        expect(
          data.hasAction(SemanticsAction.tap),
          isTrue,
          reason: '$caption must stay operable from its own node',
        );
      }
    });
  });

  testWidgets('follows each switch when the policy changes', (tester) async {
    await withSemantics(tester, () async {
      await pumpWithPolicy(
        tester,
        PayjoinPolicy.defaults().copyWith(
          sendEnabled: false,
          receiveEnabled: true,
          buyEnabled: false,
          sellEnabled: false,
        ),
      );

      for (final MapEntry(key: action, value: caption) in _captions.entries) {
        final data = _nodeLabelled(tester, caption).getSemanticsData();
        expect(
          data.flagsCollection.isToggled,
          action == PayjoinAction.receive ? Tristate.isTrue : Tristate.isFalse,
          reason: '$caption must follow the policy',
        );
      }
    });
  });

  testWidgets('keeps every caption as a single, stateful switch node', (
    tester,
  ) async {
    await withSemantics(tester, () async {
      await pumpWithPolicy(tester, PayjoinPolicy.defaults());

      for (final caption in _captions.values) {
        final nodes = _semanticsNodes(tester)
            .where((node) => node.getSemanticsData().label == caption);
        expect(
          nodes,
          hasLength(1),
          reason: '$caption must not be announced twice',
        );
        expect(
          nodes.single.getSemanticsData().flagsCollection.isToggled,
          isNot(Tristate.none),
          reason: '$caption must expose its state on the same node',
        );
      }
    });
  });
}
