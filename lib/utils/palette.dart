import 'package:flutter/material.dart';

// Deterministic color per index (golden angle so consecutive colors stay
// well distinguished even with many items: clusters, devices, etc.).
Color colorForIndex(int index) {
  final hue = (index * 137.508) % 360;
  return HSVColor.fromAHSV(1, hue, 0.65, 0.9).toColor();
}
