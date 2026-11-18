import 'package:meta/meta.dart';
import 'package:ark/ark.dart';
import 'package:primitives/primitives.dart';

import 'ark_failure.dart';

/// Host admission must acquire parent custody, verify ready/present parent and
/// publish its durable Ark reference before invoking create. Publication must
/// survive failure or process death until authoritative obligation retirement.
/// Child derivation must never re-acquire the parent lock inside native locks.
abstract interface class ArkProvisioningPort {
  @useResult
  Future<Result<ArkSnapshot, ArkFailure>> run(
    ArkAccountConfig config,
    Future<Result<ArkSnapshot, ArkFailure>> Function() create,
  );
}
