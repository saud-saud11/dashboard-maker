import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import '../pages/create_dashboard_page.dart';

class DashboardHtmlExporter {
  static void exportToHtml(List<Indicator> indicators, String dashboardTitle) {
    final html_content = _buildHtml(indicators, dashboardTitle);
    final bytes = utf8.encode(html_content);
    final blob = html.Blob([bytes], 'text/html');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', 'dashboard_${DateTime.now().millisecondsSinceEpoch}.html')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  static String _colorToHex(int color) {
    return '#${color.toRadixString(16).padLeft(8, '0').substring(2)}';
  }

  static String _indicatorColorHex(IndicatorCategory cat) {
    switch (cat) {
      case IndicatorCategory.general: return '#6366F1';
      case IndicatorCategory.health:     return '#EC4899';
      case IndicatorCategory.economic:    return '#F59E0B';
      case IndicatorCategory.environment:      return '#EF4444';
      case IndicatorCategory.education:   return '#06B6D4';
    }
  }

  static String _statusColorHex(Indicator e) {
    final pct = e.achievePct;
    if (pct >= 100) return '#10B981';
    if (pct >= 75)  return '#06B6D4';
    if (pct >= 50)  return '#F59E0B';
    return '#EF4444';
  }

  static String _categoryIcon(IndicatorCategory cat) {
    switch (cat) {
      case IndicatorCategory.general: return 'bar_chart';
      case IndicatorCategory.health:     return 'favorite';
      case IndicatorCategory.economic:    return 'payments';
      case IndicatorCategory.environment:      return 'eco';
      case IndicatorCategory.education:   return 'school';
    }
  }

  // ─────────────────────────────────────────────
  //  SVG Bar Chart
  // ─────────────────────────────────────────────
  static String _buildSvgBarChart(List<Indicator> indicators) {
    if (indicators.isEmpty) return '';

    const chartW = 700.0;
    const chartH = 280.0;
    const padLeft = 50.0;
    const padBottom = 60.0;
    const padTop = 20.0;
    const padRight = 20.0;

    final plotW = chartW - padLeft - padRight;
    final plotH = chartH - padBottom - padTop;

    final maxVal = indicators
        .map((e) => e.current > e.target ? e.current : e.target)
        .reduce((a, b) => a > b ? a : b) * 1.2;

    final groupW = plotW / indicators.length;
    const barW = 22.0;
    const barGap = 6.0;

    final gridLines = List.generate(5, (i) {
      final y = padTop + plotH * (1 - i / 4);
      final val = (maxVal * i / 4).toStringAsFixed(0);
      return '''
        <line x1="$padLeft" y1="$y" x2="${chartW - padRight}" y2="$y" stroke="#ffffff18" stroke-width="1" stroke-dasharray="4,4"/>
        <text x="${padLeft - 6}" y="${y + 4}" text-anchor="end" fill="#64748B" font-size="11">$val</text>
      ''';
    }).join('');

    final bars = indicators.asMap().entries.map((entry) {
      final i = entry.key;
      final e = entry.value;
      final centerX = padLeft + groupW * i + groupW / 2;
      final catColor = _indicatorColorHex(e.category);

      final barH1 = (e.current / maxVal) * plotH;
      final barH2 = (e.target / maxVal) * plotH;

      final x1 = centerX - barW - barGap / 2;
      final x2 = centerX + barGap / 2;
      final y1 = padTop + plotH - barH1;
      final y2 = padTop + plotH - barH2;

      final label = e.name.length > 12 ? '${e.name.substring(0, 12)}…' : e.name;
      final labelY = padTop + plotH + 18;
      final subLabelY = padTop + plotH + 32;

      return '''
        <rect x="$x1" y="$y1" width="$barW" height="$barH1" rx="4" ry="4" fill="$catColor" opacity="0.9">
          <animate attributeName="height" from="0" to="$barH1" dur="0.8s" fill="freeze" begin="${i * 0.15}s"/>
          <animate attributeName="y" from="${padTop + plotH}" to="$y1" dur="0.8s" fill="freeze" begin="${i * 0.15}s"/>
        </rect>
        <rect x="$x2" y="$y2" width="$barW" height="$barH2" rx="4" ry="4" fill="#06B6D4" opacity="0.9">
          <animate attributeName="height" from="0" to="$barH2" dur="0.8s" fill="freeze" begin="${i * 0.15 + 0.1}s"/>
          <animate attributeName="y" from="${padTop + plotH}" to="$y2" dur="0.8s" fill="freeze" begin="${i * 0.15 + 0.1}s"/>
        </rect>
        <text x="$centerX" y="$labelY" text-anchor="middle" fill="#CBD5E1" font-size="10">$label</text>
        <text x="${x1 + barW/2}" y="${y1 - 4}" text-anchor="middle" fill="$catColor" font-size="9" font-weight="bold">${e.current}</text>
        <text x="${x2 + barW/2}" y="${y2 - 4}" text-anchor="middle" fill="#06B6D4" font-size="9" font-weight="bold">${e.target}</text>
      ''';
    }).join('');

    return '''
<svg viewBox="0 0 $chartW $chartH" xmlns="http://www.w3.org/2000/svg" style="width:100%;max-width:700px;display:block;margin:0 auto;">
  <rect width="$chartW" height="$chartH" rx="12" fill="#1E293B"/>
  $gridLines
  <line x1="$padLeft" y1="$padTop" x2="$padLeft" y2="${padTop + plotH}" stroke="#ffffff20" stroke-width="1"/>
  $bars
  <!-- Legend -->
  <rect x="210" y="${chartH - 18}" width="12" height="12" rx="2" fill="#6366F1" />
  <text x="226" y="${chartH - 8}" fill="#CBD5E1" font-size="11">القيمة الحالية</text>
  <rect x="330" y="${chartH - 18}" width="12" height="12" rx="2" fill="#06B6D4"/>
  <text x="346" y="${chartH - 8}" fill="#CBD5E1" font-size="11">الهدف المستهدف</text>
</svg>''';
  }

  // ─────────────────────────────────────────────
  //  SVG Donut for each indicator
  // ─────────────────────────────────────────────
  static String _buildDonut(double pct, String colorHex, String label, String sub) {
    const r = 38.0;
    const cx = 50.0;
    const cy = 50.0;
    const strokeW = 9.0;
    const circumference = 2 * 3.14159265 * r;
    final dashOffset = circumference * (1 - pct / 100);

    return '''
<svg viewBox="0 0 100 110" xmlns="http://www.w3.org/2000/svg" style="width:120px;height:130px;">
  <circle cx="$cx" cy="$cy" r="$r" fill="none" stroke="#334155" stroke-width="$strokeW"/>
  <circle cx="$cx" cy="$cy" r="$r" fill="none" stroke="$colorHex" stroke-width="$strokeW"
    stroke-dasharray="$circumference" stroke-dashoffset="$circumference"
    stroke-linecap="round" transform="rotate(-90 $cx $cy)">
    <animate attributeName="stroke-dashoffset" from="$circumference" to="$dashOffset" dur="1.2s" fill="freeze" easing="ease-out"/>
  </circle>
  <text x="$cx" y="${cy + 5}" text-anchor="middle" fill="$colorHex" font-size="13" font-weight="bold">${pct.toStringAsFixed(0)}%</text>
  <text x="$cx" y="90" text-anchor="middle" fill="#CBD5E1" font-size="8" font-weight="bold">$label</text>
  <text x="$cx" y="102" text-anchor="middle" fill="$colorHex" font-size="7">$sub</text>
</svg>''';
  }

  // ─────────────────────────────────────────────
  //  Overall Score Ring
  // ─────────────────────────────────────────────
  static String _buildOverallRing(double pct) {
    const r = 55.0;
    const cx = 80.0;
    const cy = 80.0;
    const strokeW = 13.0;
    const circumference = 2 * 3.14159265 * r;
    final dashOffset = circumference * (1 - pct / 100);

    String ringColor;
    if (pct >= 100) ringColor = '#10B981';
    else if (pct >= 75) ringColor = '#06B6D4';
    else if (pct >= 50) ringColor = '#F59E0B';
    else ringColor = '#EF4444';

    return '''
<svg viewBox="0 0 160 160" xmlns="http://www.w3.org/2000/svg" style="width:160px;height:160px;">
  <circle cx="$cx" cy="$cy" r="$r" fill="none" stroke="#1E293B" stroke-width="${strokeW + 2}"/>
  <circle cx="$cx" cy="$cy" r="$r" fill="none" stroke="#334155" stroke-width="$strokeW"/>
  <circle cx="$cx" cy="$cy" r="$r" fill="none" stroke="$ringColor" stroke-width="$strokeW"
    stroke-dasharray="$circumference" stroke-dashoffset="$circumference"
    stroke-linecap="round" transform="rotate(-90 $cx $cy)">
    <animate attributeName="stroke-dashoffset" from="$circumference" to="$dashOffset" dur="1.5s" fill="freeze"/>
  </circle>
  <text x="$cx" y="${cy + 6}" text-anchor="middle" fill="$ringColor" font-size="20" font-weight="bold">${pct.toStringAsFixed(1)}%</text>
  <text x="$cx" y="${cy + 22}" text-anchor="middle" fill="#94A3B8" font-size="11">الأداء العام</text>
</svg>''';
  }

  // ─────────────────────────────────────────────
  //  Full HTML
  // ─────────────────────────────────────────────
  static String _buildHtml(List<Indicator> indicators, String title) {
    final now = DateTime.now();
    final dateStr = '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';

    final achieved   = indicators.where((e) => e.achievePct >= 100).length;
    final onTrack    = indicators.where((e) => e.achievePct >= 75 && e.achievePct < 100).length;
    final needsWork  = indicators.where((e) => e.achievePct < 75).length;
    final overallAvg = indicators.isEmpty ? 0.0
        : indicators.map((e) => e.achievePct).reduce((a, b) => a + b) / indicators.length;

    // Indicator cards HTML
    final indicatorCards = indicators.map((e) {
      final pct       = e.achievePct;
      final catColor  = _indicatorColorHex(e.category);
      final statColor = _statusColorHex(e);
      final icon      = _categoryIcon(e.category);
      final donut     = _buildDonut(pct, statColor, e.statusLabel, '${pct.toStringAsFixed(1)}%');

      return '''
<div class="ind-card">
  <div class="ind-header">
    <div class="ind-title">
      <div class="ind-icon" style="background:${catColor}22; color:$catColor;">
        <span class="material-symbols-outlined">$icon</span>
      </div>
      ${e.name}
    </div>
    <div class="ind-status" style="background:$statColor;">${e.statusLabel}</div>
  </div>
  <div class="ind-values">
    <div class="val-block">
      <div class="val-label">القيمة الحالية</div>
      <div class="val-number" style="color:$catColor;">${e.current} ${e.unit}</div>
    </div>
    <div class="val-arrow">↔</div>
    <div class="val-block">
      <div class="val-label">الهدف</div>
      <div class="val-number" style="color:#06B6D4;">${e.target} ${e.unit}</div>
    </div>
    <div class="ind-donut">$donut</div>
  </div>
</div>''';
    }).join('\n');

    final summaryRing = _buildOverallRing(overallAvg);
    final barChart    = _buildSvgBarChart(indicators);

    return '''<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
  <meta charset="UTF-8"/>
  <title>$title</title>
  <style>
    body {
      font-family: 'Tajawal', 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
      background-color: #f3f4f6;
      color: #1f2937;
      margin: 0; padding: 20px;
    }
    .header {
      text-align: center; margin-bottom: 30px;
      padding: 30px;
      background: linear-gradient(135deg, #005C53, #007D72);
      border-radius: 16px;
      color: white;
      box-shadow: 0 4px 6px -1px rgba(0,0,0,0.1);
      position: relative;
    }
    .moh-logo {
      position: absolute;
      top: 20px;
      right: 30px;
      height: 80px;
    }
    .header h1 { margin: 0; font-size: 32px; font-weight: 800; }
    .header p { margin: 8px 0 0; color: #a7f3d0; font-size: 16px; }
    
    .ind-card {
      background: white;
      border-radius: 16px;
      padding: 24px;
      margin-bottom: 20px;
      box-shadow: 0 4px 6px -1px rgba(0,0,0,0.1);
      border: 1px solid #e5e7eb;
    }
    .ind-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 20px; }
    .ind-title { display: flex; align-items: center; gap: 12px; font-size: 18px; font-weight: 700; color: #374151;}
    .ind-icon {
      width: 40px; height: 40px; border-radius: 10px;
      display: flex; align-items: center; justify-content: center;
      font-size: 20px;
    }
    .ind-status {
      padding: 6px 12px; border-radius: 20px; font-size: 12px; font-weight: bold;
      color: white;
    }
    .ind-values { 
      display: flex; align-items: center; gap: 16px; background: #f9fafb; padding: 16px; border-radius: 12px;
    }
    .val-block { display: flex; flex-direction: column; gap: 4px; }
    .val-label { font-size: 12px; color: #6b7280; }
    .val-number { font-size: 20px; font-weight: 800; }
    .val-arrow { color: #9ca3af; font-size: 18px; align-self: center; }
    .ind-donut { margin-right: auto; }

    .chart-wrap {
      background: white; border-radius: 16px; padding: 24px; margin-top: 30px;
      border: 1px solid #e5e7eb; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.1);
    }
    .chart-title { font-size: 18px; font-weight: bold; margin-bottom: 20px; display: flex; align-items: center; gap: 10px; color: #374151;}
    .section-icon { width: 32px; height: 32px; border-radius: 8px; display: flex; align-items: center; justify-content: center;}
    
    .summary-wrap { background: white; border-radius: 16px; padding: 24px; margin-top: 30px; border: 1px solid #e5e7eb; }
    .summary-inner { display: flex; align-items: center; gap: 36px; flex-wrap: wrap; }
    .stat-cards { display: flex; gap: 14px; flex: 1; flex-wrap: wrap; }
    .stat-card { flex: 1; min-width: 100px; padding: 18px; border-radius: 14px; text-align: center; border: 1px solid #e5e7eb; }
  </style>
  <link href="https://fonts.googleapis.com/css2?family=Tajawal:wght@400;700;800&display=swap" rel="stylesheet">
  <link href="https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined" rel="stylesheet" />
</head>
<body>
<div class="page">
  <div class="header">
    <img src="https://www.moh.gov.sa/SiteCollectionImages/MOH_Logo_W.png" alt="MOH Logo" class="moh-logo" onerror="this.style.display='none'">
    <h1>$title</h1>
    <p>تم الإنشاء بتاريخ $dateStr</p>
  </div>

  <!-- Indicators -->
  <div class="section-title">
    <div class="section-icon" style="background:#005C5322; color:#005C53;">
      <span class="material-symbols-outlined">dataset</span>
    </div>
    المؤشرات الصحية
  </div>
  $indicatorCards

  <!-- Bar Chart -->
  <div class="chart-wrap">
    <div class="chart-title">
      <div class="section-icon" style="background:#005C5322;color:#005C53;">
        <span class="material-symbols-outlined">bar_chart</span>
      </div>
      الوضع الحالي مقابل الهدف المستهدف
    </div>
    $barChart
  </div>

  <!-- Summary -->
  <div class="summary-wrap">
    <div class="section-title">
      <div class="section-icon" style="background:#F59E0B22;">🏆</div>
      ملخص الأداء العام
    </div>
    <div class="summary-inner">
      $summaryRing
      <div class="stat-cards">
        <div class="stat-card" style="background:#10B98122;border:1px solid #10B98144;">
          <div class="stat-icon">✅</div>
          <div class="stat-number" style="color:#10B981;">$achieved</div>
          <div class="stat-label">مُحقَّق</div>
        </div>
        <div class="stat-card" style="background:#06B6D422;border:1px solid #06B6D444;">
          <div class="stat-icon">📈</div>
          <div class="stat-number" style="color:#06B6D4;">$onTrack</div>
          <div class="stat-label">قريب من الهدف</div>
        </div>
        <div class="stat-card" style="background:#EF444422;border:1px solid #EF444444;">
          <div class="stat-icon">⚠️</div>
          <div class="stat-number" style="color:#EF4444;">$needsWork</div>
          <div class="stat-label">يحتاج تحسين</div>
        </div>
      </div>
    </div>
  </div>

  <!-- Footer -->
  <div class="footer">
    تم التصدير بواسطة <span>داشبورد ميكر</span> — جميع البيانات مدخلة يدوياً ومقارنة بأهداف WHO
  </div>

</div>
</body>
</html>''';
  }
}
