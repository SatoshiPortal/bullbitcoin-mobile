import 'package:meta/meta.dart';

@immutable
sealed class InteracSecurityEvent {
  const InteracSecurityEvent();
}

final class InteracQuestionTyped extends InteracSecurityEvent {
  final String text;

  const InteracQuestionTyped(this.text);
}

final class InteracAnswerTyped extends InteracSecurityEvent {
  final String text;

  const InteracAnswerTyped(this.text);
}

final class InteracSaveAsDefaultSet extends InteracSecurityEvent {
  final bool save;

  const InteracSaveAsDefaultSet({required this.save});
}

final class InteracContinuePressed extends InteracSecurityEvent {
  const InteracContinuePressed();
}

/// Back to the answer from the next step.
final class InteracEditPressed extends InteracSecurityEvent {
  const InteracEditPressed();
}
