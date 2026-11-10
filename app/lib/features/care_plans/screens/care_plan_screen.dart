import 'dart:ui';
import 'package:ava_web/features/care_plans/models/care_plan.dart';
import 'package:ava_web/common/widgets/app_background.dart';
import 'package:flutter/material.dart';
import 'package:ava_web/common/widgets/flow.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ava_web/features/account/user_data_controller.dart';
import 'package:ava_web/common/widgets/app_card.dart';
import 'package:ava_web/features/care_plans/care_plan_notes.dart';
import 'package:ava_web/features/care_plans/widgets/note_editor_sheet.dart';
import 'package:ava_web/core/design_system.dart';
import 'package:ava_web/core/responsive.dart';
import 'package:ava_web/common/widgets/responsive_page.dart';
import 'package:ava_web/core/app_theme.dart';
import 'package:ava_web/core/kind_style.dart';
import 'package:ava_web/features/care_plans/widgets/favorite_button.dart';

class CarePlanScreen extends ConsumerStatefulWidget {
  const CarePlanScreen({super.key, required this.carePlan});

  final CarePlan carePlan;

  @override
  ConsumerState<CarePlanScreen> createState() => _CarePlanScreenState();
}

class _CarePlanScreenState extends ConsumerState<CarePlanScreen> {
  bool _compactMode = false;

  static const _glassBorderRadius = AppRadius.lg;

  void _toggleViewMode() {
    setState(() {
      _compactMode = !_compactMode;
    });
  }

  Color _kindColor(Kind kind) => context.kindTone(kind);

  String? get _note => ref.read(carePlanNotesProvider)[widget.carePlan.id];

  Future<void> _copy(String text, String message) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _copyWholePlan() => _copy(
    carePlanAsText(
      widget.carePlan,
      kindLabel: kindLabel(widget.carePlan.kind),
      note: _note,
    ),
    'برنامه مراقبتی کپی شد؛ می‌توانید آن را در هر جایی جای‌گذاری کنید',
  );

  Future<void> _editNote() async {
    final text = await showNoteEditorSheet(
      context,
      planTitle: widget.carePlan.title,
      initialText: _note ?? '',
    );
    if (text == null) return;
    await ref.read(userDataProvider.notifier).setNote(widget.carePlan.id, text);
  }

  @override
  Widget build(BuildContext context) {
    final entries = [
      for (final s in widget.carePlan.sections) MapEntry(s.title, s.items),
    ];
    final accentColor = _kindColor(widget.carePlan.kind);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildGlassAppBar(accentColor),
      body: AppBackground(
        child: SafeArea(
          child: ResponsivePage(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: _compactMode
                  ? _buildCompactView(entries, accentColor)
                  : _buildFullView(entries, accentColor),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildGlassAppBar(Color accentColor) {
    return FlowAppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: context.onBg,
      centerTitle: true,
      title: Text(
        widget.carePlan.title,
        textAlign: TextAlign.center,
        style: context.text.titleLarge,
      ),
      actions: [
        IconButton(
          tooltip: 'کپی کل برنامه',
          onPressed: _copyWholePlan,
          icon: Icon(Icons.copy_all_rounded, color: context.onBg),
        ),
        IconButton(
          tooltip: 'یادداشت من',
          onPressed: _editNote,
          icon: Icon(Icons.edit_note_rounded, color: context.onBg),
        ),
        FavoriteButton(
          carePlan: widget.carePlan,
          color: accentColor,
          size: context.sp(24),
        ),
        IconButton(
          tooltip: "حالت نمایش",
          onPressed: _toggleViewMode,
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Icon(
              _compactMode
                  ? Icons.view_agenda_rounded
                  : Icons.view_module_rounded,
              key: ValueKey(_compactMode),
              color: context.onBg,
              size: context.sp(26),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFullView(
    List<MapEntry<String, List<String>>> entries,
    Color accentColor,
  ) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          for (int i = 0; i < entries.length; i++) ...[
            _buildSectionCard(
              title: entries[i].key,
              items: entries[i].value,
              accentColor: accentColor,
              onCopy: () => _copy(
                sectionAsText(widget.carePlan, widget.carePlan.sections[i]),
                '«${entries[i].key}» کپی شد',
              ),
            ),
            SizedBox(height: context.hp(16)),
          ],
          _NoteCard(
            note: ref.watch(carePlanNotesProvider)[widget.carePlan.id],
            onEdit: _editNote,
          ),
          SizedBox(height: context.hp(20)),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<String> items,
    required Color accentColor,
    required VoidCallback onCopy,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_glassBorderRadius),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(context.wp(18)),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              context.onBg.withValues(alpha: 0.16),
              context.onBg.withValues(alpha: 0.06),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(_glassBorderRadius),
          border: Border.all(color: context.onBg.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.20),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accentColor.withValues(alpha: 0.85),
                    accentColor.withValues(alpha: 0.55),
                  ],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(AppRadius.md),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 40),
                  Expanded(
                    child: Text(
                      title.trim(),
                      textAlign: TextAlign.center,
                      style: context.text.titleMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'کپی این بخش',
                    onPressed: onCopy,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.copy_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: context.hp(14)),
            for (final item in items) ...[
              _buildItemText(item),
              SizedBox(height: context.hp(10)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildItemText(String text) {
    return Container(
      padding: EdgeInsets.all(context.wp(14)),
      decoration: BoxDecoration(
        color: context.onBg.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: context.onBg.withValues(alpha: 0.16)),
      ),
      child: Text(
        text,
        style: context.text.bodyMedium.copyWith(
          color: context.onBg.withValues(alpha: 0.92),
          height: 1.75,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildCompactView(
    List<MapEntry<String, List<String>>> entries,
    Color accentColor,
  ) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: entries.length,
      padding: EdgeInsets.only(top: context.hp(6), bottom: context.hp(20)),
      itemBuilder: (context, index) {
        final entry = entries[index];
        final count = entry.value.length;

        return Padding(
          padding: EdgeInsets.only(bottom: context.hp(14)),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              onTap: () =>
                  _showSectionPopup(entry.key, entry.value, accentColor),
              splashColor: accentColor.withValues(alpha: 0.22),
              highlightColor: accentColor.withValues(alpha: 0.1),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: context.wp(16),
                  vertical: context.hp(16),
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accentColor.withValues(alpha: 0.26),
                      accentColor.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.45),
                    width: 1.3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.2),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: context.wp(42),
                      height: context.wp(42),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color.lerp(accentColor, Colors.white, 0.15)!,
                            accentColor,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withValues(alpha: 0.45),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.assignment_rounded,
                        color: Colors.white,
                        size: context.sp(20),
                      ),
                    ),

                    SizedBox(width: context.wp(14)),

                    Expanded(
                      child: Text(
                        entry.key,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodyLarge.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),

                    SizedBox(width: context.wp(8)),

                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.wp(10),
                        vertical: context.hp(5),
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        '$count مورد',
                        style: context.text.labelMedium.copyWith(
                          color: context.legible(accentColor),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),

                    SizedBox(width: context.wp(6)),

                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: accentColor,
                      size: context.sp(15),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showSectionPopup(String title, List<String> items, Color accentColor) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
            horizontal: context.wp(24),
            vertical: context.hp(40),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: 440,
                  maxHeight: MediaQuery.sizeOf(context).height * 0.72,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  gradient: LinearGradient(
                    colors: [
                      context.appColors.dialogSurface.withValues(alpha: 0.97),
                      context.appColors.dialogSurface.withValues(alpha: 0.9),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.4),
                    width: 1.3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.28),
                      blurRadius: 30,
                      offset: const Offset(0, 14),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.fromLTRB(
                        context.wp(20),
                        context.hp(18),
                        context.wp(12),
                        context.hp(16),
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            accentColor.withValues(alpha: 0.95),
                            accentColor.withValues(alpha: 0.7),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(AppRadius.xl),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: context.wp(38),
                            height: context.wp(38),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.22),
                            ),
                            child: Icon(
                              Icons.assignment_rounded,
                              color: Colors.white,
                              size: context.sp(19),
                            ),
                          ),
                          SizedBox(width: context.wp(12)),
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.titleMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'بستن',
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: context.sp(22),
                            ),
                            splashRadius: context.wp(20),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: EdgeInsets.all(context.wp(18)),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: EdgeInsets.only(bottom: context.hp(12)),
                            child: _buildItemText(items[index]),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note, required this.onEdit});
  final String? note;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final hasNote = note != null && note!.isNotEmpty;
    final accent = context.appColors.warning;
    return AppCard(
      accent: accent,
      onTap: onEdit,
      semanticLabel: hasNote ? 'ویرایش یادداشت' : 'افزودن یادداشت',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sticky_note_2_rounded, color: accent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'یادداشت من',
                  style: context.text.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Icon(
                hasNote ? Icons.edit_rounded : Icons.add_rounded,
                color: context.onBgMuted,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            hasNote
                ? note!
                : 'نکته‌ای برای خودتان بنویسید؛ فقط روی همین دستگاه ذخیره می‌شود.',
            style: hasNote
                ? context.text.bodyMedium
                : context.text.bodySmall.copyWith(color: context.onBgMuted),
          ),
        ],
      ),
    );
  }
}
