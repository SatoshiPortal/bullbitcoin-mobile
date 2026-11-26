import 'package:exchange/exchange.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:preferences/preferences.dart';

import 'domain/usecases/add_recipient_usecase.dart';
import 'domain/usecases/check_sinpe_usecase.dart';
import 'domain/usecases/get_account_owner_name_usecase.dart';
import 'domain/usecases/get_confidential_sepa_availability_usecase.dart';
import 'domain/usecases/get_preferred_jurisdiction_usecase.dart';
import 'domain/usecases/get_recipients_environment_usecase.dart';
import 'domain/usecases/get_recipients_usecase.dart';
import 'domain/usecases/list_cad_billers_usecase.dart';
import 'domain/usecases/watch_sepa_virtual_payee_activation_usecase.dart';
import 'domain/usecases/watch_virtual_iban_usecase.dart';
import 'presentation/recipients_bloc.dart';
import 'presentation/sepa_virtual_payee_activation_cubit.dart';
import 'presentation/virtual_iban_onboarding_cubit.dart';
import 'public/recipient_filter_criteria.dart';
import 'public/recipient_view_model.dart';

typedef RecipientSelected = Future<void>? Function(
  RecipientViewModel recipient, {
  required bool isNew,
});

typedef RecipientsServices = ({
  RecipientsBloc Function(RecipientFilterCriteria?, RecipientSelected?)
  createRecipientsBloc,
  VirtualIbanOnboardingCubit Function() createVirtualIbanCubit,
  SepaVirtualPayeeActivationCubit Function(String) createActivationCubit,
});

class RecipientsScope extends InheritedWidget {
  final RecipientsServices _services;

  RecipientsScope({
    required Exchange Function() exchange,
    required Preferences Function() preferences,
    required super.child,
    super.key,
  }) : _services = _buildServices(exchange, preferences);

  @internal
  const RecipientsScope.withServices({
    required this._services,
    required super.child,
    super.key,
  });

  @internal
  static RecipientsServices read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<RecipientsScope>();
    if (scope == null) throw StateError('RecipientsScope not mounted');
    return scope._services;
  }

  @override
  bool updateShouldNotify(RecipientsScope oldWidget) => false;
}

RecipientsServices _buildServices(
  Exchange Function() exchange,
  Preferences Function() preferences,
) => (
  createRecipientsBloc: (filter, onSelected) {
    final capability = exchange();
    final recipients = capability.recipients;
    final environment = GetRecipientsEnvironmentUsecase(preferences());
    return RecipientsBloc(
      allowedRecipientFilters: filter,
      onRecipientSelectedHook: onSelected,
      getPreferredJurisdictionUsecase: GetPreferredJurisdictionUsecase(
        capability,
      ),
      getConfidentialSepaAvailabilityUsecase:
          GetConfidentialSepaAvailabilityUsecase(capability),
      getAccountOwnerNameUsecase: GetAccountOwnerNameUsecase(capability),
      addRecipientUsecase: AddRecipientUsecase(
        recipientsRepository: recipients,
        sepaVirtualPayeeRepository: recipients,
        getRecipientsEnvironmentUsecase: environment,
      ),
      getRecipientsUsecase: GetRecipientsUsecase(
        recipientsRepository: recipients,
        getRecipientsEnvironmentUsecase: environment,
      ),
      checkSinpeUsecase: CheckSinpeUsecase(
        recipientsRepository: recipients,
        getRecipientsEnvironmentUsecase: environment,
      ),
      listCadBillersUsecase: ListCadBillersUsecase(
        recipientsRepository: recipients,
        getRecipientsEnvironmentUsecase: environment,
      ),
    );
  },
  createVirtualIbanCubit: () {
    final capability = exchange();
    return VirtualIbanOnboardingCubit(
      watchVirtualIbanUsecase: WatchVirtualIbanUsecase(
        virtualIbans: capability.virtualIbans,
        getRecipientsEnvironmentUsecase: GetRecipientsEnvironmentUsecase(
          preferences(),
        ),
        notifications: capability.notifications,
      ),
      getAccountOwnerNameUsecase: GetAccountOwnerNameUsecase(capability),
    );
  },
  createActivationCubit: (recipientId) => SepaVirtualPayeeActivationCubit(
    watchSepaVirtualPayeeActivationUsecase:
        WatchSepaVirtualPayeeActivationUsecase(
          sepaVirtualPayeeRepository: exchange().recipients,
          getRecipientsEnvironmentUsecase: GetRecipientsEnvironmentUsecase(
            preferences(),
          ),
        ),
    recipientId: recipientId,
  ),
);
