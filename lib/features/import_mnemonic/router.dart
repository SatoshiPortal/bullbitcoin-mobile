import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart'
    as legacy
    show ScriptType;
import 'dart:async';
import 'package:bb_mobile/features/wallet_sync/public/wallet_sync_facade.dart';
import 'package:bb_mobile/features/import_mnemonic/presentation/cubit.dart';
import 'package:transaction_sync/transaction_sync.dart' show BitcoinSyncSource;
import 'package:bb_mobile/features/import_mnemonic/presentation/state.dart';
import 'package:bb_mobile/features/import_mnemonic/ui/mnemonic_page.dart';
import 'package:bb_mobile/features/import_mnemonic/ui/select_purpose_page.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum ImportMnemonicRoute {
  importMnemonicHome('/import-mnemonic-home'),
  selectScriptType('/select-script-type');

  final String path;

  const ImportMnemonicRoute(this.path);
}

class ImportMnemonicRouter {
  static final route = ShellRoute(
    builder: (context, state, child) => BlocProvider<ImportMnemonicCubit>(
      create: (_) => locator<ImportMnemonicCubit>(),
      child: BlocListener<ImportMnemonicCubit, ImportMnemonicState>(
        listenWhen: (previous, current) =>
            previous.wallet == null && current.wallet != null,
        listener: (context, state) {
          context.read<WalletBloc>().add(const WalletStarted());
          context.goNamed(WalletRoute.walletHome.name);
        },
        child: child,
      ),
    ),
    routes: [
      GoRoute(
        name: ImportMnemonicRoute.importMnemonicHome.name,
        path: ImportMnemonicRoute.importMnemonicHome.path,
        builder: (context, state) =>
            BlocListener<ImportMnemonicCubit, ImportMnemonicState>(
              listenWhen: (previous, current) =>
                  previous.mnemonic == null && current.mnemonic != null,
              listener: (context, state) async {
                final cubit = context.read<ImportMnemonicCubit>();
                final selection = await locator<WalletSyncFacade>().choose(
                  context,
                  askScriptType: true,
                );
                if (!context.mounted || cubit.isClosed) return;
                if (selection == null) {
                  cubit.reset();
                  return;
                }
                if (selection.source == BitcoinSyncSource.electrum) {
                  unawaited(cubit.confirmSource(source: selection.source));
                  context.goNamed(ImportMnemonicRoute.selectScriptType.name);
                } else {
                  await cubit.confirmSource(
                    source: selection.source,
                    birthday: selection.birthday,
                    scriptType: legacy.ScriptType.fromName(
                      selection.scriptType.name,
                    ),
                  );
                  if (!cubit.isClosed) await cubit.import();
                }
              },
              child: const MnemonicPage(),
            ),
      ),

      GoRoute(
        name: ImportMnemonicRoute.selectScriptType.name,
        path: ImportMnemonicRoute.selectScriptType.path,
        builder: (context, state) => const SelectScriptTypePage(),
      ),
    ],
  );
}
