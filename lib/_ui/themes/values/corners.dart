import 'package:flutter/material.dart';

class CornerRadius {
  static const double small = 4.0;
  static const double medium = 8.0;
  static const double large = 16.0;
  static const double xLarge = 24.0;
  static const double xxLarge = 32.0;
  static const double xxxLarge = 48.0;
  static const double circle = 100.0;

  static const BorderRadiusGeometry defaultBorderRadius = BorderRadius.all(
    Radius.circular(medium),
  );

  static const Radius defaultRadius = Radius.circular(medium);
}
