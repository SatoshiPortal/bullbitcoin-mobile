import 'package:labels/labels.dart';

class LoadSendLabelSuggestionsUsecase {
  final Labels _labels;

  LoadSendLabelSuggestionsUsecase(this._labels);

  Future<Set<String>> execute() async => (await _labels.suggestions()).fold(
    (suggestions) => suggestions,
    (_) => const <String>{},
  );
}
