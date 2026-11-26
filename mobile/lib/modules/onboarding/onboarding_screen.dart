import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app_router.dart';
import '../../shared/network/local/cache_helper.dart';
import '../../l10n/app_strings.dart';
import '../../shared/styles/colors.dart';
import '../../shared/components/components.dart';

class _Slide {
  final IconData icon;
  final String titleKey;
  final String bodyKey;
  const _Slide(this.icon, this.titleKey, this.bodyKey);
}

const _slides = [
  _Slide(Icons.medication_liquid, 'ob1.title', 'ob1.body'),
  _Slide(Icons.document_scanner, 'ob2.title', 'ob2.body'),
  _Slide(Icons.diversity_1, 'ob3.title', 'ob3.body'),
];

/// First-launch onboarding (3 slides) — shown once, then never again.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await CacheHelper.setOnboardingSeen();
    if (mounted) context.go(Routes.login);
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _slides.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                children: [
                  // Language switch on the very first screen — an English
                  // speaker must be able to read the onboarding from slide 1.
                  const Padding(
                    padding: EdgeInsetsDirectional.only(start: 8),
                    child: LanguageToggle(),
                  ),
                  TextButton(
                    onPressed: _finish,
                    child: Text(context.tr('ob.skip')),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) {
                  final slide = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: GlassCard(
                      padding: const EdgeInsets.all(24),
                      radius: 28,
                      child: Center(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(slide.icon,
                                    size: 62, color: AppColors.primary),
                              ),
                              const SizedBox(height: 24),
                              Text(context.tr(slide.titleKey),
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 12),
                              Text(context.tr(slide.bodyKey),
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyLarge),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _slides.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _page ? 28 : 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: i == _page
                          ? AppColors.primary
                          : AppColors.primary.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: isLast
                      ? _finish
                      : () => _controller.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          ),
                  child: Text(isLast ? context.tr('ob.start') : context.tr('ob.next')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
