import 'package:wallet_import/src/presentation/mnemonic/cubit.dart';
import 'package:wallet_import/src/presentation/mnemonic/state.dart';
import 'package:wallet_import/src/ui/mnemonic/mnemonic_page.dart';
import 'package:wallet_import/src/ui/mnemonic/select_purpose_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' show BuildContext;

enum ImportMnemonicRoute {
  importMnemonicHome('/import-mnemonic-home'),
  selectScriptType('/select-script-type');

  final String path;

  const ImportMnemonicRoute(this.path);
}

class ImportMnemonicRouter {
  static ShellRoute route({
    required ImportMnemonicCubit Function() createCubit,
    required void Function(BuildContext) onImported,
    required void Function(BuildContext) onExit,
  }) => ShellRoute(
    builder: (context, state, child) => BlocProvider<ImportMnemonicCubit>(
      create: (_) => createCubit(),
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
                !previous.imported && current.imported,
            listener: (context, state) => onImported(context),
            child: SelectScriptTypePage(onExit: onExit),
          );
        },
      ),
    ],
  );
}
