import 'package:bb_arch/settings/view/widgets/menu_widget.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'currency.freezed.dart';
part 'currency.g.dart';

@freezed
class Currency with _$Currency {
  const factory Currency({
    required String name,
    required double? price,
    required String code,
    required bool isFiat,
  }) = _Currency;
  const Currency._();

  factory Currency.fromJson(Map<String, dynamic> json) => _$CurrencyFromJson(json);

  static List<DropDownItem>  toDropDownItems(List<Currency> currencies) {
    return currencies.map((Currency currency) {
      return DropDownItem(text: currency.name, value: currency.code);
    }).toList();
  }
}
