import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/budget_controller.dart';
import '../navigation/main_shell.dart';

/// Screen 0: Personalization & Onboarding Setup ("Minty Nest" Google Stitch)
class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final _nameController = TextEditingController();
  final _universityController = TextEditingController();
  final _budgetTargetController = TextEditingController(text: '1500');

  String _selectedStanding = '';
  bool _workStudyEnabled = true;
  double _monthlyTarget = 1500.0;
  String _pin = '';
  bool _biometricEnabled = true;
  String? _errorMessage;
  bool _isSubmitting = false;

  final List<String> _standings = [
    'Freshman',
    'Sophomore',
    'Junior',
    'Senior',
    'Grad',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _universityController.dispose();
    _budgetTargetController.dispose();
    super.dispose();
  }

  void _onDigitPressed(String digit) {
    HapticFeedback.lightImpact();
    if (_pin.length < 4) {
      setState(() {
        _pin += digit;
        _errorMessage = null;
      });
    }
  }

  void _onDeletePressed() {
    HapticFeedback.lightImpact();
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
        _errorMessage = null;
      });
    }
  }

  Future<void> _handleCompleteSetup() async {
    final name = _nameController.text.trim();
    final university = _universityController.text.trim();

    if (name.isEmpty) {
      setState(() => _errorMessage = 'Please enter your full legal name');
      return;
    }
    if (university.isEmpty) {
      setState(() => _errorMessage = 'Please enter your university and major');
      return;
    }
    if (_pin.length < 4) {
      setState(
          () => _errorMessage = 'Please complete your 4-digit vault passcode');
      return;
    }

    setState(() => _isSubmitting = true);

    final auth = Provider.of<AuthController>(context, listen: false);
    final budget = Provider.of<BudgetController>(context, listen: false);

    final emergencyBuffer = (_monthlyTarget * 0.15).roundToDouble();

    await auth.completeOnboarding(
      name: name,
      university: university,
      standing: _selectedStanding,
      hasWorkStudy: _workStudyEnabled,
      isBiometricEnabled: _biometricEnabled,
      pin: _pin,
      budgetCap: _monthlyTarget,
      safeBuffer: emergencyBuffer,
    );

    await budget.setBudgetCap(_monthlyTarget, emergencyBuffer);

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const MainShell(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curve =
              CurvedAnimation(parent: animation, curve: Curves.easeInOutCubic);
          return FadeTransition(
            opacity: curve,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.04),
                end: Offset.zero,
              ).animate(curve),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic breakdown calculation based on _monthlyTarget:
    // Housing & Dining (55%), Textbooks & Tech (15%), Social & Coffee (15%), Emergency Buffer (15%)
    final housingDiningAmount = (_monthlyTarget * 0.55).round();
    final textbooksTechAmount = (_monthlyTarget * 0.15).round();
    final socialCoffeeAmount = (_monthlyTarget * 0.15).round();
    final emergencyBufferAmount = (_monthlyTarget * 0.15).round();

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top Step Indicator ──────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryFixed.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'STEP 1 OF 1',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Personalization & Setup',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Progress Bar (100% filled)
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  height: 8,
                  width: double.infinity,
                  color: AppColors.surfaceHigh,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: 1.0,
                    child: Container(color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // ── Welcoming Headline Card ─────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0E0B6945),
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Let's personalize your student nest 🌱",
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Set up your campus profile, monthly allowance, and confidential vault.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Mascot / Student Avatar Badge
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainer,
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: AppColors.primaryFixed, width: 2),
                      ),
                      child: const Center(
                        child: Text(
                          '🎓',
                          style: TextStyle(fontSize: 26),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Card 1: Campus Profile ──────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0E0B6945),
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryFixed,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.school,
                              color: AppColors.primary, size: 18),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Campus Profile',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'Helps tailor student discounts & aid reminders',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Legal Name Field
                    const Text(
                      'Full Legal Name',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _nameController,
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Your name',
                        hintText: 'Enter your full name',
                        hintStyle: const TextStyle(color: AppColors.outline),
                        labelStyle: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12),
                        prefixIcon: const Icon(Icons.badge_outlined,
                            color: AppColors.outline, size: 20),
                        filled: true,
                        fillColor: AppColors.surfaceLow,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // University & Major Field
                    const Text(
                      'University & Major',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _universityController,
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Institution and degree',
                        hintText: 'e.g., INSAT / Faculty of Sciences',
                        hintStyle: const TextStyle(color: AppColors.outline),
                        labelStyle: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12),
                        prefixIcon: const Icon(Icons.account_balance_outlined,
                            color: AppColors.outline, size: 20),
                        filled: true,
                        fillColor: AppColors.surfaceLow,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Current Standing Pills
                    const Text(
                      'Current Standing',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _standings.map((standing) {
                        final isSelected = _selectedStanding == standing;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedStanding = standing),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.surfaceLow,
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: isSelected
                                  ? [
                                      const BoxShadow(
                                        color: Color(0x2E0B6945),
                                        blurRadius: 8,
                                        offset: Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Text(
                              standing,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Work-Study Switch Tile
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLow,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              color: AppColors.secondaryFixed,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.work_outline,
                                color: AppColors.secondary, size: 18),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Campus Job / Work-Study',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  'Bi-weekly pay schedule enabled',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _workStudyEnabled,
                            activeColor: Colors.white,
                            activeTrackColor: AppColors.primary,
                            inactiveThumbColor: Colors.white,
                            inactiveTrackColor: AppColors.surfaceHigh,
                            onChanged: (val) =>
                                setState(() => _workStudyEnabled = val),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Card 2: Monthly Spending Target ─────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0E0B6945),
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: AppColors.tertiaryFixed,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.payments_outlined,
                              color: AppColors.tertiary, size: 18),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Monthly Spending Target',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'Your comfortable campus baseline',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Centered Headline Display
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLow,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'ESTIMATED TOTAL',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  '${_monthlyTarget.toInt()} DT',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppColors.primary,
                                    fontSize: 34,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1.0,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '/ month',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Direct Amount Input Field for Bidirectional Control
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.surfaceHigh),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.edit_outlined,
                                      size: 14, color: AppColors.textSecondary),
                                  const SizedBox(width: 6),
                                  const Text('Direct Cap: ',
                                      style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600)),
                                  SizedBox(
                                    width: 60,
                                    child: TextField(
                                      controller: _budgetTargetController,
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                      ),
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      onChanged: (text) {
                                        final parsed = double.tryParse(text) ??
                                            _monthlyTarget;
                                        setState(() {
                                          _monthlyTarget =
                                              parsed.clamp(0.0, 3000.0);
                                        });
                                      },
                                    ),
                                  ),
                                  const Text('DT',
                                      style: TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Interactive Continuous Slider (0 DT to 3000 DT)
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: AppColors.primary,
                              inactiveTrackColor: AppColors.surfaceHigh,
                              thumbColor: AppColors.primary,
                              overlayColor: AppColors.primary.withOpacity(0.15),
                              trackHeight: 6,
                              thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 10),
                            ),
                            child: Slider(
                              value: _monthlyTarget.clamp(0.0, 3000.0),
                              min: 0.0,
                              max: 3000.0,
                              onChanged: (val) {
                                setState(() {
                                  _monthlyTarget = val;
                                  _budgetTargetController.text =
                                      val.toInt().toString();
                                });
                              },
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text('0 DT',
                                        style: TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 11)),
                                  ),
                                ),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text('1,500 DT',
                                        style: TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 11)),
                                  ),
                                ),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text('+3,000 DT',
                                        style: TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 11)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Category Allocation Grid (2 columns: 55%, 15%, 15%, 15%)
                    const Text(
                      'Category Allocation',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _allocationMiniCard(
                            dotColor: AppColors.categoryHousing,
                            label: 'Housing & Dining',
                            amount: '$housingDiningAmount DT',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _allocationMiniCard(
                            dotColor: AppColors.categoryBooks,
                            label: 'Textbooks & Tech',
                            amount: '$textbooksTechAmount DT',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _allocationMiniCard(
                            dotColor: AppColors.categorySocial,
                            label: 'Social & Coffee',
                            amount: '$socialCoffeeAmount DT',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _allocationMiniCard(
                            dotColor: AppColors.categoryEmergency,
                            label: 'Emergency Buffer',
                            amount: '$emergencyBufferAmount DT',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Smart Suggestion Tip Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHigh.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                              color: AppColors.tertiaryFixed,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.tips_and_updates,
                                color: AppColors.tertiary, size: 14),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Smart Student Suggestion',
                                  style: TextStyle(
                                    color: AppColors.tertiary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Living on campus? Combining campus meal plan points covers ~42% of daily lunches!',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                    height: 1.35,
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
              const SizedBox(height: 16),

              // ── Card 3: Confidential Vault PIN ─────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0E0B6945),
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: AppColors.secondaryFixed,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.lock_outline,
                              color: AppColors.secondary, size: 18),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Confidential Vault PIN',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'Protects FAFSA docs, leases & direct deposit info',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 4-digit PIN Box Displays
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (index) {
                          final isFilled = index < _pin.length;
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            width: 48,
                            height: 56,
                            decoration: BoxDecoration(
                              color: isFilled
                                  ? AppColors.surfaceLow
                                  : AppColors.surfaceHigh,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isFilled
                                    ? AppColors.primary
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Center(
                              child: isFilled
                                  ? const Text(
                                      '•',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 28,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    )
                                  : const Text(
                                      '•',
                                      style: TextStyle(
                                        color: AppColors.outlineVariant,
                                        fontSize: 24,
                                      ),
                                    ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Numeric Keypad
                    _buildNumericKeypad(),
                    const SizedBox(height: 14),

                    // Biometric Login Switch Tile
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLow,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              color: AppColors.secondaryFixed,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.fingerprint,
                                color: AppColors.secondary, size: 18),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Enable Biometric Login',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  'Instant unlock with Face ID / Fingerprint',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _biometricEnabled,
                            activeColor: Colors.white,
                            activeTrackColor: AppColors.primary,
                            inactiveThumbColor: Colors.white,
                            inactiveTrackColor: AppColors.surfaceHigh,
                            onChanged: (val) =>
                                setState(() => _biometricEnabled = val),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Center(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

              // ── Full-Width Deep Emerald Bottom Action Button ────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleCompleteSetup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    elevation: 2,
                    shadowColor: const Color(0x330B6945),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Complete Setup & Enter Nest',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward, size: 18),
                            ],
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _allocationMiniCard({
    required Color dotColor,
    required String label,
    required String amount,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Text(
                  amount,
                  style: const TextStyle(
                    color: AppColors.textOnSurfaceVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumericKeypad() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['1', '2', '3']
                  .map((d) => _keypadButton(d, () => _onDigitPressed(d)))
                  .toList(),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['4', '5', '6']
                  .map((d) => _keypadButton(d, () => _onDigitPressed(d)))
                  .toList(),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['7', '8', '9']
                  .map((d) => _keypadButton(d, () => _onDigitPressed(d)))
                  .toList(),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const SizedBox(width: 60, height: 42),
                _keypadButton('0', () => _onDigitPressed('0')),
                SizedBox(
                  width: 60,
                  height: 42,
                  child: IconButton(
                    icon: const Icon(Icons.backspace_outlined,
                        color: AppColors.textSecondary, size: 20),
                    onPressed: _onDeletePressed,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _keypadButton(String label, VoidCallback onTap) {
    return SizedBox(
      width: 60,
      height: 42,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          backgroundColor: AppColors.surfaceLow,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
