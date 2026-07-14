class LightningAddressRegistration {
  final String nym;
  final String lightningAddress;

  const LightningAddressRegistration({
    required this.nym,
    required this.lightningAddress,
  });
}

class LightningAddressStatus {
  final String nym;
  final bool active;
  final String? lightningAddress;
  final LightningAddressPermanentNameStatus? permanentNameStatus;

  const LightningAddressStatus({
    required this.nym,
    required this.active,
    this.lightningAddress,
    this.permanentNameStatus,
  });
}

class LightningAddressPermanentNameStatus {
  final String nym;
  final bool lightningAddressOnline;
  final LightningAddressPermanentNameQuota quota;

  const LightningAddressPermanentNameStatus({
    required this.nym,
    required this.lightningAddressOnline,
    required this.quota,
  });
}

class LightningAddressPermanentNameQuota {
  final int used;
  final int cap;
  final int remaining;

  const LightningAddressPermanentNameQuota({
    required this.used,
    required this.cap,
    required this.remaining,
  });
}
