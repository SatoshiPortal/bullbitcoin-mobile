import 'package:bull_exchange/src/recipients/presentation/recipients_bloc.dart';
import 'package:bull_exchange/src/presentation/exchange_failure_l10n.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

extension RecipientServerFieldError on BuildContext {
  /// The message for [field] when the exchange refused it on the last save,
  /// shown under the field until the next save. Rebuilds the caller when
  /// the save failure changes.
  String? recipientServerFieldError(RecipientField field) {
    final failure = select(
      (RecipientsBloc bloc) => bloc.state.failedToAddRecipient,
    );
    return switch (failure) {
      ExchangeRecipientsInvalidFieldsFailure(:final fields) =>
        fields[field]?.toTranslated(this),
      _ => null,
    };
  }
}
