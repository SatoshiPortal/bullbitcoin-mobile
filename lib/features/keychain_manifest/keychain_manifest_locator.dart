import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/keychain_manifest/data/keychain_manifest_repository_impl.dart';
import 'package:bb_mobile/features/keychain_manifest/data/models/keychain_manifest_file_model.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/nostr_key_deriver.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_repository.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/build_keychain_manifest_file_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/create_keychain_manifest_nostr_key_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/get_default_wallet_nostr_keys_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/get_keychain_manifest_reservation_wallet_ids_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/merge_keychain_manifest_file_payloads_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/parse_keychain_manifest_file_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/record_keychain_manifest_nostr_key_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/record_reserved_wallets_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/reveal_keychain_manifest_nostr_key_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/update_keychain_manifest_nostr_key_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/watch_keychain_manifest_changes_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/presentation/nostr_keys_cubit.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/ui/widgets/nostr_nsec_reveal_dialog.dart';
import 'package:get_it/get_it.dart';

abstract final class KeychainManifestLocator {
  static void setup(GetIt locator) {
    const codec = KeychainManifestFileCodec();
    locator.registerLazySingleton<KeychainManifestRepository>(
      () => KeychainManifestRepositoryImpl(locator<SqliteDatabase>()),
      dispose: (repository) => repository.close(),
    );

    KeychainManifestNostrKeyDeriver deriver() =>
        KeychainManifestNostrKeyDeriver(
          locator<GetSettingsUsecase>(),
          locator<GetDefaultSeedUsecase>(),
        );
    RecordKeychainManifestNostrKeyUsecase recordNostr() =>
        RecordKeychainManifestNostrKeyUsecase(
          locator<KeychainManifestRepository>(),
        );
    ParseKeychainManifestFileUsecase parse() =>
        const ParseKeychainManifestFileUsecase(codec);

    locator.registerFactory<NostrKeysCubit>(
      () => NostrKeysCubit(
        GetDefaultWalletNostrKeysUsecase(
          deriver(),
          locator<KeychainManifestRepository>(),
        ),
        CreateKeychainManifestNostrKeyUsecase(
          deriver(),
          locator<KeychainManifestRepository>(),
          recordNostr(),
        ),
        UpdateKeychainManifestNostrKeyUsecase(
          locator<KeychainManifestRepository>(),
        ),
      ),
    );
    locator.registerFactory<NostrNsecRevealPresenter>(
      () => NostrNsecRevealPresenter(
        RevealKeychainManifestNostrKeyUsecase(deriver()),
      ),
    );
    locator.registerLazySingleton<KeychainManifestFacade>(
      () => KeychainManifestFacade(
        WatchKeychainManifestChangesUsecase(
          locator<KeychainManifestRepository>(),
        ),
        codec,
        BuildKeychainManifestFileUsecase(locator<KeychainManifestRepository>()),
        parse(),
        MergeKeychainManifestFilePayloadsUsecase(codec, parse()),
        RecordReservedWalletsUsecase(locator<KeychainManifestRepository>()),
        recordNostr(),
        GetKeychainManifestReservationWalletIdsUsecase(
          locator<KeychainManifestRepository>(),
        ),
      ),
    );
  }
}
