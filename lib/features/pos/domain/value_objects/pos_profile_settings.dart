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
}
