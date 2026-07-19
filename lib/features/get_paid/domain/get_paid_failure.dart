import 'package:bb_mobile/core/failures/failure.dart';

sealed class GetPaidFailure extends Failure {
  final bool retryable;

  const GetPaidFailure._({required this.retryable, String? logMessage})
    : super(logMessage);

  const factory GetPaidFailure.unavailable({String? logMessage}) =
      GetPaidUnavailableFailure;

  const factory GetPaidFailure.localPreparation({String? logMessage}) =
      GetPaidLocalPreparationFailure;

  const factory GetPaidFailure.invalidResponse({String? logMessage}) =
      GetPaidInvalidResponseFailure;
}

final class GetPaidUnavailableFailure extends GetPaidFailure {
  const GetPaidUnavailableFailure({super.logMessage})
    : super._(retryable: true);
}

final class GetPaidLocalPreparationFailure extends GetPaidFailure {
  const GetPaidLocalPreparationFailure({super.logMessage})
    : super._(retryable: false);
}

final class GetPaidInvalidResponseFailure extends GetPaidFailure {
  const GetPaidInvalidResponseFailure({super.logMessage})
    : super._(retryable: true);
}
