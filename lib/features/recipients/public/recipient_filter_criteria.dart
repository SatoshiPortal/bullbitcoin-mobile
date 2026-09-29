import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';

class RecipientFilterCriteria {
  final bool? isOwner;
  final List<RecipientType> types;

  const RecipientFilterCriteria({
    this.isOwner,
    this.types = RecipientType.values,
  });
}
