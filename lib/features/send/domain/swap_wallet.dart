import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

bool supportsSwapWallet(Wallet wallet) => wallet.isLiquid
    ? !wallet.isHardwareWallet && !wallet.isWatchOnly
    : wallet.isStandardLocalSingleSignatureWallet &&
          wallet.descriptorKeys.every((key) => !key.requiresPassphrase);
