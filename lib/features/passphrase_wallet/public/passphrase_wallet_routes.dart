import 'package:bb_mobile/features/passphrase_wallet/presentation/passphrase_wallet_cubit.dart';
import 'package:bb_mobile/features/passphrase_wallet/ui/passphrase_wallet_screen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum PassphraseWalletRoute {
  wallets('passphrase');

  final String path;

  const PassphraseWalletRoute(this.path);
}

abstract final class PassphraseWalletRoutes {
  static final route = GoRoute(
    name: PassphraseWalletRoute.wallets.name,
    path: PassphraseWalletRoute.wallets.path,
    builder: (context, state) => BlocProvider(
      create: (_) => locator<PassphraseWalletCubit>()..load(),
      child: const PassphraseWalletScreen(),
    ),
  );
}
