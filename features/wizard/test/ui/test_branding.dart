import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:wizard/wizard.dart';

final testBranding = WizardBranding(
  headerLogo: _pixel,
  welcomeLogo: _pixel,
  welcomePattern: _pixel,
);

final _pixel = MemoryImage(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGNgAAIAAAUAAXpeqz8AAAAASUVORK5CYII=',
  ),
);
