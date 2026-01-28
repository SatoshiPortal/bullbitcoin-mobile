import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipients_location.dart';

class RecipientFilterCriteria {
  final bool? isOwner;
  final List<RecipientType> types;
  final RecipientsLocation location;
  final RecipientType? defaultSelectedType;

  const RecipientFilterCriteria({
    this.isOwner,
    this.types = RecipientType.values,
    this.location = RecipientsLocation.accountsView,
    this.defaultSelectedType,
  });

  /// Creates a copy with the given fields replaced
  RecipientFilterCriteria copyWith({
    bool? isOwner,
    List<RecipientType>? types,
    RecipientsLocation? location,
    RecipientType? defaultSelectedType,
  }) {
    return RecipientFilterCriteria(
      isOwner: isOwner ?? this.isOwner,
      types: types ?? this.types,
      location: location ?? this.location,
      defaultSelectedType: defaultSelectedType ?? this.defaultSelectedType,
    );
  }
}
