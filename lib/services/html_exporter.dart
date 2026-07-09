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
      case IndicatorCategory.general: return '📊';
      case IndicatorCategory.health:     return '❤️';
      case IndicatorCategory.economic:    return '💰';
      case IndicatorCategory.environment:      return '🌿';
      case IndicatorCategory.education:   return '📚';
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
    <div class="ind-icon" style="background:${catColor}22;color:$catColor;">$icon</div>
    <div class="ind-meta">
      <div class="ind-name">${e.name}</div>
      <div class="ind-cat">${e.category.labelAr}</div>
    </div>
    <div class="status-badge" style="background:${statColor}22;color:$statColor;border-color:${statColor}44;">${e.statusLabel}</div>
  </div>
  <div class="ind-values">
    <div class="val-block">
      <div class="val-label">القيمة الحالية</div>
      <div class="val-number" style="color:$catColor;">${e.current} ${e.unit}</div>
    </div>
    <div class="val-arrow">→</div>
    <div class="val-block">
      <div class="val-label">الهدف المستهدف</div>
      <div class="val-number" style="color:#06B6D4;">${e.target} ${e.unit}</div>
    </div>
    <div class="ind-donut">$donut</div>
  </div>
  <div class="prog-wrap">
    <div class="prog-labels">
      <span>التقدم نحو الهدف</span>
      <span style="color:$statColor;font-weight:700;">${pct.toStringAsFixed(1)}%</span>
    </div>
    <div class="prog-track">
      <div class="prog-fill" style="width:${pct.clamp(0, 100)}%;background:$statColor;"></div>
    </div>
  </div>
</div>''';
    }).join('\n');

    // Summary section
    final summaryRing = _buildOverallRing(overallAvg);
    final barChart    = _buildSvgBarChart(indicators);

    return '''<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
  <meta charset="UTF-8"/>
  <meta name="viewport" content="width=device-width,initial-scale=1"/>
  <title>$title — داشبورد ميكر</title>
  <style>
    @import url('https://fonts.googleapis.com/css2?family=Noto+Sans+Arabic:wght@400;600;700;900&family=Inter:wght@400;600;700;900&display=swap');

    *,*::before,*::after{box-sizing:border-box;margin:0;padding:0;}
    :root{
      --bg:#0B0F19;--surface:#1E293B;--surface2:#0F172A;
      --indigo:#6366F1;--cyan:#06B6D4;--white:#F1F5F9;
      --muted:#64748B;--border:#1E293B;
    }
    body{background:var(--bg);color:var(--white);font-family:'Noto Sans Arabic','Inter',sans-serif;min-height:100vh;direction:rtl;}

    /* ── Animated gradient background ── */
    body::before{
      content:'';position:fixed;inset:0;
      background:radial-gradient(ellipse at 20% 20%, #1E1B4B88 0%, transparent 60%),
                 radial-gradient(ellipse at 80% 80%, #06B6D422 0%, transparent 60%);
      pointer-events:none;z-index:0;
    }

    .page{position:relative;z-index:1;max-width:1000px;margin:0 auto;padding:40px 24px 80px;}

    /* ── Header ── */
    .header{
      display:flex;align-items:center;gap:18px;
      background:linear-gradient(135deg,#6366F122,#06B6D412);
      border:1px solid #6366F133;border-radius:20px;padding:28px 32px;
      margin-bottom:36px;
    }
    .header-icon{font-size:40px;line-height:1;}
    .header-title{font-size:28px;font-weight:900;letter-spacing:0.3px;
      background:linear-gradient(135deg,#6366F1,#06B6D4);
      -webkit-background-clip:text;-webkit-text-fill-color:transparent;}
    .header-sub{color:var(--muted);font-size:14px;margin-top:4px;}
    .header-badge{margin-right:auto;background:linear-gradient(135deg,#6366F1,#06B6D4);
      color:#fff;font-size:13px;font-weight:700;padding:8px 18px;border-radius:30px;white-space:nowrap;}
    .header-date{color:var(--muted);font-size:12px;margin-top:2px;}

    /* ── Section Title ── */
    .section-title{font-size:17px;font-weight:700;color:var(--white);
      display:flex;align-items:center;gap:10px;margin-bottom:16px;}
    .section-icon{width:36px;height:36px;border-radius:10px;display:flex;align-items:center;
      justify-content:center;font-size:18px;flex-shrink:0;}

    /* ── Indicator Cards ── */
    .ind-card{
      background:var(--surface);border:1px solid #ffffff15;border-radius:18px;
      padding:20px;margin-bottom:16px;
      transition:box-shadow 0.3s,transform 0.2s;
    }
    .ind-card:hover{box-shadow:0 0 24px #6366F130;transform:translateY(-2px);}
    .ind-header{display:flex;align-items:center;gap:14px;margin-bottom:16px;}
    .ind-icon{width:42px;height:42px;border-radius:12px;display:flex;align-items:center;justify-content:center;font-size:20px;flex-shrink:0;}
    .ind-meta{flex:1;}
    .ind-name{font-size:15px;font-weight:700;color:var(--white);}
    .ind-cat{font-size:12px;color:var(--muted);margin-top:2px;}
    .status-badge{font-size:11px;font-weight:700;padding:5px 12px;border-radius:20px;border:1px solid;white-space:nowrap;}
    .ind-values{display:flex;align-items:center;gap:12px;margin-bottom:16px;flex-wrap:wrap;}
    .val-block{flex:1;min-width:100px;}
    .val-label{font-size:11px;color:var(--muted);margin-bottom:4px;}
    .val-number{font-size:16px;font-weight:700;}
    .val-arrow{font-size:20px;color:#ffffff30;}
    .ind-donut{margin-right:auto;}
    .prog-wrap{border-top:1px solid #ffffff10;padding-top:12px;}
    .prog-labels{display:flex;justify-content:space-between;font-size:12px;color:var(--muted);margin-bottom:6px;}
    .prog-track{background:#ffffff10;border-radius:6px;height:8px;overflow:hidden;}
    .prog-fill{height:100%;border-radius:6px;transition:width 1.2s cubic-bezier(.4,0,.2,1);}

    /* ── Summary Section ── */
    .summary-wrap{
      background:linear-gradient(135deg,var(--surface),var(--surface2));
      border:1px solid #ffffff15;border-radius:20px;padding:28px;margin-top:36px;
    }
    .summary-inner{display:flex;align-items:center;gap:36px;flex-wrap:wrap;}
    .stat-cards{display:flex;gap:14px;flex:1;flex-wrap:wrap;}
    .stat-card{flex:1;min-width:100px;padding:18px 14px;border-radius:14px;text-align:center;}
    .stat-number{font-size:28px;font-weight:900;margin-bottom:4px;}
    .stat-label{font-size:12px;color:var(--muted);}
    .stat-icon{font-size:22px;margin-bottom:8px;}

    /* ── Chart Section ── */
    .chart-wrap{
      background:var(--surface);border:1px solid #ffffff15;border-radius:20px;
      padding:24px;margin-top:24px;
    }
    .chart-title{display:flex;align-items:center;gap:10px;font-size:15px;font-weight:700;margin-bottom:20px;}

    /* ── Footer ── */
    .footer{margin-top:48px;text-align:center;color:var(--muted);font-size:12px;border-top:1px solid #ffffff0D;padding-top:20px;}
    .footer span{background:linear-gradient(135deg,#6366F1,#06B6D4);-webkit-background-clip:text;-webkit-text-fill-color:transparent;font-weight:700;}

    /* ── Print ── */
    @media print{
      body::before{display:none;}
      .ind-card,.chart-wrap,.summary-wrap{break-inside:avoid;}
    }
    @media(max-width:600px){
      .header{flex-wrap:wrap;}.header-badge{margin-right:0;}
      .ind-values{flex-direction:column;}.ind-donut{margin-right:0;}
    }
  </style>
</head>
<body>
<div class="page">

  <!-- Header -->
  <div class="header">
    <div class="header-icon">📊</div>
    <div>
      <div class="header-title">$title</div>
      <div class="header-sub">لوحة مقارنة مؤشرات الصحة بأهداف منظمة الصحة العالمية (WHO)</div>
      <div class="header-date">تاريخ التصدير: $dateStr</div>
    </div>
    <div class="header-badge">${indicators.length} مؤشرات</div>
  </div>

  <!-- Indicators -->
  <div class="section-title">
    <div class="section-icon" style="background:#6366F122;">📋</div>
    المؤشرات الصحية
  </div>
  $indicatorCards

  <!-- Bar Chart -->
  <div class="chart-wrap">
    <div class="chart-title">
      <div class="section-icon" style="background:#6366F122;font-size:16px;">📊</div>
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
