import 'package:exchange/exchange.dart';

class RecipientFilterCriteria {
  final bool? isOwner;
  final List<RecipientType> types;

  RecipientFilterCriteria({this.isOwner, List<RecipientType>? types})
    : types = types ?? RecipientType.standardTypes;

  /// The same criteria as the step library's filter, on rails.
  RecipientFilter get filter => RecipientFilter(
    rails: [for (final type in types) type.rail],
    owner: switch (isOwner) {
      null => null,
      true => RecipientOwnership.own,
      false => RecipientOwnership.thirdParty,
    },
  );
}
