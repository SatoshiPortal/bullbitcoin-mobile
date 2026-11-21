import 'package:network/src/tor_settings/presentation/tor_settings_cubit.dart';
import 'package:network/src/tor_settings/public/tor_settings_scope.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:mocktail/mocktail.dart';

class _MockTorSettingsCubit extends Mock implements TorSettingsCubit {}

void main() {
  late _MockTorSettingsCubit cubit;

  setUp(() {
    cubit = _MockTorSettingsCubit();
    when(() => cubit.state).thenReturn(const TorSettingsState());
    when(() => cubit.stream).thenAnswer((_) => const Stream.empty());
    when(cubit.init).thenAnswer((_) async {});
    when(cubit.onAppResumed).thenAnswer((_) async {});
    when(cubit.close).thenAnswer((_) async {});
  });

  testWidgets('owns init, resume and close for exactly one scope', (
    tester,
  ) async {
    await tester.pumpWidget(
      TorSettingsScope(createCubit: () => cubit, child: const SizedBox()),
    );
    verify(cubit.init).called(1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    verify(cubit.onAppResumed).called(1);

    await tester.pumpWidget(const SizedBox());
    verify(cubit.close).called(1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    verifyNoMoreInteractions(cubit);
  });
}
