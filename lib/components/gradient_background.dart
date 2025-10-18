import 'package:flutter/material.dart';

const BoxDecoration gradientBackgroundDecoration = BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment(-0.19, -0.99),
    end: Alignment(0.19, 0.99),
    colors: [
      Color(0xFFE3DEFF),
      Color(0x637B6CD9),
      Color(0x403817FE),
    ],
    stops: [0.0, 0.5211, 1.0345],
  ),
);