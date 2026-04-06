import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:campusgig/services/onboarding_state.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingPageData> _pages = const [
    _OnboardingPageData(
      title: 'Kampuste yetenegini gelire cevir.',
      subtitle: 'Dakikalar icinde hizmet ver ya da gorev ustlen.',
      accentA: Color(0xFF7CFF6B),
      accentB: Color(0xFF1E9D4B),
      icon: LucideIcons.sparkles,
      cta: 'Devam Et',
    ),
    _OnboardingPageData(
      title: 'Iki yol, tek platform.',
      subtitle:
          'Hizmette saglayici kazanir; gorevde ilan acan oder, ustlenen kazanir.',
      accentA: Color(0xFF4CC9FF),
      accentB: Color(0xFF8B5CF6),
      icon: LucideIcons.gitMerge,
      cta: 'Devam Et',
    ),
    _OnboardingPageData(
      title: 'Guvenli havuz + PIN dogrulama.',
      subtitle: 'Teklif -> Onay -> PIN -> Hizmet -> Odeme Aktar/Itiraz',
      footer: '24 saat icinde aksiyon yoksa otomatik onay devreye girer.',
      accentA: Color(0xFF7CFF6B),
      accentB: Color(0xFF38BDF8),
      icon: LucideIcons.shieldCheck,
      cta: 'Hemen Katil',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentPage];
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: const [Color(0xFF070B1A), Color(0xFF141230)],
                ),
              ),
            ),
          ),
          Positioned(
            top: -120,
            left: -80,
            child: _blob(page.accentA),
          ),
          Positioned(
            bottom: -120,
            right: -80,
            child: _blob(page.accentB),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: const SizedBox(),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: TextButton(
                    onPressed: () async {
                      await OnboardingState.markSeen();
                      if (!mounted) return;
                      context.go('/login');
                    },
                    child: const Text('Atla',
                        style: TextStyle(color: Color(0xFF9CA3AF))),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _pages.length,
                    onPageChanged: (value) =>
                        setState(() => _currentPage = value),
                    itemBuilder: (context, index) => _buildPage(_pages[index]),
                  ),
                ),
                _buildDots(),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (_currentPage < _pages.length - 1) {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                          );
                          return;
                        }
                        await OnboardingState.markSeen();
                        if (!mounted) return;
                        context.go('/login');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18)),
                      ),
                      child: Ink(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: LinearGradient(
                              colors: [page.accentA, page.accentB]),
                          boxShadow: [
                            BoxShadow(
                              color: page.accentA.withOpacity(0.35),
                              blurRadius: 16,
                              spreadRadius: 1,
                            )
                          ],
                        ),
                        child: Center(
                          child: Text(
                            page.cta,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ),
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

  Widget _buildPage(_OnboardingPageData page) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [page.accentA, page.accentB]),
                boxShadow: [
                  BoxShadow(
                    color: page.accentA.withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
                  )
                ],
              ),
              child: Icon(page.icon, color: Colors.white, size: 38),
            ),
          ),
          const SizedBox(height: 36),
          Text(
            page.title,
            style: const TextStyle(
              color: Color(0xFFF3F4F6),
              fontSize: 30,
              height: 1.15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            page.subtitle,
            style: const TextStyle(
              color: Color(0xFFD1D5DB),
              fontSize: 15,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (page.footer != null) ...[
            const SizedBox(height: 14),
            Text(
              page.footer!,
              style: TextStyle(
                color: page.accentA.withOpacity(0.9),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (page.title.startsWith('Iki yol')) ...[
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child:
                      _modeCard('Hizmet Ver', 'Yetenek Pazari', page.accentA),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _modeCard(
                      'Gorev Ac/Ustlen', 'Gorev Panosu', page.accentB),
                ),
              ],
            ),
          ] else if (page.title.startsWith('Kampuste')) ...[
            const SizedBox(height: 22),
            _serviceMockCard(page.accentA, page.accentB),
          ] else ...[
            const SizedBox(height: 22),
            _secureFlowMock(page.accentA, page.accentB),
          ],
        ],
      ),
    );
  }

  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pages.length, (index) {
        final isActive = index == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 18 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF7CFF6B) : const Color(0xFF4B5563),
            borderRadius: BorderRadius.circular(99),
          ),
        );
      }),
    );
  }

  Widget _modeCard(String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0x1FFFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Color(0xFFF3F4F6),
                  fontWeight: FontWeight.w800,
                  fontSize: 13)),
          const SizedBox(height: 2),
          Text(subtitle,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w700, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _blob(Color color) {
    return Container(
      width: 260,
      height: 260,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.2),
      ),
    );
  }

  Widget _serviceMockCard(Color a, Color b) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0x1CFFFFFF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: a.withOpacity(0.35)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [a, b]),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.user,
                        size: 16, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Matematik Odev Destegi',
                      style: TextStyle(
                          color: Color(0xFFF3F4F6),
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: a.withOpacity(0.15),
                    ),
                    child: Text('HIZMET',
                        style: TextStyle(
                            color: a,
                            fontSize: 10,
                            fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(colors: [a, b]),
                  boxShadow: [
                    BoxShadow(color: a.withOpacity(0.35), blurRadius: 12)
                  ],
                ),
                child: const Center(
                  child: Text('Teklife Git',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _secureFlowMock(Color a, Color b) {
    final steps = const ['Teklif', 'Onay', 'PIN', 'Hizmet', 'Odeme'];
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0x1CFFFFFF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: b.withOpacity(0.35)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(steps.length, (index) {
              final isLast = index == steps.length - 1;
              return Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Circle + label stacked vertically
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(colors: [a, b]),
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            steps[index],
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFD1D5DB),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Connector line between circles (aligned to circle center)
                    if (!isLast)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Container(
                          width: 8,
                          height: 2,
                          color: Colors.white24,
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _OnboardingPageData {
  final String title;
  final String subtitle;
  final String? footer;
  final Color accentA;
  final Color accentB;
  final IconData icon;
  final String cta;

  const _OnboardingPageData({
    required this.title,
    required this.subtitle,
    this.footer,
    required this.accentA,
    required this.accentB,
    required this.icon,
    required this.cta,
  });
}
