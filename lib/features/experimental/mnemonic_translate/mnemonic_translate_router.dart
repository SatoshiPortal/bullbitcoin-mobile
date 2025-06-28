import 'package:bb_mobile/features/experimental/mnemonic_translate/mnemonic_translate_page.dart';
import 'package:go_router/go_router.dart';

enum MnemonicTranslateRoutes {
  translator('/mnemonic-translate');

  final String path;
  const MnemonicTranslateRoutes(this.path);
}

class MnemonicTranslateRouterConfig {
  static final route = ShellRoute(
    builder: (context, state, child) => child,
    routes: [
      GoRoute(
        name: MnemonicTranslateRoutes.translator.name,
        path: MnemonicTranslateRoutes.translator.path,
        builder: (context, state) => const MnemonicTranslatePage(),
      ),
    ],
  );
}
