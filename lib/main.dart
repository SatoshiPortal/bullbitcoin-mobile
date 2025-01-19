import 'dart:async';
import 'dart:developer';

import 'package:bb_mobile/app.dart';
import 'package:bb_mobile/core/locator/di_initializer.dart';
import 'package:bb_mobile/core/presentation/bloc_observer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

Future main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    await Hive.initFlutter();
    await initializeDI();

    Bloc.observer = const BullBitcoinWalletAppBlocObserver();

    runApp(const BullBitcoinWalletApp());
  }, (error, stack) {
    log('\n\nError: $error \nStack: $stack\n\n');
  });
}
