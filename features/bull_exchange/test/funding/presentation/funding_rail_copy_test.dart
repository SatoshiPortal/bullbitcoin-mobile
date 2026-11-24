import 'package:bull_exchange/bull_exchange.dart';
import 'package:bull_exchange/src/funding/presentation/funding_rail_copy.dart';
import 'package:bull_exchange/src/funding/ui/widgets/funding_instructions_view.dart';
import 'package:bull_ui/testing.dart';
import 'package:exchange/funding.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Future<BuildContext> _context(WidgetTester tester, [Widget? child]) async {
  late BuildContext captured;
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: testBullExtensions),
      localizationsDelegates: ExchangeLocalizations.localizationsDelegates,
      supportedLocales: ExchangeLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: Builder(
            builder: (context) {
              captured = context;
              return child ?? const SizedBox();
            },
          ),
        ),
      ),
    ),
  );
  return captured;
}

void main() {
  testWidgets('every rail has a tile and copy for every field it shows', (
    tester,
  ) async {
    final context = await _context(tester);
    for (final rail in FundingRails.all) {
      final tile = rail.tile(context);
      expect(tile.title, isNotEmpty, reason: rail.name);
      expect(tile.subtitle, isNotEmpty, reason: rail.name);
      final copy = rail.instructionsCopy(context);
      expect(copy.title, isNotEmpty, reason: rail.name);
      if (rail is ProcessorCodeRail) {
        expect(
          copy.fields.keys.toSet(),
          rail.fields.toSet(),
          reason: rail.name,
        );
      }
    }
  });

  testWidgets('the instructions show the server values, nothing else', (
    tester,
  ) async {
    await _context(
      tester,
      FundingInstructionsView(
        rail: const SinpeMovilRail(),
        instructions: const FundingInstructionRows([
          InstructionRow(InstructionField.phoneNumber, '88888888'),
          InstructionRow(InstructionField.beneficiaryName, 'Bull Bitcoin'),
        ]),
        onOpenLink: (_) => fail('no link'),
      ),
    );

    expect(find.text('88888888'), findsOneWidget);
    expect(find.text('Bull Bitcoin'), findsOneWidget);
  });

  testWidgets('a COP link opens through the callback', (tester) async {
    Uri? opened;
    final link = Uri.parse('https://pay.example/cop');
    await _context(
      tester,
      FundingInstructionsView(
        rail: const CopBankTransferRail(),
        instructions: FundingInstructionLink(link),
        onOpenLink: (uri) => opened = uri,
      ),
    );

    await tester.tap(find.byIcon(Icons.open_in_new));
    expect(opened, link);
  });
}
