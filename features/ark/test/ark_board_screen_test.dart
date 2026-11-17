import 'package:bull_ark/src/domain/usecases/confirm_ark_board_usecase.dart';
import 'package:bull_ark/src/domain/usecases/prepare_ark_board_usecase.dart';
import 'package:bull_ark/src/domain/usecases/read_ark_board_usecase.dart';
import 'package:bull_ark/src/presentation/ark_board_cubit.dart';
import 'package:bull_ark/src/ui/ark_board_amount_screen.dart';
import 'package:bull_ark/src/ui/ark_board_screen.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton, SizedBox;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'ark_board_journey_test.dart' show prepared;
import 'ark_information_widget_test.dart' show app, config, details;
import 'ark_operations_test.dart' show Preferences;
import 'fake_ark_board_funding.dart';

class Rig {
  final funding = FakeArkBoardFunding()
    ..prepared = Ok(prepared())
    ..observed = Ok(prepared());
  late final ArkBoardCubit cubit;
  int refreshes = 0;
  Rig() {
    final preferences = Preferences();
    cubit = ArkBoardCubit(
      PrepareArkBoardUsecase(funding, preferences),
      ReadArkBoardUsecase(funding),
      ConfirmArkBoardUsecase(funding, preferences),
      config: config(),
    );
    addTearDown(cubit.close);
  }
  ArkBoardScreen get screen =>
      ArkBoardScreen(cubit: cubit, onReconcile: () => refreshes++);
}

BullButton button(WidgetTester tester, String label) =>
    tester.widget<BullButton>(find.widgetWithText(BullButton, label));

void main() {
  testWidgets(
    'mount is passive; explicit review shows actual source debit and fee units',
    (tester) async {
      final rig = Rig();
      await tester.pumpWidget(app(rig.screen));
      await tester.pumpAndSettle();
      expect(rig.funding.calls, isEmpty);
      final input = tester.widget<ArkBoardAmountScreen>(
        find.byType(ArkBoardAmountScreen),
      );
      input.onReviewRequest?.call(rig.cubit.config, Sats.fromInt(1000));
      await tester.pumpAndSettle();
      expect(rig.funding.calls, ['prepare', 'read']);
      expect(details(tester), containsPair('Amount in sats', '1000'));
      expect(details(tester), containsPair('Miner fee (sats)', '100'));
      expect(details(tester), containsPair('Ark board fee (sats)', '10'));
      expect(details(tester), containsPair('Source debit (sats)', '1100'));
      expect(details(tester), containsPair('Net amount (sats)', '990'));
      final confirm = button(tester, 'Confirm').onPressed;
      expect(confirm, isNotNull);
      confirm.call();
      confirm.call();
      await tester.pumpAndSettle();
      expect(rig.funding.calls, ['prepare', 'read', 'confirm']);
      expect(rig.cubit.state, isA<ArkBoardPending>());
      confirm.call();
      await tester.pumpAndSettle();
      expect(rig.funding.calls, ['prepare', 'read', 'confirm']);
    },
  );

  testWidgets(
    'same account replacement rejects old confirm without closing injected owners',
    (tester) async {
      final first = Rig(), second = Rig();
      await first.cubit.prepare(Sats.fromInt(1000));
      await tester.pumpWidget(app(first.screen));
      await tester.pumpAndSettle();
      final oldConfirm = button(tester, 'Confirm').onPressed;
      await second.cubit.prepare(Sats.fromInt(1000));
      await tester.pumpWidget(app(second.screen));
      await tester.pumpAndSettle();
      oldConfirm.call();
      await tester.pumpAndSettle();
      expect(first.funding.calls, ['prepare', 'read']);
      expect(second.funding.calls, ['prepare', 'read']);
      expect(first.cubit.isClosed, isFalse);
      expect(second.cubit.isClosed, isFalse);
      button(tester, 'Confirm').onPressed.call();
      await tester.pumpAndSettle();
      expect(second.funding.calls, ['prepare', 'read', 'confirm']);
    },
  );

  testWidgets(
    'direct disposal rejects old confirm while injected owner remains open',
    (tester) async {
      final rig = Rig();
      await rig.cubit.prepare(Sats.fromInt(1000));
      await tester.pumpWidget(app(rig.screen));
      await tester.pumpAndSettle();
      final oldConfirm = button(tester, 'Confirm').onPressed;
      await tester.pumpWidget(app(const SizedBox()));
      await tester.pumpAndSettle();
      expect(() => oldConfirm.call(), returnsNormally);
      expect(rig.cubit.isClosed, isFalse);
      expect(rig.funding.calls, ['prepare', 'read']);
    },
  );
}
