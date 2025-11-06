import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/view_models/cad_biller_view_model.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/view_models/recipient_view_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'recipients_event.dart';
part 'recipients_state.dart';
part 'recipients_bloc.freezed.dart';

class RecipientsBloc extends Bloc<RecipientsEvent, RecipientsState> {
  RecipientsBloc() : super(const RecipientsState()) {
    on<LoadRecipientsEvent>(_onLoadRecipients);
    on<AddRecipientEvent>(_onAddRecipient);
    on<CheckSinpeEvent>(_onCheckSinpe);
    on<SearchCadBillersEvent>(_onSearchCadBillers);
  }

  Future<void> _onLoadRecipients(
    LoadRecipientsEvent event,
    Emitter<RecipientsState> emit,
  ) async {
    // Implementation for loading recipients
  }

  Future<void> _onAddRecipient(
    AddRecipientEvent event,
    Emitter<RecipientsState> emit,
  ) async {
    // Implementation for adding a recipient
  }

  Future<void> _onCheckSinpe(
    CheckSinpeEvent event,
    Emitter<RecipientsState> emit,
  ) async {
    // Implementation for checking Sinpe
  }

  Future<void> _onSearchCadBillers(
    SearchCadBillersEvent event,
    Emitter<RecipientsState> emit,
  ) async {
    // Implementation for searching CAD billers
  }
}
