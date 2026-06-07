class BullnymQuotaDto {
  final int used;
  final int cap;
  final int remaining;

  const BullnymQuotaDto({
    required this.used,
    required this.cap,
    required this.remaining,
  });

  factory BullnymQuotaDto.fromJson(Object? json) {
    final map = json is Map<String, dynamic> ? json : const <String, dynamic>{};
    final used = (map['used'] as num?)?.toInt() ?? 0;
    final cap = (map['cap'] as num?)?.toInt() ?? 0;
    return BullnymQuotaDto(
      used: used,
      cap: cap,
      remaining:
          (map['remaining'] as num?)?.toInt() ??
          ((cap - used).clamp(0, cap) as num).toInt(),
    );
  }
}

class BullnymPreviousNymDto {
  final String nym;
  final DateTime createdAt;

  const BullnymPreviousNymDto({required this.nym, required this.createdAt});

  factory BullnymPreviousNymDto.fromJson(Map<String, dynamic> json) {
    return BullnymPreviousNymDto(
      nym: json['nym'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class BullnymRegisterResponseDto {
  final String nym;
  final String lightningAddress;
  final BullnymQuotaDto quota;

  const BullnymRegisterResponseDto({
    required this.nym,
    required this.lightningAddress,
    required this.quota,
  });

  factory BullnymRegisterResponseDto.fromJson(Map<String, dynamic> json) {
    return BullnymRegisterResponseDto(
      nym: json['nym'] as String,
      lightningAddress: json['lightning_address'] as String,
      quota: BullnymQuotaDto.fromJson(json['quota']),
    );
  }
}

class BullnymDeleteResponseDto {
  final BullnymQuotaDto quota;

  const BullnymDeleteResponseDto({required this.quota});

  factory BullnymDeleteResponseDto.fromJson(Map<String, dynamic> json) {
    return BullnymDeleteResponseDto(
      quota: BullnymQuotaDto.fromJson(json['quota']),
    );
  }
}

class BullnymLookupResponseDto {
  final String nym;
  final bool active;
  final BullnymQuotaDto quota;
  final List<BullnymPreviousNymDto> previousNyms;

  const BullnymLookupResponseDto({
    required this.nym,
    required this.active,
    required this.quota,
    required this.previousNyms,
  });

  factory BullnymLookupResponseDto.fromJson(Map<String, dynamic> json) {
    final rawPrevious = json['previous_nyms'];
    return BullnymLookupResponseDto(
      nym: json['nym'] as String,
      active: json['active'] as bool,
      quota: BullnymQuotaDto.fromJson(json['quota']),
      previousNyms: rawPrevious is List
          ? [
              for (final item in rawPrevious)
                BullnymPreviousNymDto.fromJson(item as Map<String, dynamic>),
            ]
          : const [],
    );
  }
}
