import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipients_location.dart';

class AllowedRecipientFiltersViewModel {
  final bool? isOwner;
  final List<RecipientType> types;
  final RecipientsLocation location;
  final RecipientType? defaultSelectedType;

  const AllowedRecipientFiltersViewModel({
    this.isOwner,
    this.types = RecipientType.values,
    this.location = RecipientsLocation.accountsView,
    this.defaultSelectedType,
  });

  /// Creates a copy with the given fields replaced
  AllowedRecipientFiltersViewModel copyWith({
    bool? isOwner,
    List<RecipientType>? types,
    RecipientsLocation? location,
    RecipientType? defaultSelectedType,
  }) {
    return AllowedRecipientFiltersViewModel(
      isOwner: isOwner ?? this.isOwner,
      types: types ?? this.types,
      location: location ?? this.location,
      defaultSelectedType: defaultSelectedType ?? this.defaultSelectedType,
    );
  }
}
