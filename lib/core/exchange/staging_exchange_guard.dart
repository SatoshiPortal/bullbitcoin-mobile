import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/staging_env.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class StagingExchangeGuard {
  StagingExchangeGuard._();

  static const message = 'STAGING ENV MISSING';

  static bool isBlocked(Environment? environment) =>
      environment == Environment.testnet && !StagingEnv.isConfigured;

  static void warn(BuildContext context) {
    SnackBarUtils.showSnackBar(context, message);
  }

  static void leaveIfBlocked(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(WalletRoute.walletHome.name);
    }
  }

  static bool tryProceed(BuildContext context, VoidCallback onAllowed) {
    final environment = context.read<SettingsCubit>().state.environment;
    if (isBlocked(environment)) {
      warn(context);
      return false;
    }
    onAllowed();
    return true;
  }

  static Widget wrap(Widget child) => StagingExchangeGuardPage(child: child);
}

class StagingExchangeGuardPage extends StatelessWidget {
  const StagingExchangeGuardPage({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final environment = context.read<SettingsCubit>().state.environment;
    if (!StagingExchangeGuard.isBlocked(environment)) {
      return child;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      StagingExchangeGuard.warn(context);
      StagingExchangeGuard.leaveIfBlocked(context);
    });

    return const SizedBox.shrink();
  }
}
