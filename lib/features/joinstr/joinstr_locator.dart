import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_receive_address_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/joinstr/data/joinstr_datasource.dart';
import 'package:bb_mobile/features/joinstr/data/joinstr_store.dart';
import 'package:bb_mobile/features/joinstr/domain/usecases/get_joinstr_settings_usecase.dart';
import 'package:bb_mobile/features/joinstr/domain/usecases/initiate_joinstr_pool_usecase.dart';
import 'package:bb_mobile/features/joinstr/domain/usecases/join_joinstr_pool_usecase.dart';
import 'package:bb_mobile/features/joinstr/domain/usecases/list_joinstr_pools_usecase.dart';
import 'package:bb_mobile/features/joinstr/domain/usecases/resolve_joinstr_peer_context_usecase.dart';
import 'package:bb_mobile/features/joinstr/domain/usecases/save_joinstr_relay_usecase.dart';
import 'package:bb_mobile/features/joinstr/presentation/joinstr_cubit.dart';
import 'package:get_it/get_it.dart';

class JoinstrLocator {
  static void setup(GetIt locator) {
    locator.registerLazySingleton<JoinstrDatasource>(
      () => const JoinstrDatasource(),
    );
    locator.registerLazySingleton<JoinstrStore>(
      () => JoinstrStore(
        locator<KeyValueStorageDatasource<String>>(
          instanceName: LocatorInstanceNameConstants.secureStorageDatasource,
        ),
      ),
    );

    locator.registerFactory<ResolveJoinstrPeerContextUsecase>(
      () => ResolveJoinstrPeerContextUsecase(
        seedRepository: locator<SeedRepository>(),
        electrumServerRepository: locator<ElectrumServerRepository>(),
        getReceiveAddressUsecase: locator<GetReceiveAddressUsecase>(),
      ),
    );
    locator.registerFactory<GetJoinstrSettingsUsecase>(
      () => GetJoinstrSettingsUsecase(store: locator<JoinstrStore>()),
    );
    locator.registerFactory<SaveJoinstrRelayUsecase>(
      () => SaveJoinstrRelayUsecase(store: locator<JoinstrStore>()),
    );
    locator.registerFactory<ListJoinstrPoolsUsecase>(
      () => ListJoinstrPoolsUsecase(
        datasource: locator<JoinstrDatasource>(),
        store: locator<JoinstrStore>(),
      ),
    );
    locator.registerFactory<JoinJoinstrPoolUsecase>(
      () => JoinJoinstrPoolUsecase(
        datasource: locator<JoinstrDatasource>(),
        store: locator<JoinstrStore>(),
        resolvePeerContextUsecase: locator<ResolveJoinstrPeerContextUsecase>(),
      ),
    );
    locator.registerFactory<InitiateJoinstrPoolUsecase>(
      () => InitiateJoinstrPoolUsecase(
        datasource: locator<JoinstrDatasource>(),
        store: locator<JoinstrStore>(),
        resolvePeerContextUsecase: locator<ResolveJoinstrPeerContextUsecase>(),
      ),
    );

    // A singleton on purpose: a coinjoin round blocks in the bindings for up
    // to the pool duration, and its outcome must land in state even when the
    // user navigates away and back (see JoinstrCubit).
    locator.registerLazySingleton<JoinstrCubit>(
      () => JoinstrCubit(
        getWalletsUsecase: locator<GetWalletsUsecase>(),
        getJoinstrSettingsUsecase: locator<GetJoinstrSettingsUsecase>(),
        saveJoinstrRelayUsecase: locator<SaveJoinstrRelayUsecase>(),
        listJoinstrPoolsUsecase: locator<ListJoinstrPoolsUsecase>(),
        joinJoinstrPoolUsecase: locator<JoinJoinstrPoolUsecase>(),
        initiateJoinstrPoolUsecase: locator<InitiateJoinstrPoolUsecase>(),
      ),
    );
  }
}
