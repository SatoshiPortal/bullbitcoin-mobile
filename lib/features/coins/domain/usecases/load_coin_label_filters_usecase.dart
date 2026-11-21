import 'package:labels/labels.dart';

class LoadCoinLabelFiltersUsecase {
  final Labels _labels;

  LoadCoinLabelFiltersUsecase(this._labels);

  Future<Set<String>> execute() async => (await _labels.suggestions()).fold(
    (suggestions) => suggestions,
    (_) => const <String>{},
  );
}
