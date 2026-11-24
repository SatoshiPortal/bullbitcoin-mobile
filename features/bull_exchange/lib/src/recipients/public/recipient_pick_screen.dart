import 'package:bull_exchange/src/recipients/public/recipient_filter_criteria.dart';
import 'package:bull_exchange/src/recipients/ui/screens/recipients_screen.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter/widgets.dart';

/// The recipients list and form of a flow's recipient step: shows the
/// recipients [filter] admits and hands the picked (or newly saved) one to
/// [onPicked]. The flow decides with the same filter (`filter.choose`)
/// whether it goes on; [problem] is its answer when it doesn't.
class RecipientPickScreen extends StatelessWidget {
  const RecipientPickScreen({
    super.key,
    required this.filter,
    required this.onPicked,
    this.problem,
  });

  final RecipientFilter filter;
  final void Function(Recipient recipient) onPicked;
  final String? problem;

  @override
  Widget build(BuildContext context) {
    final types = [for (final rail in filter.rails) rail.type];
    return RecipientsScreen(
      filter: RecipientFilterCriteria(
        types: types,
        isOwner: switch (filter.owner) {
          null => null,
          RecipientOwnership.own => true,
          RecipientOwnership.thirdParty => false,
        },
      ),
      onRecipientSelected: (recipient, {required isNew}) {
        onPicked(recipient.recipient);
        return null;
      },
      enforceRecipientFilter: true,
      fixedRecipientType: types.length == 1 ? types.single : null,
      onRecipientAddedHookError: problem,
      onRecipientSelectedHookError: problem,
    );
  }
}
