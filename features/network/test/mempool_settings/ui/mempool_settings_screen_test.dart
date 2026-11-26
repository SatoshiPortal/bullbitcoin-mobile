import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network/src/mempool_settings/presentation/mempool_settings_cubit.dart';
import 'package:network/src/mempool_settings/ui/mempool_settings_screen.dart';

import '../../fixtures.dart';

class _MempoolSettings extends MockCubit<MempoolSettingsState>
    implements MempoolSettingsCubit {}

void main() {
  testWidgets('refreshes server status from a named action', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      final cubit = _MempoolSettings();
      when(() => cubit.state).thenReturn(const MempoolSettingsState());
      when(() => cubit.loadData()).thenAnswer((_) async {});
      when(cubit.refresh).thenAnswer((_) async {});

      await tester.pumpWidget(
        MaterialApp(
          theme: networkTestTheme(),
          localizationsDelegates: networkTestLocalizationsDelegates,
          home: BlocProvider<MempoolSettingsCubit>.value(
            value: cubit,
            child: const MempoolSettingsScreen(),
          ),
        ),
      );

      final action = find.byTooltip('Refresh servers');
      expect(tester.getSize(action).shortestSide, greaterThanOrEqualTo(48));
      await tester.tap(action);

      verify(cubit.refresh).called(1);
    } finally {
      semantics.dispose();
    }
  });
}
