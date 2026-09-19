import 'package:bb_mobile/core/utils/result.dart';
import 'dart:async';
import 'package:bb_mobile/features/backup_settings/domain/usecases/update_data_backup_lifecycle_usecase.dart';
import 'package:bb_mobile/features/backup_settings/public/backup_settings_facade.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Lifecycle extends Mock implements UpdateDataBackupLifecycleUsecase {}

void main() {
  late _Lifecycle lifecycle;
  late StreamController<void> controls;
  setUp(() {
    lifecycle = _Lifecycle();
    controls = StreamController<void>.broadcast(sync: true);
    when(() => lifecycle.changes).thenAnswer((_) => controls.stream);
    when(
      () => lifecycle.execute(
        ready: any(named: 'ready'),
        foreground: any(named: 'foreground'),
      ),
    ).thenAnswer((_) async => const Ok(null));
    locator.registerSingleton<UpdateDataBackupLifecycleUsecase>(lifecycle);
  });
  tearDown(() async {
    await controls.close();
    await locator.reset();
  });
  Future<void> pump(WidgetTester tester, bool ready) => tester.pumpWidget(
    MaterialApp(
      home: BackupSettingsScope(ready: ready, child: const SizedBox.shrink()),
    ),
  );
  testWidgets(
    'app scope forwards startup readiness, consent changes, pause and disposal',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await pump(tester, false);
      verify(() => lifecycle.execute(ready: false, foreground: true)).called(1);
      await pump(tester, true);
      verify(() => lifecycle.execute(ready: true, foreground: true)).called(1);
      controls.add(null);
      await tester.pump();
      verify(() => lifecycle.execute(ready: true, foreground: true)).called(1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      verify(
        () => lifecycle.execute(ready: true, foreground: false),
      ).called(greaterThanOrEqualTo(1));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      verify(() => lifecycle.execute(ready: true, foreground: true)).called(1);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(controls.hasListener, isFalse);
      verify(
        () => lifecycle.execute(ready: false, foreground: false),
      ).called(1);
    },
  );
}
