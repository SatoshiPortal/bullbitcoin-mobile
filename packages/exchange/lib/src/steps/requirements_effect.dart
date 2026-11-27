import 'package:meta/meta.dart';

import 'virtual_iban_effect.dart';
import 'virtual_payee_effect.dart';

@immutable
sealed class RequirementsEffect {
  const RequirementsEffect();
}

final class RequirementVirtualIbanEffect extends RequirementsEffect {
  final VirtualIbanEffect effect;

  const RequirementVirtualIbanEffect(this.effect);

  @override
  bool operator ==(Object other) =>
      other is RequirementVirtualIbanEffect && other.effect == effect;

  @override
  int get hashCode => Object.hash(RequirementVirtualIbanEffect, effect);

  @override
  String toString() => 'RequirementVirtualIbanEffect($effect)';
}

/// A virtual payee effect for the recipient [recipientId].
final class RequirementVirtualPayeeEffect extends RequirementsEffect {
  final String recipientId;
  final VirtualPayeeEffect effect;

  const RequirementVirtualPayeeEffect(this.recipientId, this.effect);

  @override
  bool operator ==(Object other) =>
      other is RequirementVirtualPayeeEffect &&
      other.recipientId == recipientId &&
      other.effect == effect;

  @override
  int get hashCode =>
      Object.hash(RequirementVirtualPayeeEffect, recipientId, effect);

  @override
  String toString() => 'RequirementVirtualPayeeEffect($recipientId, $effect)';
}
