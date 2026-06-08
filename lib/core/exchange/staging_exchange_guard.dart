import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/staging_env.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class StagingExchangeGuard {
  StagingExchangeGuard._();

  static const message = 'STAGING ENV MISSING';

  static bool isBlocked(Environment? environment) =>
      environment == Environment.testnet && !StagingEnv.isConfigured;

  static bool tryProceed(BuildContext context, VoidCallback onAllowed) {
    final environment = context.read<SettingsCubit>().state.environment;
    if (isBlocked(environment)) {
      SnackBarUtils.showSnackBar(context, message);
      return false;
    }
    onAllowed();
    return true;
  }
}
