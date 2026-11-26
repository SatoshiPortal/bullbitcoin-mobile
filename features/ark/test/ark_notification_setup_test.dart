import 'dart:io';
import 'dart:ui';

import 'package:bull_ark/ark_notification_setup.dart';
import 'package:bull_ark/src/data/ark_exit_notification_setup.dart';
import 'package:bull_ark/src/data/ark_payment_observer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:notifications/payment_store.dart';
import 'package:primitives/primitives.dart';

import 'ark_payment_observer_test.dart' show Exits, Gateway, movement, pass;

void main() {
  test(
    'a broken exit journal does not prevent the foreground baseline',
    () async {
      final directory = Directory.systemTemp.createTempSync(
        'ark-notifications-',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final admission = await NativeFileGate(
        File('${directory.path}/lifecycle'),
      ).acquire(exclusive: false, timeout: Duration.zero) as RuntimeAdmission;
      addTearDown(admission.close);
      final marker = File('${directory.path}/exit-notices.sqlite.initialized');
      marker.writeAsStringSync('invalid');
      final foreground = await openForegroundArkExitNotifier(
        documents: directory.path,
        directory: directory.path,
        locale: const Locale('en'),
        admission: admission,
        initializeExits: (_) async => Ok(unavailableArkNotifications()),
      );
      await foreground.combined.observe(pass([movement('already seen')]));
      marker.deleteSync();
      await foreground.combined.observe(pass([movement('already seen')]));
      expect(marker.readAsStringSync(), 'ark-exit-notices:1\n');
      await foreground.close();

      final gateway = Gateway();
      final store = PaymentNotificationStore(
        () async => directory.path,
        () async => gateway,
      );
      addTearDown(store.close);
      final background = ArkPaymentObserver(
        notifications: await store.open(),
        exits: Exits(),
        foreground: false,
        copy: (count) => (title: 'Received', body: '$count'),
      );
      await background.observe(
        pass([movement('already seen'), movement('new')]),
      );
      expect(gateway.shown.single.body, '1');
    },
  );
}
