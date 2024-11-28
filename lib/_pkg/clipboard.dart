import 'package:bb_mobile/_pkg/logger.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/services.dart';

class BBClipboard {
  static Future<String?> paste() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      return data?.text;
    } catch (e) {
      return null;
    }
  }

  static Future<void> copy(String data) async {
    try {
      await Clipboard.setData(ClipboardData(text: data));
      HapticFeedback.mediumImpact();
    } catch (_) {}
  }
}

class Clippboard {
  Future<String?> paste() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      return data?.text;
    } catch (e) {
      if (locator.isRegistered<Logger>()) locator<Logger>().log(e.toString());
      return null;
    }
  }

  Future<void> copy(String data) async {
    try {
      await Clipboard.setData(ClipboardData(text: data));
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (locator.isRegistered<Logger>()) locator<Logger>().log(e.toString());
    }
  }
}
