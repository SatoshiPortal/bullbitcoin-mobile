import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_receive_address_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/joinstr/data/joinstr_datasource.dart';
import 'package:bb_mobile/features/joinstr/domain/usecases/initiate_joinstr_pool_usecase.dart';
import 'package:bb_mobile/features/joinstr/domain/usecases/join_joinstr_pool_usecase.dart';
import 'package:bb_mobile/features/joinstr/domain/usecases/list_joinstr_pools_usecase.dart';
import 'package:bb_mobile/features/joinstr/domain/usecases/resolve_joinstr_peer_context_usecase.dart';
import 'package:bb_mobile/features/joinstr/presentation/joinstr_cubit.dart';
import 'package:get_it/get_it.dart';

class JoinstrLocator {
  static void setup(GetIt locator) {
    locator.registerLazySingleton<JoinstrDatasource>(
      () => const JoinstrDatasource(),
    );

    locator.registerFactory<ResolveJoinstrPeerContextUsecase>(
      () => ResolveJoinstrPeerContextUsecase(
        seedRepository: locator<SeedRepository>(),
        electrumServerRepository: locator<ElectrumServerRepository>(),
        getReceiveAddressUsecase: locator<GetReceiveAddressUsecase>(),
      ),
    );
    locator.registerFactory<ListJoinstrPoolsUsecase>(
      () => ListJoinstrPoolsUsecase(datasource: locator<JoinstrDatasource>()),
    );
    locator.registerFactory<JoinJoinstrPoolUsecase>(
      () => JoinJoinstrPoolUsecase(
        datasource: locator<JoinstrDatasource>(),
        resolvePeerContextUsecase: locator<ResolveJoinstrPeerContextUsecase>(),
      ),
    );
    locator.registerFactory<InitiateJoinstrPoolUsecase>(
      () => InitiateJoinstrPoolUsecase(
        datasource: locator<JoinstrDatasource>(),
        resolvePeerContextUsecase: locator<ResolveJoinstrPeerContextUsecase>(),
      ),
    );

    locator.registerFactory<JoinstrCubit>(
      () => JoinstrCubit(
        getWalletsUsecase: locator<GetWalletsUsecase>(),
        listJoinstrPoolsUsecase: locator<ListJoinstrPoolsUsecase>(),
        joinJoinstrPoolUsecase: locator<JoinJoinstrPoolUsecase>(),
        initiateJoinstrPoolUsecase: locator<InitiateJoinstrPoolUsecase>(),
      ),
    );
  }
}
