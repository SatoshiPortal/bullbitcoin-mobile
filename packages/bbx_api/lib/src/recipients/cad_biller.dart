import 'package:meta/meta.dart';

/// A Canadian bill payment payee from `listAplBillers`.
@immutable
class CadBiller {
  final String payeeCode;
  final String payeeName;

  const CadBiller({required this.payeeCode, required this.payeeName});
}

/// The billers that match a search. An element that is not a valid
/// [CadBiller] is left out and counted in [skippedElements].
@immutable
class CadBillerSearch {
  final List<CadBiller> billers;
  final int skippedElements;

  const CadBillerSearch({required this.billers, this.skippedElements = 0});
}
