import 'package:all_seed_view/src/domain/usecases/delete_swap_master_key_usecase.dart';
import 'package:all_seed_view/src/domain/usecases/get_swap_master_key_usecase.dart';
import 'package:access/access.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:preferences/preferences.dart';
import 'package:secrets/custody.dart';
import 'package:secrets/secrets.dart';
import 'package:swaps/swaps.dart';

import 'domain/usecases/delete_secret_usecase.dart';
import 'domain/usecases/get_all_secrets_usecase.dart';
import 'domain/usecases/get_wallets_usecase.dart';
import 'domain/usecases/separate_secrets_usecase.dart';
import 'presentation/all_seed_view_cubit.dart';
import 'ui/all_seed_view_screen.dart';

enum AllSeedViewRoute {
  allSeedView('seed-viewer');

  final String path;
  const AllSeedViewRoute(this.path);
}

final class AllSeedViewFeature {
  final Secrets _secrets;
  final WalletInventory _inventory;
  final ActiveEnvironmentReader _preferences;
  final SeedReferences _references;
  final BoltzSwaps _swaps;
  final Access _access;

  const AllSeedViewFeature._(
    this._secrets,
    this._inventory,
    this._preferences,
    this._references,
    this._swaps,
    this._access,
  );

  factory AllSeedViewFeature.mount({
    required Secrets secrets,
    required WalletInventory inventory,
    required ActiveEnvironmentReader preferences,
    required SeedReferences references,
    required BoltzSwaps swaps,
    required Access access,
  }) => AllSeedViewFeature._(
    secrets,
    inventory,
    preferences,
    references,
    swaps,
    access,
  );

  GoRoute get route => GoRoute(
    path: AllSeedViewRoute.allSeedView.path,
    name: AllSeedViewRoute.allSeedView.name,
    builder: (context, state) => BlocProvider(
      create: (_) => AllSeedViewCubit(
        getAllSecretsUsecase: GetAllSecretsUsecase(secrets: _secrets),
        getWalletsUsecase: GetWalletsUsecase(_inventory, _preferences),
        deleteSecretUsecase: DeleteSecretUsecase(
          secrets: _secrets,
          seedReferences: _references,
        ),
        separateSecretsUsecase: const SeparateSecretsUsecase(),
        getSwapMasterKeyUsecase: GetSwapMasterKeyUsecase(_swaps),
        deleteSwapMasterKeyUsecase: DeleteSwapMasterKeyUsecase(_swaps),
      ),
      child: AllSeedViewScreen(access: _access, swaps: _swaps),
    ),
  );
}
