/// GENERATED CODE - DO NOT MODIFY BY HAND
/// *****************************************************
///  FlutterGen
/// *****************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: directives_ordering,unnecessary_import,implicit_dynamic_list_literal,deprecated_member_use

import 'package:flutter/widgets.dart';

class $AssetsI18nGen {
  const $AssetsI18nGen();

  /// File path: assets/i18n/en.json
  String get en => 'assets/i18n/en.json';

  /// File path: assets/i18n/fr.json
  String get fr => 'assets/i18n/fr.json';

  /// List of all assets
  List<String> get values => [en, fr];
}

class $AssetsIconsGen {
  const $AssetsIconsGen();

  /// File path: assets/icons/btc.png
  AssetGenImage get btc => const AssetGenImage('assets/icons/btc.png');

  /// File path: assets/icons/dollar.png
  AssetGenImage get dollar => const AssetGenImage('assets/icons/dollar.png');

  /// File path: assets/icons/right-arrow.png
  AssetGenImage get rightArrow =>
      const AssetGenImage('assets/icons/right-arrow.png');

  /// File path: assets/icons/settings-line.png
  AssetGenImage get settingsLine =>
      const AssetGenImage('assets/icons/settings-line.png');

  /// File path: assets/icons/success_tick.gif
  AssetGenImage get successTick =>
      const AssetGenImage('assets/icons/success_tick.gif');

  /// File path: assets/icons/swap.png
  AssetGenImage get swap => const AssetGenImage('assets/icons/swap.png');

  /// List of all assets
  List<AssetGenImage> get values => [
    btc,
    dollar,
    rightArrow,
    settingsLine,
    successTick,
    swap,
  ];
}

class $AssetsImagesGen {
  const $AssetsImagesGen();

  /// File path: assets/images/arrow_down.png
  AssetGenImage get arrowDown =>
      const AssetGenImage('assets/images/arrow_down.png');

  /// File path: assets/images/arrow_down_white.png
  AssetGenImage get arrowDownWhite =>
      const AssetGenImage('assets/images/arrow_down_white.png');

  /// File path: assets/images/icon_btc.png
  AssetGenImage get iconBtc =>
      const AssetGenImage('assets/images/icon_btc.png');

  /// File path: assets/images/icon_lbtc.png
  AssetGenImage get iconLbtc =>
      const AssetGenImage('assets/images/icon_lbtc.png');

  /// File path: assets/images/swap_icon.png
  AssetGenImage get swapIcon =>
      const AssetGenImage('assets/images/swap_icon.png');

  /// File path: assets/images/swap_icon_white.png
  AssetGenImage get swapIconWhite =>
      const AssetGenImage('assets/images/swap_icon_white.png');

  /// List of all assets
  List<AssetGenImage> get values => [
    arrowDown,
    arrowDownWhite,
    iconBtc,
    iconLbtc,
    swapIcon,
    swapIconWhite,
  ];
}

class $AssetsImages2Gen {
  const $AssetsImages2Gen();

  /// File path: assets/images2/bb-logo-small.png
  AssetGenImage get bbLogoSmall =>
      const AssetGenImage('assets/images2/bb-logo-small.png');

  /// File path: assets/images2/bg-red.png
  AssetGenImage get bgRed => const AssetGenImage('assets/images2/bg-red.png');

  /// List of all assets
  List<AssetGenImage> get values => [bbLogoSmall, bgRed];
}

class Assets {
  const Assets._();

  static const AssetGenImage arrowDown = AssetGenImage('assets/arrow_down.png');
  static const AssetGenImage arrowDownWhite = AssetGenImage(
    'assets/arrow_down_white.png',
  );
  static const AssetGenImage bbLogoRed = AssetGenImage(
    'assets/bb-logo-red.png',
  );
  static const AssetGenImage bbLogoSmall = AssetGenImage(
    'assets/bb-logo-small.png',
  );
  static const AssetGenImage bbLogoWhiteSplash = AssetGenImage(
    'assets/bb-logo-white-splash.png',
  );
  static const AssetGenImage bbLogoWhite = AssetGenImage(
    'assets/bb-logo-white.png',
  );
  static const AssetGenImage bbLogo2 = AssetGenImage('assets/bb-logo2.png');
  static const AssetGenImage bbWhite = AssetGenImage('assets/bb-white.png');
  static const String bip39English = 'assets/bip39_english.txt';
  static const AssetGenImage ccLogo = AssetGenImage('assets/cc-logo.png');
  static const String edit = 'assets/edit.svg';
  static const $AssetsI18nGen i18n = $AssetsI18nGen();
  static const AssetGenImage iconlarge = AssetGenImage('assets/iconlarge.png');
  static const AssetGenImage iconnewRed = AssetGenImage(
    'assets/iconnew-red.png',
  );
  static const AssetGenImage iconnew = AssetGenImage('assets/iconnew.png');
  static const $AssetsIconsGen icons = $AssetsIconsGen();
  static const $AssetsImagesGen images = $AssetsImagesGen();
  static const $AssetsImages2Gen images2 = $AssetsImages2Gen();
  static const String loaderanimation = 'assets/loaderanimation.json';
  static const String newAddress = 'assets/new-address.svg';
  static const AssetGenImage nfcScan = AssetGenImage('assets/nfc_scan.png');
  static const String refresh = 'assets/refresh.svg';
  static const String requestPayment = 'assets/request-payment.svg';
  static const AssetGenImage splash = AssetGenImage('assets/splash.png');
  static const AssetGenImage textlogo = AssetGenImage('assets/textlogo.png');
  static const AssetGenImage txStatusComplete = AssetGenImage(
    'assets/tx_status_complete.png',
  );
  static const AssetGenImage txStatusFailed = AssetGenImage(
    'assets/tx_status_failed.png',
  );
  static const AssetGenImage txStatusPending = AssetGenImage(
    'assets/tx_status_pending.png',
  );

  /// List of all assets
  static List<dynamic> get values => [
    arrowDown,
    arrowDownWhite,
    bbLogoRed,
    bbLogoSmall,
    bbLogoWhiteSplash,
    bbLogoWhite,
    bbLogo2,
    bbWhite,
    bip39English,
    ccLogo,
    edit,
    iconlarge,
    iconnewRed,
    iconnew,
    loaderanimation,
    newAddress,
    nfcScan,
    refresh,
    requestPayment,
    splash,
    textlogo,
    txStatusComplete,
    txStatusFailed,
    txStatusPending,
  ];
}

class AssetGenImage {
  const AssetGenImage(this._assetName, {this.size, this.flavors = const {}});

  final String _assetName;

  final Size? size;
  final Set<String> flavors;

  Image image({
    Key? key,
    AssetBundle? bundle,
    ImageFrameBuilder? frameBuilder,
    ImageErrorWidgetBuilder? errorBuilder,
    String? semanticLabel,
    bool excludeFromSemantics = false,
    double? scale,
    double? width,
    double? height,
    Color? color,
    Animation<double>? opacity,
    BlendMode? colorBlendMode,
    BoxFit? fit,
    AlignmentGeometry alignment = Alignment.center,
    ImageRepeat repeat = ImageRepeat.noRepeat,
    Rect? centerSlice,
    bool matchTextDirection = false,
    bool gaplessPlayback = true,
    bool isAntiAlias = false,
    String? package,
    FilterQuality filterQuality = FilterQuality.medium,
    int? cacheWidth,
    int? cacheHeight,
  }) {
    return Image.asset(
      _assetName,
      key: key,
      bundle: bundle,
      frameBuilder: frameBuilder,
      errorBuilder: errorBuilder,
      semanticLabel: semanticLabel,
      excludeFromSemantics: excludeFromSemantics,
      scale: scale,
      width: width,
      height: height,
      color: color,
      opacity: opacity,
      colorBlendMode: colorBlendMode,
      fit: fit,
      alignment: alignment,
      repeat: repeat,
      centerSlice: centerSlice,
      matchTextDirection: matchTextDirection,
      gaplessPlayback: gaplessPlayback,
      isAntiAlias: isAntiAlias,
      package: package,
      filterQuality: filterQuality,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
    );
  }

  ImageProvider provider({AssetBundle? bundle, String? package}) {
    return AssetImage(_assetName, bundle: bundle, package: package);
  }

  String get path => _assetName;

  String get keyName => _assetName;
}
