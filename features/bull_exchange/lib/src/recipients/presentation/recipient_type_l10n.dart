import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_exchange/src/recipients/presentation/payout_rail_l10n.dart';
import 'package:bull_exchange/src/recipients/public/recipient_selection.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter/widgets.dart';

extension RecipientTypeL10n on RecipientType {
  String label(BuildContext context) => rail.label(context);
}

extension RecipientSelectionL10n on RecipientSelection {
  /// The row that identifies the account, labelled by its kind.
  ({String label, String? value}) accountDetail(BuildContext context) =>
      switch (accountRows) {
        [final row, ...] => (label: row.field.label(context), value: row.value),
        [] => (label: context.loc.recipientsInfoAccount, value: null),
      };
}
