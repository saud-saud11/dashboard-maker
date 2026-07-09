import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/html_exporter.dart';

// ══════════════════════════════════════════════════════════════════
//  DATA MODEL
// ══════════════════════════════════════════════════════════════════
class Indicator {
  final String id;
  String name;
  double current;
  double target;
  String unit;
  IndicatorDirection direction;
  IndicatorCategory category;

  Indicator({
    required this.id,
    required this.name,
    required this.current,
    required this.target,
    required this.unit,
    this.direction = IndicatorDirection.higherIsBetter,
    this.category = IndicatorCategory.general,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'current': current,
    'target': target,
    'unit': unit,
    'direction': direction.name,
    'category': category.name,
  };

  factory Indicator.fromJson(Map<String, dynamic> json) => Indicator(
    id: json['id'],
    name: json['name'],
    current: json['current'],
    target: json['target'],
    unit: json['unit'],
    direction: IndicatorDirection.values.firstWhere((e) => e.name == json['direction'], orElse: () => IndicatorDirection.higherIsBetter),
    category: IndicatorCategory.values.firstWhere((e) => e.name == json['category'], orElse: () => IndicatorCategory.general),
  );

  double get pct {
    if (target == 0) return 100;
    if (direction == IndicatorDirection.higherIsBetter) {
      return (current / target * 100).clamp(0, 200);
    } else {
      if (current <= target) return 100;
      return ((target / current) * 100).clamp(0, 100);
    }
  }

  double get achievePct => pct.clamp(0, 100);

  double get gap => (target - current).abs();
  bool get achieved => pct >= 100;
  bool get nearTarget => pct >= 75 && pct < 100;
  bool get needsWork => pct < 75;

  String get statusLabel {
    if (achieved) return 'مُحقَّق';
    if (nearTarget) return 'قريب';
    return 'يحتاج تحسين';
  }

  Color get statusColor {
    if (achieved) return const Color(0xFF10B981);
    if (nearTarget) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  Color get categoryColor => category.color;
}

enum IndicatorDirection { higherIsBetter, lowerIsBetter }
enum IndicatorCategory { general, health, education, environment, economic }

extension IndicatorCategoryExt on IndicatorCategory {
  String get labelAr {
    switch (this) {
      case IndicatorCategory.general: return 'عام';
      case IndicatorCategory.health: return 'صحة';
      case IndicatorCategory.education: return 'تعليم';
      case IndicatorCategory.environment: return 'بيئة';
      case IndicatorCategory.economic: return 'اقتصاد';
    }
  }

  Color get color {
    switch (this) {
      case IndicatorCategory.general: return const Color(0xFF006C5B); // MOH Teal
      case IndicatorCategory.health: return const Color(0xFF10B981); // Emerald
      case IndicatorCategory.education: return const Color(0xFF00ACC1); // Light Teal
      case IndicatorCategory.environment: return const Color(0xFF43A047); // Green
      case IndicatorCategory.economic: return const Color(0xFFD97706); // Amber
    }
  }

  IconData get icon {
    switch (this) {
      case IndicatorCategory.general: return Icons.bar_chart_rounded;
      case IndicatorCategory.health: return Icons.favorite_rounded;
      case IndicatorCategory.education: return Icons.school_rounded;
      case IndicatorCategory.environment: return Icons.eco_rounded;
      case IndicatorCategory.economic: return Icons.payments_rounded;
    }
  }
}

// ══════════════════════════════════════════════════════════════════
//  MAIN PAGE
// ══════════════════════════════════════════════════════════════════
class CreateDashboardPage extends StatefulWidget {
  const CreateDashboardPage({super.key});

  @override
  State<CreateDashboardPage> createState() => _CreateDashboardPageState();
}

class _CreateDashboardPageState extends State<CreateDashboardPage>
    with TickerProviderStateMixin {
  final List<Indicator> _indicators = [];
  late AnimationController _addAnimCtrl;

  // Live input state
  final _dashboardTitleCtrl = TextEditingController(text: 'الداشبورد المخصص');
  final _nameCtrl = TextEditingController();
  final _currentCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  final _unitCtrl = TextEditingController(text: '%');
  IndicatorDirection _dir = IndicatorDirection.higherIsBetter;
  IndicatorCategory _cat = IndicatorCategory.health;

  // View mode for the dashboard grid
  DashViewMode _viewMode = DashViewMode.infographic;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _addAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _nameCtrl.addListener(() => setState(() {}));
    _currentCtrl.addListener(() => setState(() {}));
    _targetCtrl.addListener(() => setState(() {}));
    _unitCtrl.addListener(() => setState(() {}));
    _dashboardTitleCtrl.addListener(_saveData);
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final title = prefs.getString('dash_title');
      if (title != null) _dashboardTitleCtrl.text = title;

      final indsStr = prefs.getString('dash_indicators');
      if (indsStr != null) {
        final List<dynamic> jsonList = jsonDecode(indsStr);
        setState(() {
          _indicators.clear();
          _indicators.addAll(jsonList.map((e) => Indicator.fromJson(e)));
        });
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('dash_title', _dashboardTitleCtrl.text);
      final indsJson = jsonEncode(_indicators.map((e) => e.toJson()).toList());
      await prefs.setString('dash_indicators', indsJson);
    } catch (_) {}
  }

  void _clearData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    setState(() {
      _indicators.clear();
      _dashboardTitleCtrl.text = 'لوحة المؤشرات الصحية';
    });
  }

  @override
  void dispose() {
    _dashboardTitleCtrl.removeListener(_saveData);
    _dashboardTitleCtrl.dispose();
    _addAnimCtrl.dispose();
    _nameCtrl.dispose();
    _currentCtrl.dispose();
    _targetCtrl.dispose();
    _unitCtrl.dispose();
    super.dispose();
  }

  void _applyTemplate(String type) {
    setState(() {
      _indicators.clear();
      if (type == 'financial') {
        _indicators.addAll([
          Indicator(id: 'f1', name: 'الإيرادات', current: 120000, target: 150000, unit: 'ريال', category: IndicatorCategory.economic),
          Indicator(id: 'f2', name: 'المصروفات', current: 80000, target: 70000, unit: 'ريال', direction: IndicatorDirection.lowerIsBetter, category: IndicatorCategory.economic),
          Indicator(id: 'f3', name: 'هامش الربح', current: 25, target: 30, unit: '%', category: IndicatorCategory.economic),
        ]);
      } else if (type == 'hr') {
        _indicators.addAll([
          Indicator(id: 'h1', name: 'رضا الموظفين', current: 85, target: 90, unit: '%', category: IndicatorCategory.general),
          Indicator(id: 'h2', name: 'معدل الدوران', current: 12, target: 10, unit: '%', direction: IndicatorDirection.lowerIsBetter, category: IndicatorCategory.general),
          Indicator(id: 'h3', name: 'ساعات التدريب', current: 15, target: 20, unit: 'ساعة', category: IndicatorCategory.education),
        ]);
      } else if (type == 'health') {
        _indicators.addAll([
          Indicator(id: 'm1', name: 'رضا المرضى', current: 88, target: 95, unit: '%', category: IndicatorCategory.health),
          Indicator(id: 'm2', name: 'وقت الانتظار', current: 25, target: 15, unit: 'دقيقة', direction: IndicatorDirection.lowerIsBetter, category: IndicatorCategory.health),
          Indicator(id: 'm3', name: 'نسبة الإشغال', current: 75, target: 80, unit: '%', category: IndicatorCategory.health),
        ]);
      }
      _saveData();
    });
  }

  Indicator? get _livePreview {
    final cur = double.tryParse(_currentCtrl.text);
    final tgt = double.tryParse(_targetCtrl.text);
    if (cur == null || tgt == null || tgt == 0) return null;
    return Indicator(
      id: 'preview',
      name: _nameCtrl.text.isEmpty ? 'المؤشر' : _nameCtrl.text,
      current: cur,
      target: tgt,
      unit: _unitCtrl.text.isEmpty ? '%' : _unitCtrl.text,
      direction: _dir,
      category: _cat,
    );
  }

  void _addIndicator() {
    final ind = _livePreview;
    if (ind == null) return;
    setState(() {
      _indicators.insert(0, Indicator(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: ind.name,
        current: ind.current,
        target: ind.target,
        unit: ind.unit,
        direction: _dir,
        category: _cat,
      ));
      _nameCtrl.clear();
      _currentCtrl.clear();
      _targetCtrl.clear();
      _unitCtrl.text = '%';
      _saveData();
    });
    _addAnimCtrl.forward(from: 0);
  }

  void _removeIndicator(Indicator ind) {
    setState(() {
      _indicators.remove(ind);
      _saveData();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: CircularProgressIndicator(color: Color(0xFF10B981)),
        ),
      );
    }
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHero(),
          const SizedBox(height: 20),
          _buildTemplatesSection(),
          const SizedBox(height: 24),
          _buildInputPanel(),
          if (_livePreview != null) ...[
            const SizedBox(height: 20),
            _buildLivePreviewSection(_livePreview!),
          ],
          if (_indicators.isNotEmpty) ...[
            const SizedBox(height: 32),
            _buildDashboardSection(),
          ],
        ],
      ),
    );
  }

  // ─── Hero Header ─────────────────────────────────────────────
  Widget _buildHero() {
    final total = _indicators.length;
    final achieved = _indicators.where((e) => e.achieved).length;
    final avg = total == 0 ? 0.0 :
        _indicators.map((e) => e.achievePct).reduce((a, b) => a + b) / total;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF006C5B), Color(0xFF022C22)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x3310B981)),
        boxShadow: const [
          BoxShadow(color: Color(0x30006C5B), blurRadius: 32, offset: Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('منصة مؤشرات وزارة الصحة', style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white,
                )),
                const SizedBox(height: 6),
                Text(
                  'أدخل المعدلات الحالية والأهداف لإنشاء إنفوجرافيك تفاعلي رسمي',
                  style: TextStyle(fontSize: 13, color: Colors.grey[300], height: 1.4),
                ),
                const SizedBox(height: 12),
                if (total > 0)
                  TextButton.icon(
                    onPressed: _clearData,
                    icon: const Icon(Icons.delete_sweep_rounded, color: Colors.white70, size: 18),
                    label: const Text('مسح كافة المؤشرات', style: TextStyle(color: Colors.white70)),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white12,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          if (total > 0) ...[
            Column(
              children: [
                _MiniRing(pct: avg, size: 64, strokeW: 6, label: '${avg.toStringAsFixed(0)}%'),
                const SizedBox(height: 6),
                Text('$achieved/$total مُحقَّق', style: TextStyle(fontSize: 11, color: Colors.grey[300])),
              ],
            ),
            const SizedBox(width: 16),
          ],
          Image.network(
            'https://www.moh.gov.sa/SiteCollectionImages/MOH_Logo_W.png',
            height: 70,
            errorBuilder: (context, error, stackTrace) => const Icon(Icons.health_and_safety_rounded, size: 50, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  // ─── Templates Section ───────────────────────────────────────
  Widget _buildTemplatesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('القوالب السريعة:', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _TemplateBtn(title: 'لوحة مبيعات ومالية', icon: Icons.attach_money_rounded, onTap: () => _applyTemplate('financial')),
              const SizedBox(width: 8),
              _TemplateBtn(title: 'لوحة موارد بشرية', icon: Icons.people_outline_rounded, onTap: () => _applyTemplate('hr')),
              const SizedBox(width: 8),
              _TemplateBtn(title: 'لوحة صحية', icon: Icons.health_and_safety_outlined, onTap: () => _applyTemplate('health')),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Input Panel ──────────────────────────────────────────────
  Widget _buildInputPanel() {
    final preview = _livePreview;
    final hasData = preview != null;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF064E3B), // MOH dark green surface
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasData ? const Color(0xFF10B981) : const Color(0x1AFFFFFF),
          width: hasData ? 1.5 : 1,
        ),
        boxShadow: hasData ? const [
          BoxShadow(color: Color(0x3010B981), blurRadius: 20, offset: Offset(0, 6)),
        ] : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Panel header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF006C5B), Color(0xFF10B981)]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add_chart_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                const Text('أضف مؤشراً جديداً', style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white,
                )),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Row 1: Name + Unit
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(flex: 3, child: _InputField(
                  controller: _nameCtrl,
                  label: 'اسم المؤشر',
                  icon: Icons.label_outline_rounded,
                )),
                const SizedBox(width: 12),
                Expanded(flex: 1, child: _InputField(
                  controller: _unitCtrl,
                  label: 'الوحدة',
                  icon: Icons.straighten_rounded,
                )),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Row 2: Current + Target with visual connector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(child: _InputField(
                  controller: _currentCtrl,
                  label: 'المعدل الحالي',
                  icon: Icons.speed_rounded,
                  color: _cat.color,
                  isNumeric: true,
                )),
                const SizedBox(width: 8),
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF022C22),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0x1AFFFFFF)),
                      ),
                      child: const Text('↔', style: TextStyle(color: Colors.white70, fontSize: 18)),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Expanded(child: _InputField(
                  controller: _targetCtrl,
                  label: 'الهدف',
                  icon: Icons.flag_rounded,
                  color: const Color(0xFF10B981),
                  isNumeric: true,
                )),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Category + Direction
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                // Category
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('الفئة', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: IndicatorCategory.values.map((c) {
                            final sel = c == _cat;
                            return GestureDetector(
                              onTap: () => setState(() => _cat = c),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: sel ? c.color.withAlpha(50) : const Color(0x1AFFFFFF),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: sel ? c.color : Colors.transparent),
                                ),
                                child: Text(
                                  c.labelAr,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: sel ? c.color : Colors.white60,
                                    fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Direction toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _DirChip(
                  label: '↑ الأعلى أفضل',
                  selected: _dir == IndicatorDirection.higherIsBetter,
                  color: const Color(0xFF10B981),
                  onTap: () => setState(() => _dir = IndicatorDirection.higherIsBetter),
                ),
                const SizedBox(width: 10),
                _DirChip(
                  label: '↓ الأقل أفضل',
                  selected: _dir == IndicatorDirection.lowerIsBetter,
                  color: const Color(0xFFEF4444),
                  onTap: () => setState(() => _dir = IndicatorDirection.lowerIsBetter),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Add Button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: SizedBox(
              width: double.infinity,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  gradient: hasData
                      ? const LinearGradient(colors: [Color(0xFF006C5B), Color(0xFF10B981)])
                      : null,
                  color: hasData ? null : const Color(0x1AFFFFFF),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: hasData ? const [
                    BoxShadow(color: Color(0x3010B981), blurRadius: 16, offset: Offset(0, 4)),
                  ] : null,
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: hasData ? _addIndicator : null,
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_graph_rounded,
                            color: hasData ? Colors.white : Colors.white30, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            hasData ? 'إنشاء الإنفوجرافيك' : 'أدخل البيانات أولاً',
                            style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold,
                              color: hasData ? Colors.white : Colors.white30,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Live Preview Section ─────────────────────────────────────
  Widget _buildLivePreviewSection(Indicator ind) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const _PulseDot(),
            const SizedBox(width: 8),
            Text(
              'معاينة حية — تتحدث تلقائياً',
              style: TextStyle(fontSize: 13, color: Colors.grey[400], fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 3 live preview cards side-by-side
        LayoutBuilder(builder: (_, constraints) {
          final isWide = constraints.maxWidth > 600;
          final cards = [
            _buildGaugePreview(ind),
            _buildThermometerPreview(ind),
            _buildKpiPreview(ind),
          ];
          return isWide
              ? Row(children: cards
                  .map((c) => Expanded(child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: c,
                  )))
                  .toList())
              : Column(children: [
                  cards[0],
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: cards[1]),
                    const SizedBox(width: 12),
                    Expanded(child: cards[2]),
                  ]),
                ]);
        }),
      ],
    );
  }

  Widget _buildGaugePreview(Indicator ind) {
    return _GaugeCard(indicator: ind, live: true);
  }

  Widget _buildThermometerPreview(Indicator ind) {
    return _ThermometerCard(indicator: ind, live: true);
  }

  Widget _buildKpiPreview(Indicator ind) {
    return _KpiCard(indicator: ind, live: true);
  }

  // ─── Full Dashboard Section ───────────────────────────────────
  Widget _buildDashboardSection() {
    final total = _indicators.length;
    final achieved = _indicators.where((e) => e.achieved).length;
    final avg = _indicators.map((e) => e.achievePct).reduce((a, b) => a + b) / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Dashboard Title Input
        TextField(
          controller: _dashboardTitleCtrl,
          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'عنوان الداشبورد...',
            hintStyle: TextStyle(color: Colors.white24),
            prefixIcon: Icon(Icons.edit, color: Colors.white38, size: 20),
          ),
          onChanged: (_) => setState((){}),
        ),
        const SizedBox(height: 12),
        // Indicator management chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _indicators.map((ind) => Tooltip(
            message: 'انقر للتعديل، أو اضغط × للحذف',
            child: InputChip(
              label: Text(ind.name, style: const TextStyle(fontSize: 12, color: Colors.white)),
              avatar: const Icon(Icons.edit, size: 14, color: Colors.white70),
              onPressed: () {
                setState(() {
                  _nameCtrl.text = ind.name;
                  _currentCtrl.text = ind.current.toString();
                  _targetCtrl.text = ind.target.toString();
                  _unitCtrl.text = ind.unit;
                  _dir = ind.direction;
                  _cat = ind.category;
                  _removeIndicator(ind);
                });
              },
              deleteIcon: const Icon(Icons.close, size: 16, color: Colors.white70),
              onDeleted: () {
                _removeIndicator(ind);
              },
              backgroundColor: ind.categoryColor.withAlpha(40),
              side: BorderSide(color: ind.categoryColor.withAlpha(100)),
            ),
          )).toList(),
        ),
        const SizedBox(height: 24),
        // Mode toggle bar
        _buildViewModeBar(),
        const SizedBox(height: 20),

        // View content
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
          child: _buildCurrentView(),
        ),

        // Overall Summary Infographic
        const SizedBox(height: 28),
        _buildSummaryInfographic(avg, achieved, total),
        const SizedBox(height: 32),
        
        // Export Button
        Center(
          child: ElevatedButton.icon(
            onPressed: () {
              DashboardHtmlExporter.exportToHtml(_indicators, _dashboardTitleCtrl.text);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم تصدير الداشبورد بنجاح!'), backgroundColor: Color(0xFF10B981)),
              );
            },
            icon: const Icon(Icons.download_rounded),
            label: const Text('تصدير الداشبورد كـ HTML', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF047857), // Emerald 700
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              elevation: 8,
              shadowColor: const Color(0x60047857),
            ),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildViewModeBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: DashViewMode.values.map((mode) {
          final sel = mode == _viewMode;
          return GestureDetector(
            onTap: () => setState(() => _viewMode = mode),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(left: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: sel ? const Color(0xFF10B981) : const Color(0xFF064E3B),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: sel ? const Color(0xFF10B981) : const Color(0x1AFFFFFF),
                ),
                boxShadow: sel ? const [
                  BoxShadow(color: Color(0x3010B981), blurRadius: 12, offset: Offset(0, 4)),
                ] : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(mode.label, style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: sel ? Colors.white : Colors.white60,
                  )),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCurrentView() {
    switch (_viewMode) {
      case DashViewMode.infographic:
        return _buildInfographicView();
      case DashViewMode.gauge:
        return _buildGaugeView();
      case DashViewMode.comparison:
        return _buildComparisonView();
      case DashViewMode.trafficLight:
        return _buildTrafficLightView();
      case DashViewMode.thermometer:
        return _buildThermometerView();
    }
  }

  // ── Infographic View (KPI Cards) ──
  Widget _buildInfographicView() {
    return Column(
      key: const ValueKey('infographic'),
      children: _indicators.map((ind) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: _FullKpiCard(indicator: ind, onDelete: () => _removeIndicator(ind)),
      )).toList(),
    );
  }

  // ── Gauge View ──
  Widget _buildGaugeView() {
    return GridView.builder(
      key: const ValueKey('gauge'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 240, mainAxisSpacing: 16, crossAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: _indicators.length,
      itemBuilder: (_, i) => _GaugeCard(indicator: _indicators[i]),
    );
  }

  // ── Comparison Bars View ──
  Widget _buildComparisonView() {
    return Column(
      key: const ValueKey('comparison'),
      children: _indicators.map((ind) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: _ComparisonBar(indicator: ind),
      )).toList(),
    );
  }

  // ── Traffic Light View ──
  Widget _buildTrafficLightView() {
    return GridView.builder(
      key: const ValueKey('traffic'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200, mainAxisSpacing: 16, crossAxisSpacing: 16,
        childAspectRatio: 0.7,
      ),
      itemCount: _indicators.length,
      itemBuilder: (_, i) => _TrafficLightCard(indicator: _indicators[i]),
    );
  }

  // ── Thermometer View ──
  Widget _buildThermometerView() {
    return GridView.builder(
      key: const ValueKey('therm'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180, mainAxisSpacing: 16, crossAxisSpacing: 16,
        childAspectRatio: 0.55,
      ),
      itemCount: _indicators.length,
      itemBuilder: (_, i) => _ThermometerCard(indicator: _indicators[i]),
    );
  }

  // ── Summary Infographic ──
  Widget _buildSummaryInfographic(double avg, int achieved, int total) {
    final onTrack = _indicators.where((e) => e.nearTarget).length;
    final needsWork = _indicators.where((e) => e.needsWork).length;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF006C5B), Color(0xFF022C22)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x3310B981)),
      ),
      child: Column(
        children: [
          // Top strip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0x40006C5B), Color(0x1010B981)]),
              borderRadius: BorderRadius.vertical(top: Radius.circular(23)),
            ),
            child: Row(
              children: [
                const Icon(Icons.stars_rounded, color: Color(0xFFD97706), size: 24),
                const SizedBox(width: 12),
                const Text('ملخص الأداء العام', style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white,
                )),
                const Spacer(),
                Text(
                  '$total مؤشر',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Big ring
                _MiniRing(pct: avg, size: 110, strokeW: 10, label: '${avg.toStringAsFixed(0)}%', fontSize: 20),
                const SizedBox(width: 24),
                // Stats
                Expanded(
                  child: Column(
                    children: [
                      _StatRow(icon: Icons.check_circle_outline_rounded, label: 'مُحقَّق', value: achieved, color: const Color(0xFF10B981)),
                      const SizedBox(height: 10),
                      _StatRow(icon: Icons.pending_outlined, label: 'قريب من الهدف', value: onTrack, color: const Color(0xFFF59E0B)),
                      const SizedBox(height: 10),
                      _StatRow(icon: Icons.error_outline_rounded, label: 'يحتاج تحسين', value: needsWork, color: const Color(0xFFEF4444)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Progress strip at the bottom
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('الأداء الكلي', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                    Text(
                      '${avg.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold,
                        color: avg >= 75 ? const Color(0xFF10B981) : avg >= 50 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _AnimatedProgressBar(pct: avg / 100),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  ENUMS
// ══════════════════════════════════════════════════════════════════
enum DashViewMode {
  infographic, gauge, comparison, trafficLight, thermometer;

  String get label {
    switch (this) {
      case DashViewMode.infographic: return 'إنفوجرافيك';
      case DashViewMode.gauge: return 'مقياس دائري';
      case DashViewMode.comparison: return 'مقارنة';
      case DashViewMode.trafficLight: return 'إشارة ضوء';
      case DashViewMode.thermometer: return 'ترمومتر';
    }
  }

  String get emoji {
    switch (this) {
      case DashViewMode.infographic: return '📋';
      case DashViewMode.gauge: return '🎯';
      case DashViewMode.comparison: return '📊';
      case DashViewMode.trafficLight: return '🚦';
      case DashViewMode.thermometer: return '🌡️';
    }
  }
}

// ══════════════════════════════════════════════════════════════════
//  REUSABLE WIDGETS
// ══════════════════════════════════════════════════════════════════

// ─── Gauge Card ──────────────────────────────────────────────────
class _GaugeCard extends StatefulWidget {
  final Indicator indicator;
  final bool live;
  const _GaugeCard({required this.indicator, this.live = false});

  @override
  State<_GaugeCard> createState() => _GaugeCardState();
}

class _GaugeCardState extends State<_GaugeCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _anim = Tween<double>(begin: 0, end: widget.indicator.achievePct / 100)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(_GaugeCard old) {
    super.didUpdateWidget(old);
    _anim = Tween<double>(
      begin: _anim.value,
      end: widget.indicator.achievePct / 100,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward(from: 0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ind = widget.indicator;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final v = _anim.value;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF064E3B),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0x1AFFFFFF)),
            boxShadow: widget.live ? [
              BoxShadow(color: ind.category.color.withAlpha(60), blurRadius: 16, offset: const Offset(0, 4)),
            ] : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Speedometer
              SizedBox(
                height: 120,
                child: CustomPaint(
                  painter: _SpeedometerPainter(value: v, color: ind.statusColor, catColor: ind.categoryColor),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${(v * 100).toStringAsFixed(0)}%',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: ind.statusColor),
                        ),
                        Text(ind.statusLabel, style: TextStyle(fontSize: 10, color: ind.statusColor)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                ind.name,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${ind.current}', style: TextStyle(fontSize: 12, color: ind.categoryColor, fontWeight: FontWeight.bold)),
                  Text(' / ${ind.target} ${ind.unit}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Speedometer CustomPainter ───────────────────────────────────
class _SpeedometerPainter extends CustomPainter {
  final double value;
  final Color color;
  final Color catColor;
  _SpeedometerPainter({required this.value, required this.color, required this.catColor});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.75;
    final r = size.width * 0.42;

    const startAngle = math.pi * 0.75;
    const sweepMax = math.pi * 1.5;

    final bgPaint = Paint()
      ..color = const Color(0xFF334155)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    // Track marks
    for (var i = 0; i <= 10; i++) {
      final angle = startAngle + sweepMax * i / 10;
      final inner = r - 18;
      final outer = r - 8;
      final p1 = Offset(cx + inner * math.cos(angle), cy + inner * math.sin(angle));
      final p2 = Offset(cx + outer * math.cos(angle), cy + outer * math.sin(angle));
      canvas.drawLine(p1, p2, Paint()..color = const Color(0xFF475569)..strokeWidth = 1.5);
    }

    // Background arc
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      startAngle, sweepMax, false, bgPaint,
    );

    // Gradient effect (segmented arcs)
    final colors = [const Color(0xFFEF4444), const Color(0xFFF59E0B), const Color(0xFF10B981)];
    for (var i = 0; i < 3; i++) {
      final segPaint = Paint()
        ..color = colors[i].withAlpha(80)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r - 20),
        startAngle + sweepMax * i / 3,
        sweepMax / 3,
        false, segPaint,
      );
    }

    // Value arc
    if (value > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        startAngle, sweepMax * value.clamp(0, 1), false, fgPaint,
      );
    }

    // Needle
    final needleAngle = startAngle + sweepMax * value.clamp(0, 1);
    final needleEnd = Offset(cx + (r - 28) * math.cos(needleAngle), cy + (r - 28) * math.sin(needleAngle));
    canvas.drawLine(Offset(cx, cy), needleEnd, Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round);

    // Center dot
    canvas.drawCircle(Offset(cx, cy), 6, Paint()..color = catColor);
    canvas.drawCircle(Offset(cx, cy), 3, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_SpeedometerPainter old) => old.value != value || old.color != color;
}

// ─── Thermometer Card ────────────────────────────────────────────
class _ThermometerCard extends StatefulWidget {
  final Indicator indicator;
  final bool live;
  const _ThermometerCard({required this.indicator, this.live = false});

  @override
  State<_ThermometerCard> createState() => _ThermometerCardState();
}

class _ThermometerCardState extends State<_ThermometerCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _anim = Tween<double>(begin: 0, end: widget.indicator.achievePct / 100)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(_ThermometerCard old) {
    super.didUpdateWidget(old);
    _anim = Tween<double>(begin: _anim.value, end: widget.indicator.achievePct / 100)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward(from: 0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ind = widget.indicator;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final v = _anim.value;
        final Color col = ind.statusColor;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF064E3B),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0x1AFFFFFF)),
          ),
          child: Column(
            children: [
              Text(
                ind.name,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              // Thermometer body
              SizedBox(
                width: 36,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    // tube
                    Container(
                      height: 130,
                      width: 18,
                      decoration: BoxDecoration(
                        color: const Color(0xFF334155),
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    // fill
                    ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: Container(
                        height: 130 * v,
                        width: 18,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [col, col.withAlpha(180)],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                    ),
                    // Bulb
                    Positioned(
                      bottom: -8,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: col,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: col.withAlpha(100), blurRadius: 8)],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '${(v * 100).toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: col),
              ),
              Text(
                '${ind.current} / ${ind.target} ${ind.unit}',
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
              const SizedBox(height: 4),
              Text(ind.statusLabel, style: TextStyle(fontSize: 10, color: col, fontWeight: FontWeight.bold)),
            ],
          ),
        );
      },
    );
  }
}

// ─── KPI Card (compact, for live preview) ───────────────────────
class _KpiCard extends StatelessWidget {
  final Indicator indicator;
  final bool live;
  const _KpiCard({required this.indicator, this.live = false});

  @override
  Widget build(BuildContext context) {
    final ind = indicator;
    final col = ind.statusColor;
    final catCol = ind.categoryColor;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: col.withAlpha(80)),
        boxShadow: live ? [BoxShadow(color: col.withAlpha(50), blurRadius: 12, offset: const Offset(0, 4))] : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top: emoji + status
          Row(
            children: [
              Icon(ind.category.icon, color: col, size: 22),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: col.withAlpha(40),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: col.withAlpha(80)),
                ),
                child: Text(ind.statusLabel, style: TextStyle(fontSize: 10, color: col, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${ind.achievePct.toStringAsFixed(0)}%',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: catCol),
          ),
          Text(ind.name, style: const TextStyle(fontSize: 12, color: Colors.white70), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 10),
          // Mini progress
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ind.achievePct / 100,
              backgroundColor: const Color(0xFF334155),
              valueColor: AlwaysStoppedAnimation<Color>(col),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _MicroValue(label: 'حالي', value: '${ind.current}', color: catCol),
              const Spacer(),
              const Text('→', style: TextStyle(color: Colors.white24)),
              const Spacer(),
              _MicroValue(label: 'هدف', value: '${ind.target}', color: const Color(0xFF10B981)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Full KPI Card (for infographic view) ────────────────────────
class _FullKpiCard extends StatefulWidget {
  final Indicator indicator;
  final VoidCallback onDelete;
  const _FullKpiCard({required this.indicator, required this.onDelete});

  @override
  State<_FullKpiCard> createState() => _FullKpiCardState();
}

class _FullKpiCardState extends State<_FullKpiCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _prog;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _prog = Tween<double>(begin: 0, end: widget.indicator.achievePct / 100)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ind = widget.indicator;
    final col = ind.statusColor;
    final catCol = ind.categoryColor;

    return AnimatedBuilder(
      animation: _prog,
      builder: (_, __) {
        final v = _prog.value;
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF064E3B),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0x1AFFFFFF)),
          ),
          child: Column(
            children: [
              // Header strip with gradient
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [catCol.withAlpha(50), const Color(0x001E293B)],
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
                ),
                child: Row(
                  children: [
                    Icon(ind.category.icon, color: catCol, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ind.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                          Text(ind.category.labelAr, style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: col.withAlpha(40),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: col.withAlpha(80)),
                      ),
                      child: Text(ind.statusLabel, style: TextStyle(fontSize: 12, color: col, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16),
                      onPressed: widget.onDelete,
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0x1AEF4444),
                        foregroundColor: const Color(0xFFEF4444),
                        minimumSize: const Size(32, 32),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ),

              // Body
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Left: Mini ring + percentage
                    _MiniRing(pct: v * 100, size: 80, strokeW: 7, label: '${(v * 100).toStringAsFixed(0)}%', color: col),
                    const SizedBox(width: 20),
                    // Right: Stats
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: _StatBox(
                                label: 'الوضع الحالي',
                                value: '${ind.current} ${ind.unit}',
                                color: catCol,
                              )),
                              const SizedBox(width: 10),
                              Expanded(child: _StatBox(
                                label: 'الهدف',
                                value: '${ind.target} ${ind.unit}',
                                color: const Color(0xFF10B981),
                              )),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _StatBox(
                            label: 'الفجوة',
                            value: '${ind.gap.toStringAsFixed(1)} ${ind.unit}',
                            color: col,
                            fullWidth: true,
                          ),
                          const SizedBox(height: 12),
                          // Full progress bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: v,
                              backgroundColor: const Color(0xFF334155),
                              valueColor: AlwaysStoppedAnimation<Color>(col),
                              minHeight: 10,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('0', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                              Text('${(v * 100).toStringAsFixed(1)}% من الهدف',
                                style: TextStyle(fontSize: 10, color: col, fontWeight: FontWeight.bold)),
                              Text('100%', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Comparison Bar ───────────────────────────────────────────────
class _ComparisonBar extends StatefulWidget {
  final Indicator indicator;
  const _ComparisonBar({required this.indicator});

  @override
  State<_ComparisonBar> createState() => _ComparisonBarState();
}

class _ComparisonBarState extends State<_ComparisonBar> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _anim = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ind = widget.indicator;
    final catCol = ind.categoryColor;
    final statusCol = ind.statusColor;
    final maxVal = ind.current > ind.target ? ind.current : ind.target;

    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final v = _anim.value;
        final curW = maxVal == 0 ? 0.0 : (ind.current / maxVal).clamp(0.0, 1.0) * v;
        final tgtW = maxVal == 0 ? 0.0 : (ind.target / maxVal).clamp(0.0, 1.0);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF064E3B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x1AFFFFFF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(ind.category.icon, color: ind.categoryColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(ind.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusCol.withAlpha(40),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${ind.achievePct.toStringAsFixed(0)}%', style: TextStyle(fontSize: 12, color: statusCol, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Current bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('الحالي', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                      Text('${ind.current} ${ind.unit}', style: const TextStyle(fontSize: 12, color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      children: [
                        Container(height: 22, color: const Color(0xFF334155)),
                        FractionallySizedBox(
                          widthFactor: curW,
                          child: Container(
                            height: 22,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF006C5B), Color(0xFF004D40)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Target bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('الهدف المستهدف', style: TextStyle(fontSize: 11, color: Color(0xFFD97706))),
                      Text('${ind.target} ${ind.unit}', style: const TextStyle(fontSize: 12, color: Color(0xFFD97706), fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      children: [
                        Container(height: 22, color: const Color(0xFF334155)),
                        FractionallySizedBox(
                          widthFactor: tgtW,
                          child: Container(
                            height: 22,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFD97706), Color(0xFFB45309)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (ind.gap > 0) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.arrow_upward_rounded, size: 14, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 4),
                    Text(
                      'الفجوة: ${ind.gap.toStringAsFixed(1)} ${ind.unit}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFFF59E0B), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ─── Traffic Light Card ───────────────────────────────────────────
class _TrafficLightCard extends StatefulWidget {
  final Indicator indicator;
  const _TrafficLightCard({required this.indicator});

  @override
  State<_TrafficLightCard> createState() => _TrafficLightCardState();
}

class _TrafficLightCardState extends State<_TrafficLightCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _glow = Tween<double>(begin: 0.3, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ind = widget.indicator;
    final isGreen = ind.achieved;
    final isYellow = ind.nearTarget;

    return AnimatedBuilder(
      animation: _glow,
      builder: (_, __) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF064E3B),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0x1AFFFFFF)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(ind.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 12),
              // Traffic light housing
              Container(
                width: 52,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: const Color(0xFF334155), width: 2),
                ),
                child: Column(
                  children: [
                    // Red
                    _TrafficBulb(
                      color: const Color(0xFFEF4444),
                      active: !isGreen && !isYellow,
                      glowFactor: _glow.value,
                    ),
                    const SizedBox(height: 6),
                    // Yellow
                    _TrafficBulb(
                      color: const Color(0xFFF59E0B),
                      active: isYellow,
                      glowFactor: _glow.value,
                    ),
                    const SizedBox(height: 6),
                    // Green
                    _TrafficBulb(
                      color: const Color(0xFF10B981),
                      active: isGreen,
                      glowFactor: _glow.value,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${ind.achievePct.toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ind.statusColor),
              ),
              Text(
                '${ind.current}/${ind.target}',
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TrafficBulb extends StatelessWidget {
  final Color color;
  final bool active;
  final double glowFactor;
  const _TrafficBulb({required this.color, required this.active, required this.glowFactor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? color : color.withAlpha(40),
        boxShadow: active ? [
          BoxShadow(color: color.withAlpha((glowFactor * 180).toInt()), blurRadius: 12 * glowFactor),
        ] : null,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  SHARED SMALL WIDGETS
// ══════════════════════════════════════════════════════════════════

class _MiniRing extends StatelessWidget {
  final double pct;
  final double size;
  final double strokeW;
  final String label;
  final Color? color;
  final double? fontSize;

  const _MiniRing({
    required this.pct,
    required this.size,
    required this.strokeW,
    required this.label,
    this.color,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    Color ringColor;
    if (pct >= 75) ringColor = const Color(0xFF10B981);
    else if (pct >= 50) ringColor = const Color(0xFFF59E0B);
    else ringColor = const Color(0xFFEF4444);

    ringColor = color ?? ringColor;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(pct: pct / 100, color: ringColor, strokeW: strokeW),
          ),
          Text(label, style: TextStyle(
            fontSize: fontSize ?? (size * 0.22),
            fontWeight: FontWeight.bold,
            color: ringColor,
          )),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double pct;
  final Color color;
  final double strokeW;
  _RingPainter({required this.pct, required this.color, required this.strokeW});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - strokeW / 2;
    final bg = Paint()..color = const Color(0xFF334155)..style = PaintingStyle.stroke..strokeWidth = strokeW;
    final fg = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = strokeW..strokeCap = StrokeCap.round;
    canvas.drawCircle(c, r, bg);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2, 2 * math.pi * pct.clamp(0, 1), false, fg);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.pct != pct || old.color != color;
}

class _AnimatedProgressBar extends StatelessWidget {
  final double pct;
  const _AnimatedProgressBar({required this.pct});

  @override
  Widget build(BuildContext context) {
    Color col;
    if (pct >= 0.75) col = const Color(0xFF10B981);
    else if (pct >= 0.5) col = const Color(0xFFF59E0B);
    else col = const Color(0xFFEF4444);

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: LinearProgressIndicator(
        value: pct.clamp(0, 1),
        backgroundColor: const Color(0xFF334155),
        valueColor: AlwaysStoppedAnimation<Color>(col),
        minHeight: 10,
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final Color color;
  const _StatRow({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[300]))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: color.withAlpha(40),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withAlpha(80)),
          ),
          child: Text('$value', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool fullWidth;
  const _StatBox({required this.label, required this.value, required this.color, this.fullWidth = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

class _MicroValue extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MicroValue({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[500])),
        Text(value, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final Color? color;
  final bool isNumeric;

  const _InputField({
    required this.controller,
    required this.label,
    required this.icon,
    this.color,
    this.isNumeric = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFF6366F1);
    return TextFormField(
      controller: controller,
      keyboardType: isNumeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      inputFormatters: isNumeric ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))] : null,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
        prefixIcon: Icon(icon, color: c, size: 16),
        filled: true,
        fillColor: const Color(0x0FFFFFFF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0x33FFFFFF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0x33FFFFFF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}

class _DirChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _DirChip({required this.label, required this.selected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withAlpha(40) : const Color(0x1AFFFFFF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : Colors.transparent),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 12,
          color: selected ? color : Colors.white60,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        )),
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.6, end: 1.2)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: Color(0xFF10B981),
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Color(0x5010B981), blurRadius: 6)],
        ),
      ),
    );
  }
}

class _TemplateBtn extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _TemplateBtn({required this.title, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF064E3B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x1AFFFFFF)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: const Color(0xFF10B981)),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
