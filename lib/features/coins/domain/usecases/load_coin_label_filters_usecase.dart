import 'package:labels/labels.dart';

class LoadCoinLabelFiltersUsecase {
  final LabelsFacade _labels;

  LoadCoinLabelFiltersUsecase(this._labels);

  Future<Set<String>> execute() => _labels.fetchDistinctLabels();
}
