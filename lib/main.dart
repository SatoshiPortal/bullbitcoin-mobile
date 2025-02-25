import 'dart:async';
import 'dart:developer';

import 'package:bb_mobile/features/app_startup/app.dart';
import 'package:bb_mobile/features/app_startup/app_bloc_observer.dart';
import 'package:bb_mobile/features/app_startup/app_locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lwk/lwk.dart';

Future main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    await Hive.initFlutter();
    await LibLwk.init();
    await AppLocator.setup();

    Bloc.observer = const AppBlocObserver();

    runApp(const BullBitcoinWalletApp());
  }, (error, stack) {
    log('\n\nError: $error \nStack: $stack\n\n');
  });
}
