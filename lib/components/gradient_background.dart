import 'package:flutter/material.dart';
import 'package:nickname_portal/constants/colors.dart';

const BoxDecoration gradientBackgroundDecoration = BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment(-0.19, -0.99),
    end: Alignment(0.19, 0.99),
    colors: [
      Color(0x1AF6BC00), // brand accent (soft)
      Color(0x1A49A84C), // brand success (soft)
      Color(0x264C86F9), // brand primary (soft)
    ],
    stops: [0.0, 0.5211, 1.0345],
  ),
);