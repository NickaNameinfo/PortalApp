import 'package:flutter/material.dart';

/// Brand palette
const primaryColor = Color(0xFF4C86F9); // Blue
const successColor = Color(0xFF49A84C); // Green
const accentColor = Color(0xFFF6BC00); // Yellow

const Color litePrimary = Color(0x804C86F9);
var greyLite = Colors.grey.shade400;
var bWhite = Colors.white70.withValues(alpha: 0.5);

/// Brand gradients
const LinearGradient brandHeaderGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFF4C86F9), // primary
    Color(0xFF49A84C), // success
  ],
);

const LinearGradient brandFooterGradient = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [
    Color(0xFF4C86F9), // primary
    Color(0xFFF6BC00), // accent
  ],
);

const LinearGradient brandBackgroundGradient = LinearGradient(
  begin: Alignment(-0.25, -1),
  end: Alignment(0.25, 1),
  colors: [
    Color(0x1AF6BC00), // accent @ ~10%
    Color(0x1A49A84C), // success @ ~10%
    Color(0x264C86F9), // primary @ ~15%
  ],
  stops: [0.0, 0.55, 1.0],
);


var titleStyle1 = const TextStyle(
  color: primaryColor,
  fontWeight: FontWeight.bold,
  fontSize: 28,
);

var titleStyle2 = const TextStyle(
  color: Colors.white,
  fontWeight: FontWeight.bold,
  fontSize: 28,
);

var contentStyle1 = const TextStyle(
  color: primaryColor,
  fontWeight: FontWeight.w400,
  fontSize: 18,
);

var contentStyle2 = const TextStyle(
  color: Colors.white,
  fontWeight: FontWeight.w400,
  fontSize: 18,
);