import 'package:flutter/material.dart';

class CartesianCanvasTheme {
  final Color background;
  final Color axisColor;
  final double axisWidth;
  final Color gridColor;
  final double gridWidth;
  final Color labelColor;
  final double labelFontSize;
  final Color originDotColor;
  final Color tooltipBackground;
  final Color tooltipTextColor;

  const CartesianCanvasTheme({
    this.background = const Color(0xFFF8F9FA),
    this.axisColor = const Color(0xFF2B2D42),
    this.axisWidth = 1.2,
    this.gridColor = const Color(0xFFE5E7EB),
    this.gridWidth = 1.0,
    this.labelColor = const Color(0xFF6B7280),
    this.labelFontSize = 11,
    this.originDotColor = const Color(0xFF3B82F6),
    this.tooltipBackground = const Color(0xE61F2937),
    this.tooltipTextColor = const Color(0xFFF9FAFB),
  });

  static const light = CartesianCanvasTheme();

  static const dark = CartesianCanvasTheme(
    background: Color(0xFF111827),
    axisColor: Color(0xFFD1D5DB),
    axisWidth: 1.0,
    gridColor: Color(0xFF1F2937),
    gridWidth: 1.0,
    labelColor: Color(0xFF9CA3AF),
    labelFontSize: 11,
    originDotColor: Color(0xFF60A5FA),
    tooltipBackground: Color(0xE6F3F4F6),
    tooltipTextColor: Color(0xFF111827),
  );

  CartesianCanvasTheme copyWith({
    Color? background,
    Color? axisColor,
    double? axisWidth,
    Color? gridColor,
    double? gridWidth,
    Color? labelColor,
    double? labelFontSize,
    Color? originDotColor,
    Color? tooltipBackground,
    Color? tooltipTextColor,
  }) {
    return CartesianCanvasTheme(
      background: background ?? this.background,
      axisColor: axisColor ?? this.axisColor,
      axisWidth: axisWidth ?? this.axisWidth,
      gridColor: gridColor ?? this.gridColor,
      gridWidth: gridWidth ?? this.gridWidth,
      labelColor: labelColor ?? this.labelColor,
      labelFontSize: labelFontSize ?? this.labelFontSize,
      originDotColor: originDotColor ?? this.originDotColor,
      tooltipBackground: tooltipBackground ?? this.tooltipBackground,
      tooltipTextColor: tooltipTextColor ?? this.tooltipTextColor,
    );
  }
}
