import 'dart:async';

import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/recipients/application/usecases/add_recipient_usecase.dart';
import 'package:bb_mobile/features/recipients/application/usecases/check_sinpe_usecase.dart';
import 'package:bb_mobile/features/recipients/application/usecases/get_recipients_usecase.dart';
import 'package:bb_mobile/features/recipients/application/usecases/list_cad_billers_usecase.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_flow_step.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipients_location.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/cad_biller_view_model.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/recipient_filter_criteria.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_form_data_model.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_view_model.dart';
import 'package:bb_mobile/features/virtual_iban/presentation/virtual_iban_bloc.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'recipients_event.dart';
part 'recipients_state.dart';
part 'recipients_bloc.freezed.dart';

class RecipientsBloc extends Bloc<RecipientsEvent, RecipientsState> {
  RecipientsBloc({
    RecipientFilterCriteria? allowedRecipientFilters,
    Future<void>? Function(RecipientViewModel recipient, {required bool isNew})?
    onRecipientSelectedHook,
    required AddRecipientUsecase addRecipientUsecase,
    required GetRecipientsUsecase getRecipientsUsecase,
    required CheckSinpeUsecase checkSinpeUsecase,
    required ListCadBillersUsecase listCadBillersUsecase,
  }) : _onRecipientSelectedHook = onRecipientSelectedHook,
       _addRecipientUsecase = addRecipientUsecase,
       _getRecipientsUsecase = getRecipientsUsecase,
       _checkSinpeUsecase = checkSinpeUsecase,
       _listCadBillersUsecase = listCadBillersUsecase,
       super(
         RecipientsState(
           allowedRecipientFilters:
               allowedRecipientFilters ?? const RecipientFilterCriteria(),
         ),
       ) {
    on<RecipientsStarted>(_onStarted);
    on<RecipientsMoreLoaded>(_onMoreLoaded);
    on<RecipientsAdded>(_onAdded);
    on<RecipientsSinpeChecked>(_onSinpeChecked);
    on<RecipientsCadBillersSearched>(_onCadBillersSearched);
    on<RecipientsSelected>(_onSelected);
    // Virtual IBAN step flow navigation handlers
    on<RecipientsNextStepPressed>(_onNextStepPressed);
    on<RecipientsPreviousStepPressed>(_onPreviousStepPressed);
    on<RecipientsVirtualIbanActivated>(_onVirtualIbanActivated);
    on<RecipientsFallbackToRegularSepa>(_onFallbackToRegularSepa);
    // Virtual IBAN default type selection handler
    on<RecipientsDefaultTypeSelected>(_onDefaultTypeSelected);
  }

  static const pageSize = 50;
  final Future<void>? Function(
    RecipientViewModel recipient, {
    required bool isNew,
  })?
  _onRecipientSelectedHook;
  final AddRecipientUsecase _addRecipientUsecase;
  final GetRecipientsUsecase _getRecipientsUsecase;
  final CheckSinpeUsecase _checkSinpeUsecase;
  final ListCadBillersUsecase _listCadBillersUsecase;

  Future<void> _onStarted(
    RecipientsStarted event,
    Emitter<RecipientsState> emit,
  ) async {
    emit(
      state.copyWith(
        isLoadingRecipients: true,
        recipients: null,
        failedToLoadRecipients: null,
      ),
    );

    // Check VIBAN status for EUR sell/withdraw flows
    // Read directly from the singleton VirtualIbanBloc (like BB-Exchange pattern)
    final isVibanEligible =
        state.allowedRecipientFilters.location.isVirtualIbanEligible;
    if (isVibanEligible) {
      _checkAndSetVirtualIbanDefaults(emit);
    }

    // If skipTypeSelection is true and we're in a step-based flow,
    // skip directly to the enterDetails step (shows tabs/list)
    if (event.skipTypeSelection &&
        state.allowedRecipientFilters.location.usesStepBasedFlow) {
      log.info('Skipping type selection step, going directly to enterDetails');
      emit(state.copyWith(currentStep: RecipientFlowStep.enterDetails));
    }

    try {
      log.info('Loading first recipients');
      final result = await _getRecipientsUsecase.execute(
        GetRecipientsParams(pageSize: pageSize),
      );
      log.fine(
        'Loaded first ${result.recipients.length} recipients of ${result.totalRecipients} total',
      );
      emit(
        state.copyWith(
          totalRecipients: result.totalRecipients,
          recipients: result.recipients
              .map((recipient) {
                // Wrap each transformation in try/catch so a single malformed element
                // doesn't fail the entire list. Nulls are filtered out with the
                // whereType.
                try {
                  return RecipientViewModel.fromDto(recipient);
                } catch (err, stackTrace) {
                  log.severe(
                    'Error transforming recipient to view model: $err',
                    trace: stackTrace,
                  );
                  return null;
                }
              })
              .whereType<RecipientViewModel>()
              .toList(),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          failedToLoadRecipients: Exception('Failed to load recipients: $e'),
        ),
      );
    } finally {
      emit(state.copyWith(isLoadingRecipients: false));
    }
  }

  /// Checks VIBAN status and sets default recipient type to frPayee if active.
  /// Reads directly from the singleton VirtualIbanBloc (like BB-Exchange pattern).
  void _checkAndSetVirtualIbanDefaults(
    Emitter<RecipientsState> emit,
  ) {
    try {
      // Read directly from the singleton VirtualIbanBloc
      final vibanBloc = locator<VirtualIbanBloc>();
      final isVibanActive = vibanBloc.state.isActive;

      if (isVibanActive) {
        log.info('Virtual IBAN is active, setting hasActiveVirtualIban=true');
        emit(state.copyWith(hasActiveVirtualIban: true));

        // Auto-select frPayee as the default type for EUR flows
        final availableTypes = state.selectableRecipientTypes;

        RecipientType? preferredType;
        if (availableTypes.contains(RecipientType.frVirtualAccount)) {
          preferredType = RecipientType.frVirtualAccount;
        } else if (availableTypes.contains(RecipientType.frPayee)) {
          preferredType = RecipientType.frPayee;
        }

        if (preferredType != null) {
          log.info(
            'Auto-selecting $preferredType as default recipient type for VIBAN',
          );
          final updatedFilters = state.allowedRecipientFilters.copyWith(
            defaultSelectedType: preferredType,
          );
          emit(state.copyWith(allowedRecipientFilters: updatedFilters));
        }
      }
    } catch (e) {
      // Don't fail the entire flow if VIBAN check fails
      log.warning('Failed to check Virtual IBAN status: $e');
    }
  }

  Future<void> _onMoreLoaded(
    RecipientsMoreLoaded event,
    Emitter<RecipientsState> emit,
  ) async {
    if (state.isLoadingRecipients || !state.hasMoreRecipientsToLoad) {
      return;
    }

    emit(
      state.copyWith(isLoadingRecipients: true, failedToLoadRecipients: null),
    );
    try {
      log.info('Loading more recipients');
      final result = await _getRecipientsUsecase.execute(
        GetRecipientsParams(
          page: (state.recipients!.length ~/ pageSize) + 1,
          pageSize: pageSize,
        ),
      );
      log.fine(
        'Loaded additional ${result.recipients.length} recipients, '
        'total loaded: ${state.recipients!.length + result.recipients.length} '
        'of ${result.totalRecipients} total',
      );
      emit(
        state.copyWith(
          totalRecipients: result.totalRecipients,
          recipients: [
            ...state.recipients!,
            ...result.recipients.map((recipient) {
              // Wrap each transformation in try/catch so a single malformed element
              // doesn't fail the entire list. Nulls are filtered out with the
              // whereType.
              try {
                return RecipientViewModel.fromDto(recipient);
              } catch (err, stackTrace) {
                log.severe(
                  'Error transforming recipient to view model: $err',
                  trace: stackTrace,
                );
                return null;
              }
            }).whereType<RecipientViewModel>(),
          ],
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          failedToLoadRecipients: Exception(
            'Failed to load more recipients: $e',
          ),
        ),
      );
    } finally {
      emit(state.copyWith(isLoadingRecipients: false));
    }
  }

  Future<void> _onAdded(
    RecipientsAdded event,
    Emitter<RecipientsState> emit,
  ) async {
    emit(state.copyWith(isAddingRecipient: true, failedToAddRecipient: null));
    try {
      log.info('Trying to add recipient: ${event.recipient}');
      final result = await _addRecipientUsecase.execute(
        AddRecipientParams(recipientDetails: event.recipient.toDto()),
      );
      log.fine(
        'Successfully added recipient with ID: ${result.recipient.recipientId}',
      );
      final addedRecipient = RecipientViewModel.fromDto(result.recipient);

      // Call the selection hook for the newly added recipient
      if (_onRecipientSelectedHook != null) {
        await _onRecipientSelectedHook(addedRecipient, isNew: true);
      }
    } catch (e) {
      emit(
        state.copyWith(
          failedToAddRecipient: Exception('Failed to add recipient: $e'),
        ),
      );
    } finally {
      emit(state.copyWith(isAddingRecipient: false));
    }
  }

  Future<void> _onSinpeChecked(
    RecipientsSinpeChecked event,
    Emitter<RecipientsState> emit,
  ) async {
    emit(
      state.copyWith(
        isCheckingSinpe: true,
        sinpeOwnerName: '',
        failedToCheckSinpe: null,
      ),
    );
    try {
      log.info('Checking SINPE for phone number: ${event.phoneNumber}');
      final result = await _checkSinpeUsecase.execute(
        CheckSinpeParams(phoneNumber: event.phoneNumber),
      );
      log.fine('SINPE check result: $result');
      emit(state.copyWith(sinpeOwnerName: result.ownerName));
    } catch (e) {
      emit(
        state.copyWith(
          failedToCheckSinpe: Exception('Failed to check SINPE: $e'),
        ),
      );
    } finally {
      emit(state.copyWith(isCheckingSinpe: false));
    }
  }

  Future<void> _onCadBillersSearched(
    RecipientsCadBillersSearched event,
    Emitter<RecipientsState> emit,
  ) async {
    emit(
      state.copyWith(
        isSearchingCadBillers: true,
        cadBillers: null,
        failedToSearchCadBillers: null,
      ),
    );
    try {
      log.info('Searching CAD billers with query: ${event.query}');
      final result = await _listCadBillersUsecase.execute(
        ListCadBillersParams(searchTerm: event.query),
      );
      log.fine('Found ${result.billers.length} CAD billers');
      emit(
        state.copyWith(
          cadBillers: result.billers
              .map((biller) {
                // Wrap each transformation in try/catch so a single malformed element
                // doesn't fail the entire list. Nulls are filtered out with the
                // whereType.
                try {
                  return CadBillerViewModel.fromDto(biller);
                } catch (err, stackTrace) {
                  log.severe(
                    'Error transforming biller to view model: $err',
                    trace: stackTrace,
                  );
                  return null;
                }
              })
              .whereType<CadBillerViewModel>()
              .toList(),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          failedToSearchCadBillers: Exception(
            'Failed to search CAD billers: $e',
          ),
        ),
      );
    } finally {
      emit(state.copyWith(isSearchingCadBillers: false));
    }
  }

  Future<void> _onSelected(
    RecipientsSelected event,
    Emitter<RecipientsState> emit,
  ) async {
    emit(state.copyWith(failedToSelectRecipient: null));
    try {
      log.info('Recipient selected: ${event.recipient}');
      if (_onRecipientSelectedHook != null) {
        await _onRecipientSelectedHook(event.recipient, isNew: false);
      }
    } catch (e) {
      log.severe('Error in recipient selection logging: $e');
      emit(
        state.copyWith(
          failedToSelectRecipient: Exception(
            'Error when selecting recipient: $e',
          ),
        ),
      );
    }
  }

  // Virtual IBAN step flow navigation handlers

  void _onNextStepPressed(
    RecipientsNextStepPressed event,
    Emitter<RecipientsState> emit,
  ) {
    final location = state.allowedRecipientFilters.location;
    final selectedType = event.selectedType;
    final selectedJurisdiction = selectedType.jurisdictionCode;

    // Store the selected type and jurisdiction for use in Step 2
    emit(
      state.copyWith(
        selectedRecipientType: selectedType,
        selectedJurisdiction: selectedJurisdiction,
      ),
    );

    // VIBAN only for sell/withdraw, NOT pay or accounts view
    if (!location.isVirtualIbanEligible) {
      emit(state.copyWith(currentStep: RecipientFlowStep.enterDetails));
      return;
    }

    // Read current VIBAN status directly from the singleton
    final isVibanActive = locator<VirtualIbanBloc>().state.isActive;

    // If frPayee selected and no active VIBAN, show activation screen
    if (selectedType == RecipientType.frPayee && !isVibanActive) {
      emit(state.copyWith(currentStep: RecipientFlowStep.activateVirtualIban));
      return;
    }

    emit(state.copyWith(currentStep: RecipientFlowStep.enterDetails));
  }

  void _onPreviousStepPressed(
    RecipientsPreviousStepPressed event,
    Emitter<RecipientsState> emit,
  ) {
    // Go back to type selection and clear the selected type
    emit(
      state.copyWith(
        currentStep: RecipientFlowStep.selectType,
        selectedRecipientType: null,
        selectedJurisdiction: null,
      ),
    );
  }

  void _onVirtualIbanActivated(
    RecipientsVirtualIbanActivated event,
    Emitter<RecipientsState> emit,
  ) {
    // VIBAN activation complete, advance to enter details step
    emit(
      state.copyWith(
        currentStep: RecipientFlowStep.enterDetails,
        hasActiveVirtualIban: true,
      ),
    );
  }

  void _onFallbackToRegularSepa(
    RecipientsFallbackToRegularSepa event,
    Emitter<RecipientsState> emit,
  ) {
    // User chose to use regular SEPA (cjPayee) instead of VIBAN
    emit(
      state.copyWith(
        currentStep: RecipientFlowStep.enterDetails,
        selectedRecipientType: RecipientType.cjPayee,
        selectedJurisdiction: 'EU',
      ),
    );
  }

  void _onDefaultTypeSelected(
    RecipientsDefaultTypeSelected event,
    Emitter<RecipientsState> emit,
  ) {
    final updatedFilters = state.allowedRecipientFilters.copyWith(
      defaultSelectedType: event.type,
    );
    emit(state.copyWith(allowedRecipientFilters: updatedFilters));
  }
}
