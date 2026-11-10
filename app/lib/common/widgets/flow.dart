import 'package:flutter/material.dart';

/// AvA's navigation runs left-to-right, like English apps, while all
/// text stays right-to-left (Persian).

/// An [AppBar] laid out left-to-right (back/close on the left, actions
/// on the right) whose title and actions still read right-to-left.
class FlowAppBar extends StatelessWidget implements PreferredSizeWidget {
  const FlowAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.automaticallyImplyLeading = true,
    this.centerTitle,
    this.foregroundColor,
    this.elevation,
    this.scrolledUnderElevation,
    this.iconTheme,
  });

  final Widget? title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool automaticallyImplyLeading;
  final bool? centerTitle;
  final Color? foregroundColor;
  final double? elevation;
  final double? scrolledUnderElevation;
  final IconThemeData? iconTheme;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  static Widget _rtl(Widget child) =>
      Directionality(textDirection: TextDirection.rtl, child: child);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: AppBar(
        leading: leading,
        automaticallyImplyLeading: automaticallyImplyLeading,
        title: title == null ? null : _rtl(title!),
        actions: actions == null ? null : [for (final a in actions!) _rtl(a)],
        centerTitle: centerTitle,
        foregroundColor: foregroundColor,
        elevation: elevation,
        scrolledUnderElevation: scrolledUnderElevation,
        iconTheme: iconTheme,
      ),
    );
  }
}

class NextArrow extends StatelessWidget {
  const NextArrow({super.key, this.size});
  final double? size;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: Icon(Icons.arrow_forward_rounded, size: size),
  );
}

class BackArrow extends StatelessWidget {
  const BackArrow({super.key, this.size});
  final double? size;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: Icon(Icons.arrow_back_rounded, size: size),
  );
}

class NextLabel extends StatelessWidget {
  const NextLabel(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(label, textDirection: TextDirection.rtl)),
        const SizedBox(width: 8),
        const NextArrow(size: 20),
      ],
    ),
  );
}

class BackLabel extends StatelessWidget {
  const BackLabel(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const BackArrow(size: 20),
        const SizedBox(width: 8),
        Flexible(child: Text(label, textDirection: TextDirection.rtl)),
      ],
    ),
  );
}
