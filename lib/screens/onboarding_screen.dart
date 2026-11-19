import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  // Step 1 — Goal
  String? _selectedGoal;
  // Step 2 — Diet
  final Set<String> _selectedDiet = {};
  // Step 3 — Region
  String? _selectedRegion;
  // Step 4 — Notifications
  bool _notificationsEnabled = true;

  static const _goals = [
    ('🏃', 'Lose Weight',    'Burn fat with balanced meals'),
    ('💪', 'Build Muscle',   'High-protein Indian diet'),
    ('🥗', 'Eat Healthy',    'Nutritious everyday choices'),
    ('🩺', 'Manage Health',  'Diabetes, BP, cholesterol'),
    ('⚡', 'Boost Energy',   'Combat fatigue naturally'),
    ('👨‍👩‍👧', 'Family Nutrition', 'Balanced meals for all ages'),
  ];

  static const _diets = [
    '🥬 Vegetarian', '🌱 Vegan', '🙏 Jain',
    '🌾 Gluten-Free', '🥛 Lactose-Free', '🫀 Low-Sodium',
    '🩸 Diabetic-Friendly', '🫀 Low-Cholesterol', '🥩 Non-Vegetarian',
  ];

  static const _regions = [
    ('🏔️', 'North Indian',   'Dal makhani, roti, paneer'),
    ('🌴', 'South Indian',   'Idli, dosa, sambar, rasam'),
    ('🌊', 'Bengali',        'Fish curry, mishti doi'),
    ('🌸', 'Gujarati',       'Dhokla, thepla, farsan'),
    ('🌶️', 'Rajasthani',     'Dal baati, gatte ki sabzi'),
    ('🫚', 'Punjabi',        'Butter chicken, sarson saag'),
    ('🍋', 'Maharashtrian',  'Varan bhat, misal pav'),
    ('🌿', 'Kerala',         'Appam, stew, fish moilee'),
  ];

  static const _brandColor = Color(0xFF2D5B42);
  static const _totalPages = 4;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  void _skip() => _finish();

  Future<void> _finish() async {
    await ref.read(onboardingProvider.notifier).complete(
      goal: _selectedGoal,
      diet: _selectedDiet.toList(),
      region: _selectedRegion,
      notifications: _notificationsEnabled,
    );
  }

  bool get _canProceed {
    switch (_currentPage) {
      case 0: return _selectedGoal != null;
      case 1: return _selectedDiet.isNotEmpty;
      case 2: return _selectedRegion != null;
      default: return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              currentPage: _currentPage,
              total: _totalPages,
              onSkip: _skip,
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (p) => setState(() => _currentPage = p),
                children: [
                  _GoalStep(
                    goals: _goals,
                    selected: _selectedGoal,
                    onSelected: (g) => setState(() => _selectedGoal = g),
                  ),
                  _DietStep(
                    diets: _diets,
                    selected: _selectedDiet,
                    onToggle: (d) => setState(() {
                      _selectedDiet.contains(d)
                          ? _selectedDiet.remove(d)
                          : _selectedDiet.add(d);
                    }),
                  ),
                  _RegionStep(
                    regions: _regions,
                    selected: _selectedRegion,
                    onSelected: (r) => setState(() => _selectedRegion = r),
                  ),
                  _NotifStep(
                    enabled: _notificationsEnabled,
                    onChanged: (v) => setState(() => _notificationsEnabled = v),
                  ),
                ],
              ),
            ),
            _BottomBar(
              currentPage: _currentPage,
              total: _totalPages,
              canProceed: _canProceed,
              onNext: _next,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Top bar ──────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.currentPage, required this.total, required this.onSkip});
  final int currentPage;
  final int total;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Row(
            children: List.generate(total, (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(right: 6),
              height: 4,
              width: i == currentPage ? 24 : 8,
              decoration: BoxDecoration(
                color: i == currentPage
                    ? const Color(0xFF2D5B42)
                    : const Color(0xFFD1E8D8),
                borderRadius: BorderRadius.circular(2),
              ),
            )),
          ),
          const Spacer(),
          if (currentPage < 3)
            TextButton(
              onPressed: onSkip,
              child: const Text('Skip', style: TextStyle(color: Colors.grey)),
            ),
        ],
      ),
    );
  }
}

// ── Bottom bar ───────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.currentPage,
    required this.total,
    required this.canProceed,
    required this.onNext,
  });
  final int currentPage;
  final int total;
  final bool canProceed;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final isLast = currentPage == total - 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: canProceed ? onNext : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2D5B42),
            disabledBackgroundColor: const Color(0xFFD1E8D8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Text(
            isLast ? "Let's Start!" : 'Continue',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Step 1: Goal ─────────────────────────────────────────────────────────────

class _GoalStep extends StatelessWidget {
  const _GoalStep({required this.goals, required this.selected, required this.onSelected});
  final List<(String, String, String)> goals;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const Text('What\'s your goal?',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('We\'ll personalise your meal plan around it.',
              style: TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: goals.map((g) {
                final isSelected = selected == g.$2;
                return GestureDetector(
                  onTap: () => onSelected(g.$2),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFE8F5EE)
                          : const Color(0xFFF8F9FA),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF2D5B42)
                            : Colors.transparent,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(g.$1, style: const TextStyle(fontSize: 24)),
                        const SizedBox(height: 4),
                        Text(g.$2,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: isSelected
                                  ? const Color(0xFF2D5B42)
                                  : Colors.black87,
                            )),
                        Text(g.$3,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step 2: Dietary preferences ───────────────────────────────────────────────

class _DietStep extends StatelessWidget {
  const _DietStep({required this.diets, required this.selected, required this.onToggle});
  final List<String> diets;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const Text('Dietary preferences',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Select all that apply.',
              style: TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 24),
          Expanded(
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: diets.map((d) {
                final isSelected = selected.contains(d);
                return FilterChip(
                  label: Text(d),
                  selected: isSelected,
                  onSelected: (_) => onToggle(d),
                  selectedColor: const Color(0xFFE8F5EE),
                  checkmarkColor: const Color(0xFF2D5B42),
                  side: BorderSide(
                    color: isSelected
                        ? const Color(0xFF2D5B42)
                        : Colors.grey.shade300,
                  ),
                  labelStyle: TextStyle(
                    color: isSelected
                        ? const Color(0xFF2D5B42)
                        : Colors.black87,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step 3: Regional cuisine ─────────────────────────────────────────────────

class _RegionStep extends StatelessWidget {
  const _RegionStep({required this.regions, required this.selected, required this.onSelected});
  final List<(String, String, String)> regions;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const Text('Your regional cuisine',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('We\'ll suggest familiar, local recipes.',
              style: TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.separated(
              itemCount: regions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final r = regions[i];
                final isSelected = selected == r.$2;
                return GestureDetector(
                  onTap: () => onSelected(r.$2),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFE8F5EE)
                          : const Color(0xFFF8F9FA),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF2D5B42)
                            : Colors.transparent,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Text(r.$1,
                            style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.$2,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? const Color(0xFF2D5B42)
                                        : Colors.black87,
                                  )),
                              Text(r.$3,
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle,
                              color: Color(0xFF2D5B42), size: 20),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step 4: Notifications ────────────────────────────────────────────────────

class _NotifStep extends StatelessWidget {
  const _NotifStep({required this.enabled, required this.onChanged});
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5EE),
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Icon(Icons.notifications_active,
                size: 48, color: Color(0xFF2D5B42)),
          ),
          const SizedBox(height: 28),
          const Text('Stay on track',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text(
            'Get meal reminders, weekly nutrition summaries, and smart nudges when you skip logging.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey, height: 1.5),
          ),
          const SizedBox(height: 32),
          _NotifTile(
            icon: Icons.restaurant,
            title: 'Meal reminders',
            subtitle: 'Breakfast, lunch & dinner prompts',
            enabled: enabled,
            onChanged: onChanged,
          ),
          const SizedBox(height: 12),
          _NotifTile(
            icon: Icons.bar_chart,
            title: 'Weekly nutrition summary',
            subtitle: 'Every Sunday morning',
            enabled: enabled,
            onChanged: onChanged,
          ),
          const SizedBox(height: 12),
          _NotifTile(
            icon: Icons.shopping_cart,
            title: 'Shopping reminders',
            subtitle: 'When grocery list is ready',
            enabled: enabled,
            onChanged: onChanged,
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => onChanged(!enabled),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Switch(
                  value: enabled,
                  onChanged: onChanged,
                  activeColor: const Color(0xFF2D5B42),
                ),
                const SizedBox(width: 8),
                Text(
                  enabled ? 'Notifications ON' : 'Notifications OFF',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: enabled
                        ? const Color(0xFF2D5B42)
                        : Colors.grey,
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

class _NotifTile extends StatelessWidget {
  const _NotifTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onChanged,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: enabled
            ? const Color(0xFFE8F5EE)
            : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon,
              color: enabled ? const Color(0xFF2D5B42) : Colors.grey,
              size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: enabled ? Colors.black87 : Colors.grey,
                    )),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
