import 'package:exchange/exchange.dart';

class RecipientFilterCriteria {
  final bool? isOwner;
  final List<RecipientType> types;

  RecipientFilterCriteria({this.isOwner, List<RecipientType>? types})
    : types = types ?? RecipientType.standardTypes;
}
