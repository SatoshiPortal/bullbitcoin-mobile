import 'package:primitives/primitives.dart' show FeeSelection;

extension FeeSelectionName on FeeSelection {
  String title() {
    switch (this) {
      case FeeSelection.fastest:
        return 'Fastest';
      case FeeSelection.economic:
        return 'Economic';
      case FeeSelection.slow:
        return 'Slow';
      case FeeSelection.custom:
        return 'Custom Fee';
    }
  }

  static FeeSelection fromString(String value) {
    switch (value) {
      case 'Fastest':
        return FeeSelection.fastest;
      case 'Economic':
        return FeeSelection.economic;
      case 'Slow':
        return FeeSelection.slow;
      case 'Custom Fee':
        return FeeSelection.custom;
      default:
        throw Exception('Unknown fee selection: $value');
    }
  }
}
