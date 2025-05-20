import 'package:no_screenshot/no_screenshot.dart';

mixin PrivacyScreen {
  Future<void> enableScreenPrivacy() async =>
      await NoScreenshot.instance.screenshotOff();

  Future<void> disableScreenPrivacy() async =>
      await NoScreenshot.instance.screenshotOn();
}
