import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/settings/domain/wallet_registration.dart';
import 'package:satoshifier/utils/descriptor_checksum.dart';

typedef _RegularMultisig = ({int threshold, int keyCount});

abstract final class WalletRegistrationExportBuilder {
  static List<WalletRegistrationOption> build(
    Wallet wallet,
    BitcoinWalletPolicy policy, {
    String? signerId,
  }) {
    final options = <WalletRegistrationOption>[];
    final exportedDevices = <SignerDeviceEntity>{};
    var hasBitBox = false;
    var hasLedger = false;
    for (final signer in wallet.signers.where(
      (signer) => signerId == null || signer.id == signerId,
    )) {
      final device = signer.signerDevice;
      if (device == null) continue;
      if (device.supportsWalletRegistrationExport) {
        if (exportedDevices.add(device)) {
          options.add(_option(wallet, policy, device, signerId: signer.id));
        }
      } else if (device.isBitBox && !hasBitBox) {
        hasBitBox = true;
        options.add(_connectedOption(wallet, device, signerId: signer.id));
      } else if (device.isLedger && !hasLedger) {
        hasLedger = true;
        options.add(_connectedOption(wallet, device, signerId: signer.id));
      }
    }
    return List.unmodifiable(options);
  }

  static WalletRegistrationOption _connectedOption(
    Wallet wallet,
    SignerDeviceEntity device, {
    required String signerId,
  }) {
    final matchingSigners = wallet.signers.where(
      (signer) => device.isLedger
          ? signer.id == signerId && signer.signerDevice?.isLedger == true
          : signer.id == signerId && signer.signerDevice?.isBitBox == true,
    );
    if (!matchingSigners.any(wallet.hasWalletPolicyKeyOriginsFor)) {
      return UnavailableWalletRegistration(
        device: device,
        reason: WalletRegistrationUnavailableReason.unsupportedKeyOrigins,
      );
    }
    if (!wallet.supportsWalletPolicyOn(device)) {
      return _unsupportedPolicy(device);
    }
    return ConnectedWalletRegistration(device: device);
  }

  static WalletRegistrationOption _option(
    Wallet wallet,
    BitcoinWalletPolicy policy,
    SignerDeviceEntity device, {
    required String signerId,
  }) {
    if (_isTaproot(wallet) && !device.supportsComplexTaprootRegistration) {
      return _unsupportedPolicy(device);
    }
    final regularMultisig = _regularMultisig(policy);
    final fileName = '${_fileStem(wallet)}-${device.name}.txt';

    return switch (device) {
      SignerDeviceEntity.krux => _descriptorOption(
        wallet: wallet,
        device: device,
        fileName: fileName,
        encoding: WalletRegistrationQrEncoding.urBytes,
        supportsPolicy:
            regularMultisig != null || _supportsDescriptorRegistration(wallet),
      ),
      SignerDeviceEntity.specter => _specterOption(
        wallet: wallet,
        device: device,
        fileName: fileName,
        signerId: signerId,
      ),
      SignerDeviceEntity.coldcardQ => _coldcardOption(
        wallet: wallet,
        device: device,
        regularMultisig: regularMultisig,
        fileName: fileName,
        qrEncoding: WalletRegistrationQrEncoding.bbqrText,
      ),
      SignerDeviceEntity.coldcardMk4 => _coldcardOption(
        wallet: wallet,
        device: device,
        regularMultisig: regularMultisig,
        fileName: fileName,
        qrEncoding: WalletRegistrationQrEncoding.none,
      ),
      SignerDeviceEntity.jade ||
      SignerDeviceEntity.keystone => _commonMultisigOption(
        wallet: wallet,
        device: device,
        regularMultisig: _isTaproot(wallet) ? null : regularMultisig,
        fileName: fileName,
        allowLegacy: true,
        nameMaxLength: device == SignerDeviceEntity.jade ? 15 : 16,
        signerId: signerId,
      ),
      SignerDeviceEntity.passport =>
        _isTaproot(wallet)
            ? _unsupportedPolicy(device)
            : regularMultisig == null
            ? _descriptorOption(
                wallet: wallet,
                device: device,
                fileName: fileName,
                encoding: WalletRegistrationQrEncoding.urBytes,
                supportsPolicy:
                    _supportsDescriptorRegistration(wallet) &&
                    !policy.hasHashlock,
              )
            : _commonMultisigOption(
                wallet: wallet,
                device: device,
                regularMultisig: regularMultisig,
                fileName: fileName,
                allowLegacy: false,
                nameMaxLength: 16,
                signerId: signerId,
              ),
      SignerDeviceEntity.seedsigner => _commonMultisigOption(
        wallet: wallet,
        device: device,
        regularMultisig: _isTaproot(wallet) ? null : regularMultisig,
        fileName: fileName,
        allowLegacy: false,
        nameMaxLength: 16,
        signerId: signerId,
      ),
      SignerDeviceEntity.bitbox02 ||
      SignerDeviceEntity.ledgerNanoSPlus ||
      SignerDeviceEntity.ledgerNanoX ||
      SignerDeviceEntity.ledgerFlex ||
      SignerDeviceEntity.ledgerStax => throw StateError(
        'Connected devices do not use registration exports',
      ),
    };
  }

  static WalletRegistrationOption _descriptorOption({
    required Wallet wallet,
    required SignerDeviceEntity device,
    required String fileName,
    required WalletRegistrationQrEncoding encoding,
    required bool supportsPolicy,
  }) {
    if (!supportsPolicy) return _unsupportedPolicy(device);
    return AvailableWalletRegistration(
      device: device,
      qrData: wallet.publicDescriptor,
      qrEncoding: encoding,
      fileData: wallet.publicDescriptor,
      fileName: fileName,
    );
  }

  static WalletRegistrationOption _coldcardOption({
    required Wallet wallet,
    required SignerDeviceEntity device,
    required _RegularMultisig? regularMultisig,
    required String fileName,
    required WalletRegistrationQrEncoding qrEncoding,
  }) {
    if (_isTaproot(wallet)) {
      return _unsupportedPolicy(device);
    }
    if (regularMultisig == null) return _unsupportedPolicy(device);
    if (!wallet.hasWalletPolicyKeyOrigins) {
      return UnavailableWalletRegistration(
        device: device,
        reason: WalletRegistrationUnavailableReason.unsupportedKeyOrigins,
      );
    }
    final descriptor = _externalDescriptor(wallet.publicDescriptor);
    return AvailableWalletRegistration(
      device: device,
      qrData: qrEncoding == WalletRegistrationQrEncoding.none ? '' : descriptor,
      qrEncoding: qrEncoding,
      fileData: descriptor,
      fileName: fileName,
    );
  }

  static WalletRegistrationOption _specterOption({
    required Wallet wallet,
    required SignerDeviceEntity device,
    required String fileName,
    required String signerId,
  }) {
    final descriptor = wallet.publicDescriptor
        .split('#')
        .first
        .replaceAllMapped(
          RegExp(r'<([0-9]+);([0-9]+)>'),
          (match) => '{${match.group(1)},${match.group(2)}}',
        );
    final command =
        'addwallet ${_walletName(wallet, 20, signerId: signerId)}&$descriptor';
    return AvailableWalletRegistration(
      device: device,
      qrData: command,
      qrEncoding: WalletRegistrationQrEncoding.urBytes,
      fileData: command,
      fileName: fileName,
    );
  }

  static WalletRegistrationOption _commonMultisigOption({
    required Wallet wallet,
    required SignerDeviceEntity device,
    required _RegularMultisig? regularMultisig,
    required String fileName,
    required bool allowLegacy,
    required int nameMaxLength,
    required String signerId,
  }) {
    final format = _commonMultisigFormat(wallet);
    if (regularMultisig == null || format == null) {
      return _unsupportedPolicy(device);
    }
    if (!allowLegacy && format == 'P2SH') return _unsupportedPolicy(device);
    if (device == SignerDeviceEntity.seedsigner &&
        (regularMultisig.threshold > 9 || regularMultisig.keyCount > 9)) {
      return _unsupportedPolicy(device);
    }

    final keys = _commonMultisigKeys(wallet);
    final paths = keys.map((key) => key.derivationPath).toSet();
    if (regularMultisig.keyCount != keys.length || paths.length != 1) {
      return UnavailableWalletRegistration(
        device: device,
        reason: WalletRegistrationUnavailableReason.unsupportedKeyOrigins,
      );
    }

    final setup = _commonMultisigSetup(
      wallet: wallet,
      threshold: regularMultisig.threshold,
      format: format,
      keys: keys,
      nameMaxLength: nameMaxLength,
      signerId: signerId,
    );
    return AvailableWalletRegistration(
      device: device,
      qrData: setup,
      qrEncoding: WalletRegistrationQrEncoding.urBytes,
      fileData: setup,
      fileName: fileName,
    );
  }

  static _RegularMultisig? _regularMultisig(BitcoinWalletPolicy policy) {
    _RegularMultisig? inspect(BitcoinSpendingPolicy spendingPolicy) {
      final root = spendingPolicy.root;
      if (spendingPolicy.requiresPath ||
          root is! BitcoinThresholdPolicyNode ||
          root.requiresPath ||
          root.children.any((child) => child is! BitcoinSignaturePolicyNode)) {
        return null;
      }
      return (threshold: root.threshold, keyCount: root.children.length);
    }

    final external = inspect(policy.external);
    final internal = inspect(policy.internal);
    if (external == null || external != internal) return null;
    return external;
  }

  static String _commonMultisigSetup({
    required Wallet wallet,
    required int threshold,
    required String format,
    required List<_CommonMultisigKey> keys,
    required int nameMaxLength,
    required String signerId,
  }) {
    final path = _apostrophePath(keys.first.derivationPath);
    final buffer = StringBuffer()
      ..writeln('# Bull wallet multisig setup file')
      ..writeln(
        'Name: ${_walletName(wallet, nameMaxLength, signerId: signerId)}',
      )
      ..writeln('Policy: $threshold of ${keys.length}')
      ..writeln('Derivation: $path')
      ..writeln('Format: $format')
      ..writeln();
    for (final key in keys) {
      buffer.writeln('${key.masterFingerprint.toUpperCase()}: ${key.xpub}');
    }
    return buffer.toString();
  }

  static List<_CommonMultisigKey> _commonMultisigKeys(Wallet wallet) => [
    for (final match in _CommonMultisigKey.pattern.allMatches(
      wallet.publicDescriptor.split('#').first,
    ))
      _CommonMultisigKey.fromMatch(match, wallet: wallet),
  ];

  static String? _commonMultisigFormat(Wallet wallet) {
    final descriptor = wallet.publicDescriptor.toLowerCase();
    if (!descriptor.contains('sortedmulti(')) return null;
    if (descriptor.startsWith('sh(wsh(')) return 'P2WSH-P2SH';
    if (descriptor.startsWith('wsh(')) return 'P2WSH';
    if (descriptor.startsWith('sh(')) return 'P2SH';
    return null;
  }

  static bool _supportsDescriptorRegistration(Wallet wallet) {
    final descriptor = wallet.publicDescriptor.toLowerCase();
    return descriptor.startsWith('wsh(') || descriptor.startsWith('tr(');
  }

  static bool _isTaproot(Wallet wallet) =>
      wallet.publicDescriptor.toLowerCase().startsWith('tr(');

  static UnavailableWalletRegistration _unsupportedPolicy(
    SignerDeviceEntity device,
  ) => UnavailableWalletRegistration(
    device: device,
    reason: WalletRegistrationUnavailableReason.unsupportedPolicy,
  );

  static String _externalDescriptor(String descriptor) {
    final body = descriptor
        .split('#')
        .first
        .replaceAllMapped(
          RegExp(r'<([0-9]+);[0-9]+>'),
          (match) => match.group(1)!,
        );
    final checksum = DescriptorChecksum.compute(body);
    if (checksum == null) throw const FormatException('Invalid descriptor');
    return '$body#$checksum';
  }

  static String _walletName(Wallet wallet, int maxLength, {String? signerId}) {
    final idPrefix = wallet.id.length <= 8
        ? wallet.id
        : wallet.id.substring(0, 8);
    String? registrationName;
    for (final signer in wallet.signers) {
      if ((signerId == null || signer.id == signerId) &&
          signer.registrationName != null) {
        registrationName = signer.registrationName;
        break;
      }
    }
    final source = registrationName?.trim().isNotEmpty == true
        ? registrationName!.trim()
        : wallet.label?.trim().isNotEmpty == true
        ? wallet.label!.trim()
        : 'Bull $idPrefix';
    final sanitized = source
        .replaceAll(RegExp(r'[^\x20-\x7E]'), ' ')
        .replaceAll(RegExp(r'[&:\r\n]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final fallback = sanitized.isEmpty ? 'Bull Wallet' : sanitized;
    return fallback.length <= maxLength
        ? fallback
        : fallback.substring(0, maxLength);
  }

  static String _fileStem(Wallet wallet) => _walletName(wallet, 32)
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');

  static String _apostrophePath(String path) => path.replaceAllMapped(
    RegExp(r'([0-9])[hH](?=/|$)'),
    (match) => "${match.group(1)}'",
  );
}

final class _CommonMultisigKey {
  static final pattern = RegExp(
    r"\[([0-9a-fA-F]{8})((?:/[0-9]+(?:'|h)?)+)\]"
    r'((?:xpub|tpub)[1-9A-HJ-NP-Za-km-z]+)'
    r'((?:/[0-9]+)*)/<0;1>/\*',
  );

  final String masterFingerprint;
  final String derivationPath;
  final String xpub;

  const _CommonMultisigKey({
    required this.masterFingerprint,
    required this.derivationPath,
    required this.xpub,
  });

  factory _CommonMultisigKey.fromMatch(
    RegExpMatch match, {
    required Wallet wallet,
  }) {
    final suffix = match.group(4)!;
    final baseXpub = match.group(3)!;
    final xpub = suffix.isEmpty
        ? baseXpub
        : Bip32Derivation.getBip32Xpub(baseXpub)
              .derivePath(suffix.substring(1))
              .convert(wallet.isTestnet ? XpubType.tpub : XpubType.xpub);
    return _CommonMultisigKey(
      masterFingerprint: match.group(1)!.toLowerCase(),
      derivationPath: 'm${match.group(2)}$suffix',
      xpub: xpub,
    );
  }
}
