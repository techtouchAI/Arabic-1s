import 'package:flutter/material.dart';

import '../../core/theme/dimens.dart';
import '../../core/widgets/app_page.dart';
import '../../domain/models/library.dart';
import '../state/app_state.dart';
import '../widgets/bayan_emblem.dart';

/// First-launch onboarding screen where the teacher or student selects the
/// active book part (`الجزء الأول` or `الجزء الثاني`) and optionally enters
/// teacher/school details used automatically in Word `.docx` exam headers.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  CurriculumPart _selectedPart = CurriculumPart.part1;
  final TextEditingController _teacherCtrl = TextEditingController();
  final TextEditingController _schoolCtrl = TextEditingController();
  final TextEditingController _directorateCtrl = TextEditingController(
    text: 'المديرية العامة للتربية',
  );

  @override
  void dispose() {
    _teacherCtrl.dispose();
    _schoolCtrl.dispose();
    _directorateCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    AppScope.of(context).completeOnboarding(
      part: _selectedPart,
      teacherName: _teacherCtrl.text,
      schoolName: _schoolCtrl.text,
      directorate: _directorateCtrl.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
          children: <Widget>[
            AppPage(
              maxWidth: 640,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const BayanEmblem(size: 52),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('بَيَان', style: theme.textTheme.displaySmall),
                            Text(
                              'اللغة العربية للصف الأول المتوسط — المنهج الرسمي الكامل',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    '١. اختر الجزء الدراسي الحالي',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'يمكنك التبديل بين الجزء الأول والجزء الثاني في أي وقت من الشاشة الرئيسية أو الإعدادات.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (final part in CurriculumPart.values) ...<Widget>[
                    _PartOptionCard(
                      key: ValueKey<String>('onboard-${part.id}'),
                      part: part,
                      selected: _selectedPart == part,
                      onTap: () => setState(() => _selectedPart = part),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  const SizedBox(height: AppSpacing.lg),
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
                        Text(
                          '٢. بيانات المدرس والمدرسة (اختياري)',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'تُحفظ محلياً على جهازك وتُدرج تلقائياً في ترويسة وتذييل أوراق أسئلة الامتحان بصيغة Word (.docx).',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextField(
                          key: const ValueKey<String>('onboard-teacher-name'),
                          controller: _teacherCtrl,
                          decoration: const InputDecoration(
                            labelText: 'اسم مدرس المادة',
                            hintText: 'مثال: حيدر محمد الكعبي',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextField(
                          key: const ValueKey<String>('onboard-school-name'),
                          controller: _schoolCtrl,
                          decoration: const InputDecoration(
                            labelText: 'اسم المدرسة',
                            hintText: 'مثال: متوسطة المتنبي للبنين',
                            prefixIcon: Icon(Icons.school_outlined),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextField(
                          key: const ValueKey<String>('onboard-directorate'),
                          controller: _directorateCtrl,
                          decoration: const InputDecoration(
                            labelText: 'مديرية التربية',
                            prefixIcon: Icon(Icons.account_balance_outlined),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: AppPage(
              maxWidth: 640,
              padding: EdgeInsets.zero,
              child: FilledButton.icon(
                key: const ValueKey<String>('onboard-start-button'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _submit,
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('البدء في تصفح المنهج'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PartOptionCard extends StatelessWidget {
  const _PartOptionCard({
    super.key,
    required this.part,
    required this.selected,
    required this.onTap,
  });

  final CurriculumPart part;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: selected
          ? scheme.primaryContainer.withValues(alpha: 0.55)
          : scheme.surface,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(part.title, style: theme.textTheme.titleMedium),
                    Text(part.subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
