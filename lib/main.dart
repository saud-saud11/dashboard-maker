import 'package:flutter/material.dart';
import 'pages/create_dashboard_page.dart';

void main() {
  runApp(const DashboardMakerApp());
}

class DashboardMakerApp extends StatelessWidget {
  const DashboardMakerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dashboard Maker',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0B0F19),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6366F1), // Indigo
          secondary: Color(0xFF06B6D4), // Cyan
          surface: Color(0xFF1E293B), // Slate 800
        ),
      ),
      // Set localization support for Arabic (RTL)
      locale: const Locale('ar', 'AE'),
      home: const DashboardPortalPage(),
    );
  }
}

class DashboardPortalPage extends StatefulWidget {
  const DashboardPortalPage({super.key});

  @override
  State<DashboardPortalPage> createState() => _DashboardPortalPageState();
}

class _DashboardPortalPageState extends State<DashboardPortalPage> {
  String? _selectedAction;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Stack(
          children: [
            // Background subtle gradient and ambient glow
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      Color(0xFF1E1B4B), // Very deep purple/indigo
                      Color(0xFF0F172A), // Slate 900
                      Color(0xFF090D16), // Midnight
                    ],
                    center: Alignment(0, -0.5),
                    radius: 1.5,
                  ),
                ),
              ),
            ),
            // Floating ambient colored circles for glassmorphism background glow
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x266366F1),
                ),
              ),
            ),
            Positioned(
              bottom: -50,
              left: -50,
              child: Container(
                width: 250,
                height: 250,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x2606B6D4),
                ),
              ),
            ),
            
            // Content
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.0, 0.05),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          )),
                          child: child,
                        ),
                      );
                    },
                    child: _selectedAction == null
                        ? _buildPortalHome()
                        : _buildSubPage(_selectedAction!),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPortalHome() {
    final isDesktop = MediaQuery.of(context).size.width > 768;

    return Container(
      key: const ValueKey('portal_home'),
      constraints: const BoxConstraints(maxWidth: 900),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Header Logo/Branding
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF06B6D4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0x666366F1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.dashboard_customize_rounded,
              size: 48,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          
          // App Title
          const Text(
            'داشبورد ميكر',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'منصتك الذكية لبناء وعرض لوحات تحكم تفاعلية متكاملة',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[400],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 48),

          // Portal Choices Grid
          isDesktop
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(child: _buildChoiceCard(
                      title: 'إنشاء داشبورد',
                      subtitle: 'ابدأ بتصميم لوحة تحكم جديدة مخصصة، وأضف المؤشرات والرسوم البيانية وتفاعل مع بياناتك.',
                      icon: Icons.add_rounded,
                      gradientColors: [const Color(0xFF6366F1), const Color(0xFF4F46E5)],
                      glowColor: const Color(0xFF6366F1),
                      onTap: () => setState(() => _selectedAction = 'create'),
                    )),
                    const SizedBox(width: 24),
                    Expanded(child: _buildChoiceCard(
                      title: 'عرض داشبورد',
                      subtitle: 'تصفح واستعرض لوحات التحكم المحفوظة، وتابع البيانات الحية والمؤشرات الإحصائية في مكان واحد.',
                      icon: Icons.analytics_rounded,
                      gradientColors: [const Color(0xFF06B6D4), const Color(0xFF0891B2)],
                      glowColor: const Color(0xFF06B6D4),
                      onTap: () => setState(() => _selectedAction = 'view'),
                    )),
                  ],
                )
              : Column(
                  children: [
                    _buildChoiceCard(
                      title: 'إنشاء داشبورد',
                      subtitle: 'ابدأ بتصميم لوحة تحكم جديدة مخصصة، وأضف المؤشرات والرسوم البيانية وتفاعل مع بياناتك.',
                      icon: Icons.add_rounded,
                      gradientColors: [const Color(0xFF6366F1), const Color(0xFF4F46E5)],
                      glowColor: const Color(0xFF6366F1),
                      onTap: () => setState(() => _selectedAction = 'create'),
                    ),
                    const SizedBox(height: 20),
                    _buildChoiceCard(
                      title: 'عرض داشبورد',
                      subtitle: 'تصفح واستعرض لوحات التحكم المحفوظة، وتابع البيانات الحية والمؤشرات الإحصائية في مكان واحد.',
                      icon: Icons.analytics_rounded,
                      gradientColors: [const Color(0xFF06B6D4), const Color(0xFF0891B2)],
                      glowColor: const Color(0xFF06B6D4),
                      onTap: () => setState(() => _selectedAction = 'view'),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildChoiceCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradientColors,
    required Color glowColor,
    required VoidCallback onTap,
  }) {
    return PortalChoiceCard(
      title: title,
      subtitle: subtitle,
      icon: icon,
      gradientColors: gradientColors,
      glowColor: glowColor,
      onTap: onTap,
    );
  }

  Widget _buildSubPage(String type) {
    final isCreate = type == 'create';

    // If create mode, render the full CreateDashboardPage
    if (isCreate) {
      return Container(
        key: const ValueKey('page_create'),
        constraints: const BoxConstraints(maxWidth: 960),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back button row
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  onPressed: () => setState(() => _selectedAction = null),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0x0DFFFFFF),
                    hoverColor: const Color(0x1AFFFFFF),
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.add_chart_rounded, color: Color(0xFF6366F1), size: 24),
                const SizedBox(width: 10),
                const Text(
                  'إنشاء داشبورد',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const CreateDashboardPage(),
          ],
        ),
      );
    }

    // View mode placeholder
    return Container(
      key: const ValueKey('page_view'),
      constraints: const BoxConstraints(maxWidth: 800),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xCC1E293B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x1AFFFFFF)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () => setState(() => _selectedAction = null),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0x0DFFFFFF),
                  hoverColor: const Color(0x1AFFFFFF),
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.space_dashboard_rounded, color: Color(0xFF06B6D4), size: 24),
              const SizedBox(width: 10),
              const Text('عرض لوحات التحكم',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 40),
          const Icon(Icons.folder_open_rounded, size: 64, color: Colors.white24),
          const SizedBox(height: 16),
          const Text('قريباً — استعراض الداشبوردات المحفوظة',
            style: TextStyle(fontSize: 16, color: Colors.white70), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class PortalChoiceCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradientColors;
  final Color glowColor;
  final VoidCallback onTap;

  const PortalChoiceCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradientColors,
    required this.glowColor,
    required this.onTap,
  });

  @override
  State<PortalChoiceCard> createState() => _PortalChoiceCardState();
}

class _PortalChoiceCardState extends State<PortalChoiceCard> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHover(bool isHovered) {
    setState(() {
      _isHovered = isHovered;
    });
    if (isHovered) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _onHover(true),
      onExit: (_) => _onHover(false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isHovered ? widget.glowColor : const Color(0x14FFFFFF),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: _isHovered
                      ? widget.glowColor.withAlpha(64)
                      : const Color(0x26000000),
                  blurRadius: _isHovered ? 25 : 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon with gradient background
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: widget.gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    widget.icon,
                    size: 32,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                // Title
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                // Subtitle
                Text(
                  widget.subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[400],
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                // "Go" indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: _isHovered ? widget.glowColor : const Color(0x0DFFFFFF),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'البدء',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: _isHovered ? Colors.white : Colors.white70,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: _isHovered ? Colors.white : Colors.white70,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

