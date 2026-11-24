import 'package:bull_ark/ark_ui_setup.dart'
    show ArkSourceWalletName, ArkDefaultSourceWallet, ArkNamedSourceWallet;

import 'models/wallet_metadata_model.dart';

/// Names the source wallet as the wallet list does: the default wallet by the
/// app's default name, any other by its label or, without one, its origin.
ArkSourceWalletName? arkSourceWalletName(WalletMetadataModel? metadata) =>
    switch (metadata) {
      null => null,
      WalletMetadataModel(isDefault: true) => const ArkDefaultSourceWallet(),
      WalletMetadataModel(:final label?) when label.trim().isNotEmpty =>
        ArkNamedSourceWallet(label),
      final other => ArkNamedSourceWallet(other.origin),
    };
