import 'package:nostr_pos/nostr_pos.dart' as nostr;

class PosProfileSettings {
  const PosProfileSettings({
    required this.name,
    required this.currency,
    this.allowLiquid = true,
    this.allowLightning = true,
    this.allowBoltCard = true,
  });

  final String name;
  final String currency;
  final bool allowLiquid;
  final bool allowLightning;
  final bool allowBoltCard;

  nostr.PosPaymentMethods get paymentMethods {
    return nostr.PosPaymentMethods(
      liquid: allowLiquid,
      lightningSwap: allowLightning,
      boltCard: allowBoltCard,
    );
  }
}
