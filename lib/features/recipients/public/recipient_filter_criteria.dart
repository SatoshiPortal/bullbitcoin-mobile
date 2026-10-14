import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';

class RecipientFilterCriteria {
  final bool? isOwner;
  final List<RecipientType> types;

  RecipientFilterCriteria({this.isOwner, List<RecipientType>? types})
    : types = types ?? RecipientType.standardTypes;
}
