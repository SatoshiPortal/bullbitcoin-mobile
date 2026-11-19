/// Composition-only dependencies; never used by another feature's business code.
library;

import 'package:ark/ark.dart';

import '../data/ark_repository_impl.dart';
import '../domain/repositories/ark_preferences_repository.dart';
import '../domain/usecases/enable_ark_usecase.dart';
import '../domain/ark_provisioning_port.dart';
import '../domain/ark_board_funding_port.dart';
import '../domain/usecases/prepare_ark_board_usecase.dart';
import '../domain/usecases/read_ark_board_usecase.dart';
import '../domain/usecases/confirm_ark_board_usecase.dart';
import '../domain/repositories/ark_account_registry_repository.dart';
import '../domain/usecases/list_enabled_ark_accounts_usecase.dart';
import '../domain/usecases/is_ark_enabled_usecase.dart';
import '../domain/usecases/set_ark_enabled_usecase.dart';
import '../domain/usecases/read_ark_usecase.dart';
import '../domain/usecases/quote_ark_operation_usecase.dart';
import '../domain/usecases/confirm_ark_operation_usecase.dart';
import '../domain/usecases/create_ark_receive_usecase.dart';
import '../public/ark_facade.dart';
import '../domain/usecases/review_ark_claim_recovery_usecase.dart';
import '../domain/usecases/rebroadcast_ark_claim_usecase.dart';
export '../domain/repositories/ark_preferences_repository.dart';

ArkFacade createArkFacade({
  required ArkClient client,
  required ArkPreferencesRepository preferences,
  required ArkProvisioningPort provisioning,
  required ArkBoardFundingPort boardFunding,
  ArkAccountRegistryRepository? registry,
}) {
  final repository = ArkRepositoryImpl(client);
  return ArkFacade(
    EnableArkUsecase(repository, preferences, provisioning),
    IsArkEnabledUsecase(preferences),
    SetArkEnabledUsecase(repository, preferences),
    ReadArkUsecase(repository),
    SynchronizeArkUsecase(repository),
    QuoteArkOperationUsecase(repository, preferences),
    ConfirmArkOperationUsecase(repository, preferences),
    CreateArkReceiveUsecase(repository, preferences),
    PrepareArkBoardUsecase(boardFunding, preferences),
    ReadArkBoardUsecase(boardFunding),
    ConfirmArkBoardUsecase(boardFunding, preferences),
    registry == null
        ? null
        : ListEnabledArkAccountsUsecase(registry, preferences),
    ReviewArkClaimRecoveryUsecase(repository),
    RebroadcastArkClaimUsecase(repository),
  );
}
