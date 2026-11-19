import 'package:ark/ark.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'package:bull_ark/ark_ui_setup.dart' show ArkShare;
import 'package:bull_ark/src/presentation/ark_receive_cubit.dart'
    show ArkReceiveReady;
import 'package:bull_ark/src/ui/ark_board_amount_screen.dart';
import 'package:bull_ark/src/ui/ark_board_screen.dart';
import 'package:bull_ark/src/ui/ark_information_screen.dart';
import 'package:bull_ark/src/ui/ark_receive_screen.dart';

import '../ark_board_screen_test.dart' as board;

Widget informationFixture({
  required ArkAccountConfig config,
  required ArkSnapshot? snapshot,
}) => ArkInformationScreen(config: config, snapshot: snapshot);
Object boardAmountStateToken(WidgetTester tester) =>
    tester.state(find.byType(ArkBoardAmountScreen));
Widget labelledBoardFixture(
  board.Rig rig, {
  required ({String walletId, String label}) sourceLabel,
}) => ArkBoardScreen(
  cubit: rig.cubit,
  sourceLabel: sourceLabel,
  onReconcile: () {},
);

typedef ReceiveFixtureObservation = ({
  Widget widget,
  Object owner,
  Object state,
  ArkShare? share,
  VoidCallback edit,
});
ReceiveFixtureObservation receiveFixtureObservation(WidgetTester tester) {
  final page = tester.widget<ArkReceiveScreen>(find.byType(ArkReceiveScreen));
  final owner = page.cubit;
  final state = owner.state;
  expect(state, isA<ArkReceiveReady>());
  return (
    widget: page,
    owner: owner,
    state: state,
    share: page.share,
    edit: owner.edit,
  );
}

void expectBoardSourceLabel(WidgetTester tester, String? label) => expect(
  tester.widget<ArkBoardScreen>(find.byType(ArkBoardScreen)).sourceLabel?.label,
  label,
);
void expectBoardAvailable(WidgetTester tester, Sats? available) => expect(
  tester
      .widget<ArkBoardScreen>(find.byType(ArkBoardScreen))
      .displayData
      ?.available,
  available,
);
