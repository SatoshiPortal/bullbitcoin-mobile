import 'package:go_router/go_router.dart';
import 'package:flutter/widgets.dart';
import 'package:preferences/preferences.dart';
import 'package:secrets/bip85.dart';
import 'package:secrets/secrets.dart';

import 'src/domain/manage_bip85_usecase.dart';
import 'src/presentation/bip85_cubit.dart';
import 'src/ui/bip85_home_page.dart';

export 'generated/l10n/bip85_localizations.dart' show Bip85Localizations;

final class Bip85Route {
  const Bip85Route();

  static const _name = 'bip85Home';
  static const _path = '/bip85-home';

  Future<void> push(BuildContext context) => context.pushNamed<void>(_name);
}

final class Bip85Feature {
  final GoRoute route;

  const Bip85Feature._(this.route);

  static Bip85Feature mount({
    required Bip85Derivations derivations,
    required WalletInventory inventory,
    required ActiveEnvironmentReader preferences,
  }) {
    final usecase = ManageBip85Usecase(derivations, inventory, preferences);
    return Bip85Feature._(
      GoRoute(
        name: Bip85Route._name,
        path: Bip85Route._path,
        builder: (context, state) =>
            Bip85HomePage(createCubit: () => Bip85EntropyCubit(usecase)),
      ),
    );
  }
}
