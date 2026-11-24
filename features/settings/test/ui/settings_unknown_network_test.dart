import 'package:settings/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Settings extends Mock implements SettingsCubit {}

void main() {
  testWidgets('unloaded settings do not advertise network-dependent features', (
    tester,
  ) async {
    final settings = _Settings();
    when(() => settings.state).thenReturn(const SettingsState());
    when(() => settings.stream)
        .thenAnswer((_) => const Stream<SettingsState>.empty());
    List<SettingsItem> items = [];
    await tester.pumpWidget(
      BlocProvider<SettingsCubit>.value(
        value: settings,
        child: MaterialApp(
          localizationsDelegates: settingsTestLocalizationsDelegates,
          supportedLocales: SettingsLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              items = settingsItemsOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    for (final id in [
      SettingsItemId.exchange,
      SettingsItemId.mempool,
      SettingsItemId.sp,
      SettingsItemId.servicesStatus,
      SettingsItemId.autoswap,
      SettingsItemId.payjoin,
    ]) {
      expect(
        items.any((item) => item.id == id),
        isFalse,
        reason: '$id needs an explicit loaded network',
      );
    }
  });
}
