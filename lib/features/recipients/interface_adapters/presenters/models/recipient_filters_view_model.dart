import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';

class AllowedRecipientFiltersViewModel {
  final bool? isOwner;
  final List<RecipientType> types;

  const AllowedRecipientFiltersViewModel({
    this.isOwner,
    this.types = RecipientType.values,
  });
}
