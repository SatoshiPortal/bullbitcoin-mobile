import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/bloc/recipients_bloc.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_form_data_model.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_view_model.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

void submitRecipientForm(
  BuildContext context,
  RecipientFormDataModel formData, {
  RecipientViewModel? recipient,
}) {
  final event = recipient == null
      ? RecipientsEvent.added(formData)
      : RecipientsEvent.updated(
          recipientId: recipient.id,
          recipient: formData.toDomain(),
        );
  context.read<RecipientsBloc>().add(event);
}

String? recipientUpdateFieldError(BuildContext context, String field) {
  final failure = context.select(
    (RecipientsBloc bloc) => bloc.state.failedToUpdateRecipient,
  );
  return failure is RecipientsInvalidFieldsFailure &&
          failure.fields.contains(field)
      ? context.loc.oopsSomethingWentWrong
      : null;
}
