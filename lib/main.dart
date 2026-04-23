import 'dart:async';

import 'package:bb_mobile/bloc_observer.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/app_startup/presentation/bloc/app_startup_bloc.dart';
import 'package:bb_mobile/features/app_startup/ui/app_startup_widget.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
Future<void> main() async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Build expiration check
      final now = DateTime.now();
      final expirationTime = DateTime(2026, 5, 28, 23, 59);
      if (now.isAfter(expirationTime)) {
        runApp(const BuildExpiredScreen());
        return;
      }

      final logDirectory = await getApplicationDocumentsDirectory();
      log = Logger.init(directory: logDirectory);
      await log.ensureLogsExist();

      await AppLocator.setup();
      Bloc.observer = AppBlocObserver();

      runApp(const BullBitcoinWalletApp());
    },
    (error, stackTrace) async {
      log.severe(error: error, trace: stackTrace);
    },
  );
}

class BullBitcoinWalletApp extends StatelessWidget {
  const BullBitcoinWalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          locator<AppStartupBloc>()..add(const AppStartupStarted()),
      child: MaterialApp(
        title: 'BullBitcoin Wallet',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.themeData(AppThemeType.dark),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AppStartupWidget(),
      ),
    );
  }
}

class BuildExpiredScreen extends StatelessWidget {
  const BuildExpiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.themeData(AppThemeType.dark),
      home: const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 80),
              SizedBox(height: 32),
              Text(
                'This release is expired',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
