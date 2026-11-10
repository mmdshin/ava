import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ava_web/admin/data/providers.dart';
import 'package:ava_web/admin/widgets/common.dart';
import 'package:ava_web/core/app_theme.dart';
import 'package:ava_web/core/design_system.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _reason = TextEditingController(text: 'کارآزمایی بالینی');

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _set(bool frozen) async {
    final ok = await confirm(
      context,
      title: frozen ? 'قفل کردن انتشار' : 'باز کردن انتشار',
      message: frozen
          ? 'تا زمانی که قفل باز نشود، هیچ نسخه جدیدی منتشر نمی‌شود. ادامه می‌دهید؟'
          : 'بازبین‌ها دوباره می‌توانند نسخه جدید منتشر کنند. ادامه می‌دهید؟',
      action: frozen ? 'قفل کن' : 'باز کن',
      destructive: frozen,
    );
    if (!ok || !mounted) return;
    await runAction(context, () async {
      await ref
          .read(adminApiProvider)
          .setFreeze(frozen, frozen ? _reason.text.trim() : '');
      ref.invalidate(freezeProvider);
    }, success: frozen ? 'انتشار قفل شد' : 'انتشار باز شد');
  }

  @override
  Widget build(BuildContext context) {
    final freeze = ref.watch(freezeProvider);
    final colors = context.appColors;
    return AdminPage(
      title: 'تنظیمات',
      maxWidth: 760,
      child: FormSection(
        title: 'قفل انتشار',
        icon: Icons.lock_outline_rounded,
        subtitle: 'برای ثابت ماندن محتوا در دوره‌هایی مثل کارآزمایی بالینی.',
        child: AsyncBody(
          value: freeze,
          onRetry: () => ref.invalidate(freezeProvider),
          builder: (f) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: (f.frozen ? colors.warning : colors.success)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm - 4),
                ),
                child: Row(
                  children: [
                    Icon(
                      f.frozen ? Icons.lock_rounded : Icons.lock_open_rounded,
                      color: context.legible(
                        f.frozen ? colors.warning : colors.success,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            f.frozen ? 'انتشار قفل است' : 'انتشار باز است',
                            style: context.text.titleSmall,
                          ),
                          Text(
                            f.frozen
                                ? 'دلیل: ${f.reason}${f.updatedBy.isEmpty ? '' : ' · توسط ${f.updatedBy}'}'
                                : 'بازبین‌ها می‌توانند نسخه جدید منتشر کنند.',
                            style: context.text.bodySmall.copyWith(
                              color: context.onBgMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'وقتی انتشار قفل است، محتوایی که کاربران می‌بینند ثابت می‌ماند. ویرایش پیش‌نویس ادامه دارد و پس از باز شدن قفل می‌توان آن را منتشر کرد.',
                style: context.text.bodySmall.copyWith(
                  color: context.onBgMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (f.frozen)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: OutlinedButton.icon(
                    onPressed: () => _set(false),
                    icon: const Icon(Icons.lock_open_rounded),
                    label: const Text('باز کردن انتشار'),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _reason,
                        decoration: const InputDecoration(
                          labelText: 'دلیل قفل',
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    FilledButton.icon(
                      onPressed: () => _set(true),
                      icon: const Icon(Icons.lock_rounded),
                      label: const Text('قفل کردن انتشار'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
