import 'package:flutter/material.dart';

class Responsive {
  Responsive._();

  static const double _baseWidth = 390;
  static const double _baseHeight = 844;

  static double width(BuildContext context) => MediaQuery.sizeOf(context).width;

  static double height(BuildContext context) =>
      MediaQuery.sizeOf(context).height;

  static bool isMobile(BuildContext context) => width(context) < 600;

  static bool isTablet(BuildContext context) =>
      width(context) >= 600 && width(context) < 1000;

  static bool isDesktop(BuildContext context) => width(context) >= 1000;

  static double maxContentWidth(BuildContext context) {
    if (isDesktop(context)) return 900;
    if (isTablet(context)) return 700;
    return double.infinity;
  }

  static double horizontalPadding(BuildContext context) {
    final w = width(context);

    if (w > 1200) return 48;
    if (w > 700) return 32;
    return 16;
  }

  static double _widthScale(
    BuildContext context, {
    double min = 0.85,
    double max = 1.6,
  }) {
    return (width(context) / _baseWidth).clamp(min, max);
  }

  static double _heightScale(
    BuildContext context, {
    double min = 0.85,
    double max = 1.4,
  }) {
    return (height(context) / _baseHeight).clamp(min, max);
  }

  static double sp(BuildContext context, double size) {
    final scale = _widthScale(context, min: 0.85, max: 1.25);
    return size * scale;
  }

  static double wp(BuildContext context, double size) {
    return size * _widthScale(context);
  }

  static double hp(BuildContext context, double size) {
    return size * _heightScale(context);
  }

  static double wPercent(
    BuildContext context,
    double percent, {
    double min = 0,
    double max = double.infinity,
  }) {
    return (width(context) * percent).clamp(min, max);
  }
}

extension ResponsiveContext on BuildContext {
  double sp(double size) => Responsive.sp(this, size);
  double wp(double size) => Responsive.wp(this, size);
  double hp(double size) => Responsive.hp(this, size);
}
