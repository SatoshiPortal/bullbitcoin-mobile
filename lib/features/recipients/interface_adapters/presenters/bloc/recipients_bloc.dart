import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/recipients/application/usecases/add_recipient_usecase.dart';
import 'package:bb_mobile/features/recipients/application/usecases/check_sinpe_usecase.dart';
import 'package:bb_mobile/features/recipients/application/usecases/get_recipients_usecase.dart';
import 'package:bb_mobile/features/recipients/application/usecases/list_cad_billers_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/cad_biller_view_model.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_form_data_model.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_view_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'recipients_event.dart';
part 'recipients_state.dart';
part 'recipients_bloc.freezed.dart';

class RecipientsBloc extends Bloc<RecipientsEvent, RecipientsState> {
  RecipientsBloc({
    required AddRecipientUsecase addRecipientUsecase,
    required GetRecipientsUsecase getRecipientsUsecase,
    required CheckSinpeUsecase checkSinpeUsecase,
    required ListCadBillersUsecase listCadBillersUsecase,
  }) : _addRecipientUsecase = addRecipientUsecase,
       _getRecipientsUsecase = getRecipientsUsecase,
       _checkSinpeUsecase = checkSinpeUsecase,
       _listCadBillersUsecase = listCadBillersUsecase,
       super(const RecipientsState()) {
    on<RecipientsLoaded>(_onLoaded);
    on<RecipientsAdded>(_onAdded);
    on<RecipientsSinpeChecked>(_onSinpeChecked);
    on<RecipientsCadBillersSearched>(_onCadBillersSearched);
  }

  final AddRecipientUsecase _addRecipientUsecase;
  final GetRecipientsUsecase _getRecipientsUsecase;
  final CheckSinpeUsecase _checkSinpeUsecase;
  final ListCadBillersUsecase _listCadBillersUsecase;

  Future<void> _onLoaded(
    RecipientsLoaded event,
    Emitter<RecipientsState> emit,
  ) async {
    emit(
      state.copyWith(
        isLoadingRecipients: true,
        recipients: [],
        failedToLoadRecipients: null,
      ),
    );
    try {
      log.info('Loading recipients');
      final result = await _getRecipientsUsecase.execute(GetRecipientsParams());
      log.fine('Loaded ${result.recipients.length} recipients');
      emit(
        state.copyWith(
          recipients:
              result.recipients
                  .map((recipient) => RecipientViewModel.fromDto(recipient))
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

  Future<void> _onAdded(
    RecipientsAdded event,
    Emitter<RecipientsState> emit,
  ) async {
    emit(
      state.copyWith(
        isAddingRecipient: true,
        selectedRecipientId: '',
        failedToAddRecipient: null,
      ),
    );
    try {
      log.info('Trying to add recipient: ${event.recipient}');
      final result = await _addRecipientUsecase.execute(
        AddRecipientParams(recipientDetails: event.recipient.toDto()),
      );
      log.fine(
        'Successfully added recipient with ID: ${result.recipient.recipientId}',
      );
      emit(state.copyWith(selectedRecipientId: result.recipient.recipientId));
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
        cadBillers: [],
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
          cadBillers:
              result.billers
                  .map((biller) => CadBillerViewModel.fromDto(biller))
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
}
