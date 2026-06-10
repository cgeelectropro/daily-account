import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../l10n/generated/app_localizations.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import '../services/storage_service.dart';
import '../widgets/common_widgets.dart';
import 'home_shell.dart';

/// A beautiful 4-page onboarding flow for first-time users.
/// Pages: Welcome, How It Works, Profile Setup, Language Selection.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Profile fields
  String _name = '';
  String _discipleEmail = '';
  String _discipleWhatsApp = '';

  // Language selection
  String _selectedLanguage = 'en';

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  void _next() {
    if (_currentPage < 3) {
      _goToPage(_currentPage + 1);
    }
  }

  void _back() {
    if (_currentPage > 0) {
      _goToPage(_currentPage - 1);
    }
  }

  void _skip() {
    _goToPage(3);
  }

  Future<void> _saveProfileFields() async {
    final s = StorageService.instance;
    if (_name.isNotEmpty) await s.setSetting('myName', _name);
    if (_discipleEmail.isNotEmpty) {
      await s.setSetting('discipleEmail', _discipleEmail);
    }
    if (_discipleWhatsApp.isNotEmpty) {
      await s.setSetting('discipleWhatsApp', _discipleWhatsApp);
    }
  }

  Future<void> _finish() async {
    await _saveProfileFields();
    await StorageService.instance
        .setSetting('onboarding_complete', 'true');
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const HomeShell(),
        transitionDuration: const Duration(milliseconds: 800),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = S.of(context);
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  physics: const ClampingScrollPhysics(),
                  children: [
                    _buildWelcomePage(l),
                    _buildHowItWorksPage(l),
                    _buildProfilePage(l),
                    _buildLanguagePage(l),
                  ],
                ),
              ),
              _buildBottomNav(l),
            ],
          ),
        ),
      ),
    );
  }

  // ── Page 1: Welcome ──────────────────────────────────────────
  Widget _buildWelcomePage(S l) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '\u2720', // golden cross emoji / maltese cross
            style: TextStyle(fontSize: 72, color: AppTheme.gold),
          )
              .animate()
              .scale(
                begin: const Offset(0.0, 0.0),
                end: const Offset(1.0, 1.0),
                duration: 800.ms,
                curve: Curves.easeOutBack,
              )
              .fadeIn(duration: 600.ms),
          const SizedBox(height: 32),
          Text(
            l.onboardingWelcome,
            textAlign: TextAlign.center,
            style: AppTheme.display(34, color: AppTheme.gold),
          )
              .animate()
              .fadeIn(duration: 800.ms, delay: 300.ms)
              .slideY(
                begin: 0.3,
                end: 0,
                duration: 800.ms,
                delay: 300.ms,
                curve: Curves.easeOut,
              ),
          const SizedBox(height: 20),
          Text(
            l.onboardingWelcomeSub,
            textAlign: TextAlign.center,
            style: AppTheme.serif(16, color: AppTheme.sand),
          )
              .animate()
              .fadeIn(duration: 800.ms, delay: 600.ms)
              .slideY(
                begin: 0.3,
                end: 0,
                duration: 800.ms,
                delay: 600.ms,
                curve: Curves.easeOut,
              ),
          const SizedBox(height: 40),
          Text(
            l.splashVerse,
            textAlign: TextAlign.center,
            style: AppTheme.serif(13,
                color: AppTheme.clay, style: FontStyle.italic),
          ).animate().fadeIn(duration: 800.ms, delay: 1000.ms),
        ],
      ),
    );
  }

  // ── Page 2: How It Works ─────────────────────────────────────
  Widget _buildHowItWorksPage(S l) {
    final steps = [
      ('\u{1F4D6}', l.onboardingHowStep1), // open book
      ('\u{1F64F}', l.onboardingHowStep2), // folded hands
      ('\u{1F4E8}', l.onboardingHowStep3), // incoming envelope
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            l.onboardingHow,
            style: AppTheme.display(30, color: AppTheme.gold),
          )
              .animate()
              .fadeIn(duration: 600.ms)
              .slideY(begin: 0.2, end: 0, duration: 600.ms),
          const SizedBox(height: 40),
          ...List.generate(steps.length, (i) {
            final (icon, text) = steps[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppTheme.gold.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                      border:
                          Border.all(color: AppTheme.gold.withOpacity(0.25)),
                    ),
                    alignment: Alignment.center,
                    child: Text(icon, style: const TextStyle(fontSize: 24)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(
                        text,
                        style: AppTheme.serif(15, color: AppTheme.cream),
                      ),
                    ),
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(
                  duration: 500.ms,
                  delay: Duration(milliseconds: 200 + i * 200),
                )
                .slideX(
                  begin: 0.15,
                  end: 0,
                  duration: 500.ms,
                  delay: Duration(milliseconds: 200 + i * 200),
                  curve: Curves.easeOut,
                );
          }),
        ],
      ),
    );
  }

  // ── Page 3: Profile Setup ────────────────────────────────────
  Widget _buildProfilePage(S l) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          Center(
            child: Text(
              l.onboardingProfile,
              style: AppTheme.display(28, color: AppTheme.gold),
            ),
          )
              .animate()
              .fadeIn(duration: 600.ms)
              .slideY(begin: 0.2, end: 0, duration: 600.ms),
          const SizedBox(height: 8),
          Center(
            child: Text(
              l.onboardingProfileSub,
              style: AppTheme.serif(15, color: AppTheme.sand),
            ),
          ).animate().fadeIn(duration: 600.ms, delay: 200.ms),
          const SizedBox(height: 36),
          GoldField(
            label: l.yourNameLabel,
            hint: l.yourNameHint,
            value: _name,
            onChanged: (v) {
              _name = v;
              StorageService.instance.setSetting('myName', v);
            },
          ).animate().fadeIn(duration: 500.ms, delay: 300.ms),
          GoldField(
            label: l.emailLabel,
            hint: l.emailHint,
            value: _discipleEmail,
            keyboardType: TextInputType.emailAddress,
            onChanged: (v) {
              _discipleEmail = v;
              StorageService.instance.setSetting('discipleEmail', v);
            },
          ).animate().fadeIn(duration: 500.ms, delay: 450.ms),
          GoldField(
            label: l.whatsappLabel,
            hint: l.whatsappHint,
            value: _discipleWhatsApp,
            keyboardType: TextInputType.phone,
            onChanged: (v) {
              _discipleWhatsApp = v;
              StorageService.instance.setSetting('discipleWhatsApp', v);
            },
          ).animate().fadeIn(duration: 500.ms, delay: 600.ms),
        ],
      ),
    );
  }

  // ── Page 4: Language Selection ───────────────────────────────
  Widget _buildLanguagePage(S l) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            l.onboardingLanguage,
            style: AppTheme.display(28, color: AppTheme.gold),
          )
              .animate()
              .fadeIn(duration: 600.ms)
              .slideY(begin: 0.2, end: 0, duration: 600.ms),
          const SizedBox(height: 40),
          _buildLanguageCard(
            flag: '\u{1F1EC}\u{1F1E7}', // British flag
            label: 'English',
            code: 'en',
            delay: 200,
          ),
          const SizedBox(height: 16),
          _buildLanguageCard(
            flag: '\u{1F1EB}\u{1F1F7}', // French flag
            label: 'Fran\u00e7ais',
            code: 'fr',
            delay: 350,
          ),
          const SizedBox(height: 48),
          GestureDetector(
            onTap: _finish,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: AppTheme.goldGradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.gold.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                l.onboardingStart,
                style: AppTheme.display(18, color: AppTheme.bg0),
              ),
            ),
          )
              .animate()
              .fadeIn(duration: 600.ms, delay: 600.ms)
              .slideY(
                begin: 0.2,
                end: 0,
                duration: 600.ms,
                delay: 600.ms,
                curve: Curves.easeOut,
              ),
        ],
      ),
    );
  }

  Widget _buildLanguageCard({
    required String flag,
    required String label,
    required String code,
    required int delay,
  }) {
    final selected = _selectedLanguage == code;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedLanguage = code);
        DailyAccountApp.setLocale(context, Locale(code));
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 24),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.gold.withOpacity(0.15)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppTheme.gold
                : AppTheme.gold.withOpacity(0.15),
            width: selected ? 2.0 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 18),
            Text(
              label,
              style: AppTheme.display(
                20,
                color: selected ? AppTheme.gold : AppTheme.cream,
              ),
            ),
            const Spacer(),
            if (selected)
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: AppTheme.gold,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  size: 16,
                  color: AppTheme.bg0,
                ),
              ),
          ],
        ),
      ),
    ).animate().fadeIn(
          duration: 500.ms,
          delay: Duration(milliseconds: delay),
        );
  }

  // ── Bottom navigation (dots + buttons) ───────────────────────
  Widget _buildBottomNav(S l) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Page indicator dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (i) {
              final active = _currentPage == i;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: active ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: active
                      ? AppTheme.gold
                      : AppTheme.gold.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          // Navigation buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Back button (pages 2-4)
              if (_currentPage > 0)
                GestureDetector(
                  onTap: _back,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    child: Text(
                      l.back,
                      style: AppTheme.serif(15, color: AppTheme.sand),
                    ),
                  ),
                )
              else
                const SizedBox(width: 80),

              // Skip link (pages 1-2) or spacer
              if (_currentPage <= 1)
                GestureDetector(
                  onTap: _skip,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Text(
                      l.skip,
                      style:
                          AppTheme.serif(14, color: AppTheme.clay),
                    ),
                  ),
                )
              else
                const SizedBox(width: 60),

              // Next button (pages 1-3)
              if (_currentPage < 3)
                GestureDetector(
                  onTap: _next,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: AppTheme.goldGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      l.next,
                      style: AppTheme.display(15, color: AppTheme.bg0),
                    ),
                  ),
                )
              else
                const SizedBox(width: 80),
            ],
          ),
        ],
      ),
    );
  }
}
