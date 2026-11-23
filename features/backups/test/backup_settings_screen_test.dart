import 'package:backups/src/presentation/cubit/backup_settings_cubit.dart';
import 'package:backups/src/ui/screens/backup_settings_screen.dart';
import 'package:backups/backups.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class _BackupCubit extends Fake implements BackupSettingsCubit {
  @override
  BackupSettingsState get state => BackupSettingsState();

  @override
  Stream<BackupSettingsState> get stream => const Stream.empty();
}

void main() {
  Future<void> pumpScreen(WidgetTester tester, {VoidCallback? open}) =>
      tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: testBullExtensions),
          localizationsDelegates: const [BackupsFeature.localizationsDelegate],
          home: BlocProvider<BackupSettingsCubit>.value(
            value: _BackupCubit(),
            child: BackupSettingsScreen(
              onExportTransactions: () {},
              onOpenAutomaticBackup: open,
            ),
          ),
        ),
      );

  testWidgets('automatic backup stays hidden before host setup', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('Automatic backup'), findsNothing);
    expect(find.text('Money backup'), findsOneWidget);
    expect(find.text('Data backup'), findsOneWidget);
    expect(find.text('Labels'), findsOneWidget);
    expect(find.text('Transaction History'), findsOneWidget);
  });

  testWidgets('opens the supplied automatic backup action', (tester) async {
    var opens = 0;
    await pumpScreen(tester, open: () => opens++);

    final entry = find.text('Automatic backup');
    expect(find.text('Unknown'), findsOneWidget);
    await tester.ensureVisible(entry);
    await tester.tap(entry);

    expect(opens, 1);
  });
}
