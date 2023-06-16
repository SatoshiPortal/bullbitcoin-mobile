import 'package:flutter_translate/flutter_translate.dart' as tr;

extension X on String {
  String get translate {
    try {
      return tr.translate(this);
    } catch (e) {
      return this;
    }
  }
}
