import 'package:material_ui/material_ui.dart';

class Device {
  static late Size screen;

  static void init(BuildContext context) {
    screen = MediaQuery.of(context).size;
  }
}
