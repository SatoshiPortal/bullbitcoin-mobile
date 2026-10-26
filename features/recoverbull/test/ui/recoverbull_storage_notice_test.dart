import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_recoverbull/src/ui/widgets/recoverbull_storage_notice.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final mode in RecoverBullStorageMode.values) {
    testWidgets(
      'storage notice reflects ${mode.name} without hiding recovery',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(extensions: const [testBullTheme]),
            localizationsDelegates:
                RecoverBullLocalizations.localizationsDelegates,
            supportedLocales: RecoverBullLocalizations.supportedLocales,
            home: RepositoryProvider<RecoverBullStorageMode>.value(
              value: mode,
              child: const RecoverBullStorageNotice(
                child: BullScaffold(body: Text('Recovery')),
              ),
            ),
          ),
        );
        final context = tester.element(find.byType(RecoverBullStorageNotice));
        final message = RecoverBullLocalizations.of(
          context,
        ).recoverbullTemporaryStorageNotice;
        expect(find.text('Recovery'), findsOneWidget);
        expect(
          find.text(message),
          mode == RecoverBullStorageMode.temporary
              ? findsOneWidget
              : findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
