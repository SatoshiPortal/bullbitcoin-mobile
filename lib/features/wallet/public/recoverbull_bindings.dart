import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/features/wallet/data/recoverbull_wallet_adapter.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:get_it/get_it.dart';
import 'package:secrets/secrets.dart';

final class WalletRecoverBullBindings {
  static void setup(GetIt locator) =>
      locator.registerSingleton<RecoverBullWalletPort>(
        RecoverBullWalletAdapter(
          locator<WalletRepository>(),
          locator<SettingsRepository>(),
          locator<Secrets>(),
          locator<CreateDefaultWalletsUsecase>(),
        ),
      );

  static void recovered(BuildContext context) =>
      context.read<WalletBloc>().add(const WalletStarted());
}
