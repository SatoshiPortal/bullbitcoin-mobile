import 'package:labels/labels.dart';

class LoadSendLabelSuggestionsUsecase {
  final LabelsFacade _labels;

  LoadSendLabelSuggestionsUsecase(this._labels);

  Future<Set<String>> execute() => _labels.fetchDistinctLabels();
}
