import 'package:bb_mobile/features/labels/labels_facade.dart'
    show LabelType, LabelsFacade;

class GetAddressLabelsUsecase {
  final LabelsFacade _labelsFacade;

  const GetAddressLabelsUsecase({required this._labelsFacade});

  Future<List<String>> execute(String address) async {
    final labels = await _labelsFacade.fetchByReference(address);
    return [
      for (final label in labels)
        if (label.type == LabelType.address) label.label,
    ];
  }
}
