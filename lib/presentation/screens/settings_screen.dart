import 'package:flutter/material.dart';

import '../../core/theme/dimens.dart';
import '../../core/utils/arabic_text.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/section_header.dart';
import '../../domain/models/library.dart';
import '../../domain/models/progress.dart';
import '../state/app_state.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _teacherCtrl;
  late TextEditingController _schoolCtrl;
  late TextEditingController _directorateCtrl;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final profile = AppScope.of(context).teacherProfile;
      _teacherCtrl = TextEditingController(text: profile.teacherName);
      _schoolCtrl = TextEditingController(text: profile.schoolName);
      _directorateCtrl = TextEditingController(text: profile.directorate);
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _teacherCtrl.dispose();
    _schoolCtrl.dispose();
    _directorateCtrl.dispose();
    super.dispose();
  }

  void _saveProfile(AppState state) {
    state.updateTeacherProfile(
      TeacherProfile(
        teacherName: _teacherCtrl.text.trim(),
        schoolName: _schoolCtrl.text.trim(),
        directorate: _directorateCtrl.text.trim().isEmpty
            ? 'المديرية العامة للتربية'
            : _directorateCtrl.text.trim(),
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ بيانات المدرس والمدرسة.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات وبيانات المدرس')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: <Widget>[
          AppPage(
            maxWidth: AppLayout.readingMaxWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: AppSpacing.md),
                SectionHeader(
                  title: 'الجزء الدراسي الحالي',
                  accent: scheme.primary,
                ),
                SegmentedButton<CurriculumPart>(
                  segments: <ButtonSegment<CurriculumPart>>[
                    for (final part in CurriculumPart.values)
                      ButtonSegment<CurriculumPart>(
                        value: part,
                        label: Text(part.title),
                      ),
                  ],
                  selected: <CurriculumPart>{state.activePart},
                  onSelectionChanged: (Set<CurriculumPart> next) {
                    if (next.isNotEmpty) {
                      state.selectPart(next.first);
                    }
                  },
                ),

                const SizedBox(height: AppSpacing.xl),
                SectionHeader(
                  title: 'بيانات المدرس والمدرسة (لأوراق الامتحان Word)',
                  subtitle:
                      'تظهر تلقائياً في ترويسة وتوقيع أوراق الأسئلة المصدرة بصيغة .docx',
                  accent: scheme.secondary,
                ),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      TextField(
                        key: const ValueKey<String>('settings-teacher-name'),
                        controller: _teacherCtrl,
                        decoration: const InputDecoration(
                          labelText: 'اسم مدرس المادة',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        key: const ValueKey<String>('settings-school-name'),
                        controller: _schoolCtrl,
                        decoration: const InputDecoration(
                          labelText: 'اسم المدرسة',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        key: const ValueKey<String>('settings-directorate'),
                        controller: _directorateCtrl,
                        decoration: const InputDecoration(
                          labelText: 'مديرية التربية',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: FilledButton.icon(
                          key: const ValueKey<String>('save-profile-button'),
                          onPressed: () => _saveProfile(state),
                          icon: const Icon(Icons.save_outlined, size: 18),
                          label: const Text('حفظ البيانات'),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),
                SectionHeader(
                  title: 'المظهر وحجم الخط',
                  accent: scheme.tertiary,
                ),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      SegmentedButton<ThemeMode>(
                        segments: const <ButtonSegment<ThemeMode>>[
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.light,
                            icon: Icon(Icons.wb_sunny_outlined, size: 18),
                            label: Text('نهاري'),
                          ),
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.dark,
                            icon: Icon(Icons.dark_mode_outlined, size: 18),
                            label: Text('ليلي'),
                          ),
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.system,
                            icon: Icon(Icons.brightness_auto_outlined, size: 18),
                            label: Text('تلقائي'),
                          ),
                        ],
                        selected: <ThemeMode>{state.themeMode},
                        onSelectionChanged: (Set<ThemeMode> next) {
                          if (next.isNotEmpty) {
                            state.setThemeMode(next.first);
                          }
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: <Widget>[
                          const Text('مقياس الخط:'),
                          Expanded(
                            child: Slider(
                              value: state.textScale,
                              min: 0.85,
                              max: 1.40,
                              divisions: 11,
                              onChanged: state.setTextScale,
                            ),
                          ),
                          Text(
                            '${toArabicDigits((state.textScale * 100).round())}٪',
                            style: theme.textTheme.labelLarge,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),
                SectionHeader(
                  title: 'سجل القراءة ومصدر المحتوى',
                  accent: scheme.primary,
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'تطبيق «بَيَان» — يعمل دون اتصال بالإنترنت ١٠٠٪ على نظامي Android و Windows.',
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'المحتوى العلمي والنصوص والتمارين ومعجم الطالب مستخرجة ومطابقة لكتابي اللغة العربية للصف الأول المتوسط (الجزء الأول ١٠ وحدات، والجزء الثاني ٩ وحدات) المعتمدين من المديرية العامة للمناهج في وزارة التربية العراقية.',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        OutlinedButton.icon(
                          onPressed: () async {
                            await state.resetStudyProgress();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('تمت إعادة ضبط سجل القراءة والمحفوظات.'),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.restart_alt, size: 18),
                          label: const Text('إعادة ضبط المحفوظات وسجل القراءة'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
