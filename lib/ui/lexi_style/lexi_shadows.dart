import 'package:flutter/material.dart';

abstract class LexiStyleShadows {
  static const card = [
    BoxShadow(color: Color(0x12000000), blurRadius: 12, offset: Offset(0, 4)),
  ];

  static const bar = [
    BoxShadow(color: Color(0x1F000000), blurRadius: 16, offset: Offset(0, 6)),
  ];
}
