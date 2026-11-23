import 'dart:convert';

import 'package:bull_ui/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart';
import 'package:signers/signers.dart';
import 'package:wallet_import/wallet_import.dart';

void main() {
  testWidgets(
    'QR account choices distinguish invalid input from cancellation',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: testBullExtensions),
          localizationsDelegates: const [
            ImportLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: const Scaffold(body: Text('Scanner')),
        ),
      );
      final context = tester.element(find.text('Scanner'));
      final invalid = await readWatchOnlyQr(
        context,
        '{}',
        device: SignerDevice.passport,
      );
      expect((invalid as Err).failure, isA<InvalidWatchOnlyInputFailure>());

      final pending = readWatchOnlyQr(
        context,
        jsonEncode({'bip84': 'bip84 descriptor', 'bip49': 'bip49 descriptor'}),
        device: SignerDevice.keystone,
      );
      await tester.pumpAndSettle();
      expect(find.text('Segwit (BIP84)'), findsOneWidget);
      expect(find.text('Nested Segwit (BIP49)'), findsOneWidget);
      Navigator.of(context).pop();
      await tester.pumpAndSettle();
      expect((await pending as Ok).value, isNull);
    },
  );
}
