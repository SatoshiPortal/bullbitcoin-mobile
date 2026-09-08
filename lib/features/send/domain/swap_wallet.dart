import 'package:bb_mobile/features/wallet/domain/wallet.dart';

bool supportsSwapWallet(Wallet wallet) => wallet.isLiquid
    ? !wallet.isHardwareWallet && !wallet.isWatchOnly
    : wallet.isStandardLocalSingleSignatureWallet &&
          wallet.descriptorKeys.every((key) => !key.requiresPassphrase);
