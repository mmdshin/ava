import 'package:flutter/material.dart';
import 'package:ava_web/core/responsive.dart';

class ResponsivePage extends StatelessWidget {
  final Widget child;

  const ResponsivePage({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: Responsive.maxContentWidth(context),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.horizontalPadding(context),
          ),
          child: child,
        ),
      ),
    );
  }
}
