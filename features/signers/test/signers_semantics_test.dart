import 'dart:ui' show SemanticsAction, Tristate;

import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart';
import 'package:signers/routes.dart';
import 'package:signers/signers.dart';
import 'package:signers/src/bitbox_flow/bitbox_action.dart';
import 'package:signers/src/bitbox_flow/ui/screens/bitbox_action_screen.dart';
import 'package:signers/src/ledger_flow/ledger_action.dart';
import 'package:signers/src/ledger_flow/ui/screens/ledger_action_screen.dart';
import 'package:signers/src/psbt_flow/domain/psbt_qr_encoder_port.dart';
import 'package:signers/src/psbt_flow/domain/psbt_flow_failure.dart';
import 'package:signers/src/psbt_flow/show_animated_qr/show_animated_qr_widget.dart';

class _Encoder implements PsbtQrEncoderPort {
  @override
  Future<Result<List<String>, PsbtFlowFailure>> encode({
    required String psbt,
    required QrType qrType,
    required int fragmentLength,
  }) async => const Ok(['qr payload']);
}

Widget _app(Widget child) => MaterialApp(
  theme: ThemeData(extensions: testBullExtensions),
  localizationsDelegates: const [
    bullUiLocalizationsDelegate,
    SignersLocalizations.delegate,
    ...GlobalMaterialLocalizations.delegates,
  ],
  supportedLocales: SignersLocalizations.supportedLocales,
  home: child,
);

void main() {
  late GetIt services;
  setUp(() {
    services = GetIt.asNewInstance();
    SignersFeature.mount(services: services, writeNfc: (_, _, _, _) async {});
  });
  tearDown(() => services.reset());

  testWidgets('QR density exposes a name, adjustable value and updated state', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await services.unregister<PsbtQrEncoderPort>();
      services.registerSingleton<PsbtQrEncoderPort>(_Encoder());
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: ShowAnimatedQrWidget(
              services: services,
              psbt: 'psbt',
              qrType: QrType.urqr,
              showSlider: true,
            ),
          ),
        ),
      );
      await tester.pump();
      final control = find.bySemanticsLabel('QR code density');
      expect(control, findsOneWidget);
      final before = tester.getSemantics(control).getSemanticsData();
      expect(before.value, isNotEmpty);
      expect(before.hasAction(SemanticsAction.increase), isTrue);
      expect(before.hasAction(SemanticsAction.decrease), isTrue);
      await tester.drag(find.byType(Slider), const Offset(120, 0));
      await tester.pump(const Duration(milliseconds: 150));
      expect(
        tester.getSemantics(control).getSemanticsData().value,
        isNot(before.value),
      );
      await tester.pumpWidget(const SizedBox());
    } finally {
      semantics.dispose();
    }
  });

  for (final ledger in [true, false]) {
    testWidgets(
      '${ledger ? 'Ledger' : 'BitBox'} wallet selector exposes its current choice',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            _app(
              ledger
                  ? LedgerActionScreen(
                      services: services,
                      action: const LedgerAction.importWallet(),
                      parameters: const LedgerRouteParams(
                        network: NetworkEnv.mainnet,
                      ),
                    )
                  : BitBoxActionScreen(
                      services: services,
                      action: const BitBoxAction.importWallet(),
                      parameters: const BitBoxRouteParams(
                        network: NetworkEnv.mainnet,
                      ),
                    ),
            ),
          );
          await tester.pumpAndSettle();
          final context = tester.element(find.byType(Scaffold).first);
          final loc = SignersLocalizations.of(context);
          final label = ledger
              ? loc.ledgerWalletTypeLabel
              : loc.bitboxScreenWalletTypeLabel;
          final control = find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == label &&
                widget.properties.button == true,
          );
          expect(control, findsOneWidget);
          expect(
            tester.getSemantics(control).getSemanticsData().value,
            ledger ? loc.ledgerWalletTypeSegwit : loc.bitboxScreenSegwitBip84,
          );
          await tester.tap(control);
          await tester.pumpAndSettle();
          final next = ledger
              ? loc.ledgerWalletTypeNestedSegwit
              : loc.bitboxScreenNestedSegwitBip49;
          final current = ledger
              ? loc.ledgerWalletTypeSegwit
              : loc.bitboxScreenSegwitBip84;
          void expectOption(String title, {required bool selected}) {
            final data = tester
                .getSemantics(find.byKey(ValueKey(title)))
                .getSemanticsData();
            expect(data.label, contains(title));
            expect(data.hasAction(SemanticsAction.tap), isTrue);
            expect(
              data.flagsCollection.isSelected,
              selected ? Tristate.isTrue : Tristate.isFalse,
            );
          }

          expectOption(current, selected: true);
          expectOption(next, selected: false);
          await tester.tap(find.byKey(ValueKey(next)));
          await tester.pumpAndSettle();
          expect(tester.getSemantics(control).getSemanticsData().value, next);
          await tester.tap(control);
          await tester.pumpAndSettle();
          expectOption(next, selected: true);
          expectOption(current, selected: false);
          await tester.tap(find.byKey(ValueKey(next)));
          await tester.pumpAndSettle();
          await tester.pumpWidget(const SizedBox());
        } finally {
          semantics.dispose();
        }
      },
    );
  }
}
