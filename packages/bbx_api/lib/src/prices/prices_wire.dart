import 'package:bbx_api/src/bbx_format_exception.dart';
import 'package:bbx_api/src/json.dart';
import 'package:bbx_api/src/prices/user_rate.dart';

/// Throws a [BbxFormatException] naming the first invalid field.
UserRate parseUserRate(Map<String, dynamic> json) => UserRate(
  fromCurrency: read<String?>(json['fromCurrency'], 'fromCurrency'),
  indexPrice: read<num>(json['indexPrice'], 'indexPrice'),
  userPrice: read<num>(json['userPrice'], 'userPrice'),
  precision: read<int?>(json['precision'], 'precision'),
);
