import 'package:bb_mobile/features/import_mnemonic/presentation/cubit.dart';
import 'package:bb_mobile/features/import_mnemonic/presentation/state.dart';
import 'package:bb_mobile/features/import_mnemonic/ui/mnemonic_page.dart';
import 'package:bb_mobile/features/import_mnemonic/ui/select_purpose_page.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:bb_mobile/core/infra/di/core_dependencies.dart';

enum ImportMnemonicRoute {
  importMnemonicHome('/import-mnemonic-home'),
  selectScriptType('/select-script-type');

  final String path;

  const ImportMnemonicRoute(this.path);
}

class ImportMnemonicRouter {
  static final route = ShellRoute(
    builder: (context, state, child) => BlocProvider<ImportMnemonicCubit>(
      create: (_) => sl<ImportMnemonicCubit>(),
      child: child,
    ),
    routes: [
      GoRoute(
        name: ImportMnemonicRoute.importMnemonicHome.name,
        path: ImportMnemonicRoute.importMnemonicHome.path,
        builder: (context, state) =>
            BlocListener<ImportMnemonicCubit, ImportMnemonicState>(
              listenWhen: (previous, current) =>
                  previous.mnemonic == null && current.mnemonic != null,
              listener: (context, state) {
                context.goNamed(ImportMnemonicRoute.selectScriptType.name);
              },
              child: const MnemonicPage(),
            ),
      ),

      GoRoute(
        name: ImportMnemonicRoute.selectScriptType.name,
        path: ImportMnemonicRoute.selectScriptType.path,
        builder: (context, state) {
          return BlocListener<ImportMnemonicCubit, ImportMnemonicState>(
            listenWhen: (previous, current) =>
                previous.wallet == null && current.wallet != null,
            listener: (context, state) {
              // Trigger wallet refresh before navigating to home
              context.read<WalletBloc>().add(const WalletStarted());
              context.goNamed(WalletRoute.walletHome.name);
            },
            child: const SelectScriptTypePage(),
          );
        },
      ),
    ],
  );
}
