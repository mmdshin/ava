import 'package:flutter/material.dart';
import 'package:ava_web/common/widgets/flow.dart';
import 'package:ava_web/core/design_system.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:ava_web/common/widgets/app_background.dart';
import 'package:ava_web/core/app_theme.dart';
import 'package:ava_web/core/kind_style.dart';
import 'package:ava_web/core/persian_text.dart';
import 'package:ava_web/core/responsive.dart';
import 'package:ava_web/features/care_plans/models/care_plan.dart';

class CarePlanSearchDelegate extends SearchDelegate<CarePlan?> {
  CarePlanSearchDelegate(this.carePlans)
    : super(
        searchFieldLabel: 'جستجو در برنامه‌های مراقبتی...',
        textInputAction: TextInputAction.search,
      );

  final List<CarePlan> carePlans;

  @override
  ThemeData appBarTheme(BuildContext context) {
    final base = Theme.of(context);
    final onBg = context.onBg;
    final glass = context.appColors.glass;

    OutlineInputBorder border(double alpha, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(
            color: glass.withValues(alpha: alpha),
            width: width,
          ),
        );

    return base.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: onBg),
      ),
      textTheme: base.textTheme.copyWith(
        titleLarge: context.text.bodyLarge.copyWith(
          color: onBg,
          fontWeight: FontWeight.w600,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: glass.withValues(alpha: 0.08),
        hintStyle: context.text.bodyMedium.copyWith(
          color: context.onBgMuted,
          fontWeight: FontWeight.w500,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 12,
        ),
        border: border(0.22),
        enabledBorder: border(0.22),
        focusedBorder: border(0.5, 1.5),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: onBg,
        selectionColor: onBg.withValues(alpha: 0.25),
        selectionHandleColor: onBg,
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        tooltip: 'بازگشت',
        icon: const BackArrow(),
        color: context.onBg,
        onPressed: () => close(context, null),
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    if (query.isEmpty) return const SizedBox.shrink();
    return IconButton(
      tooltip: 'پاک کردن',
      icon: Icon(Icons.close_rounded, color: context.onBg),
      onPressed: () => query = '',
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) =>
      _buildPage(context, _filterCarePlans(query));

  @override
  Widget buildResults(BuildContext context) =>
      _buildPage(context, _filterCarePlans(query));

  Widget _buildPage(BuildContext context, List<CarePlan> list) {
    return AppBackground(
      child: list.isEmpty
          ? _buildEmptyState(context)
          : _buildList(context, list),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: context.wp(72),
            color: context.onBgMuted,
          ),
          SizedBox(height: context.hp(12)),
          Text(
            "هیچ موردی یافت نشد",
            style: context.text.titleLarge.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: context.hp(6)),
          Text(
            "کلمه دیگری را امتحان کنید",
            style: context.text.bodySmall.copyWith(color: context.onBgMuted),
          ),
        ],
      ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.15),
    );
  }

  Widget _buildList(BuildContext context, List<CarePlan> results) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      itemCount: results.length,
      itemBuilder: (ctx, index) {
        final carePlan = results[index];
        final tile = _SearchResultTile(
          carePlan: carePlan,
          query: query,
          onOpen: () => close(context, carePlan),
        );
        if (index > 12) return tile;
        return tile
            .animate()
            .fadeIn(duration: 300.ms, delay: (index * 20).ms)
            .slideX(begin: 0.1);
      },
    );
  }

  List<CarePlan> _filterCarePlans(String q) {
    if (normalizeForSearch(q).isEmpty) return carePlans;

    final matches = <({CarePlan plan, int rank, int order})>[];
    for (var i = 0; i < carePlans.length; i++) {
      final plan = carePlans[i];
      final int rank;
      if (searchMatches(plan.title, q)) {
        rank = 0; // title hits first
      } else if (searchMatches(kindLabel(plan.kind), q) ||
          plan.tags.any((t) => searchMatches(t.replaceAll('_', ' '), q))) {
        rank = 1;
      } else if (plan.sections.any(
        (s) => s.items.any((text) => searchMatches(text, q)),
      )) {
        rank = 2;
      } else {
        continue;
      }
      matches.add((plan: plan, rank: rank, order: i));
    }
    matches.sort((a, b) {
      final byRank = a.rank.compareTo(b.rank);
      return byRank != 0 ? byRank : a.order.compareTo(b.order);
    });
    return [for (final m in matches) m.plan];
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({
    required this.carePlan,
    required this.query,
    required this.onOpen,
  });

  final CarePlan carePlan;
  final String query;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final color = context.kindTone(carePlan.kind);
    final glass = context.appColors.glass;

    return Container(
      margin: EdgeInsets.symmetric(vertical: context.hp(6)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        gradient: LinearGradient(
          colors: [
            glass.withValues(alpha: 0.14),
            glass.withValues(alpha: 0.05),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        border: Border.all(color: glass.withValues(alpha: 0.18)),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: context.wp(44),
          height: context.wp(44),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: color.withValues(alpha: 0.6)),
          ),
          child: Icon(kindIcon(carePlan.kind), color: color),
        ),
        title: _highlightTitle(context, carePlan.title),
        subtitle: Text(
          kindLabel(carePlan.kind),
          style: context.text.labelLarge.copyWith(color: context.onBgMuted),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          size: context.wp(14),
          color: context.onBgMuted,
        ),
        onTap: onOpen,
      ),
    );
  }

  Widget _highlightTitle(BuildContext context, String text) {
    final base = context.text.bodyLarge.copyWith(fontWeight: FontWeight.w700);
    final range = findMatchRange(text, query);
    if (range == null) return Text(text, style: base);

    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: text.substring(0, range.start)),
          TextSpan(
            text: text.substring(range.start, range.end),
            style: TextStyle(
              color: context.appColors.warning,
              fontWeight: FontWeight.w900,
            ),
          ),
          TextSpan(text: text.substring(range.end)),
        ],
      ),
    );
  }
}
