// assets/charts.js — PCB 转 Gerber 自检说明的图表与流程图初始化
(function () {
  'use strict';

  var style = getComputedStyle(document.documentElement);
  var accent = style.getPropertyValue('--accent').trim();
  var accent2 = style.getPropertyValue('--accent2').trim();
  var ink = style.getPropertyValue('--ink').trim();
  var muted = style.getPropertyValue('--muted').trim();
  var rule = style.getPropertyValue('--rule').trim();

  // ---- Mermaid ----
  if (window.mermaid) {
    mermaid.initialize({ startOnLoad: true, theme: 'neutral', securityLevel: 'loose' });
  }

  // ---- 图 2：四层 行程段数 与 Gerber 体积 ----
  var el = document.getElementById('chart-runs');
  if (el && window.echarts) {
    var layers = ['GTO · 丝印', 'GTS · 阻焊', 'GTL · 铜层', 'Backlight · 背光'];
    var runs = [897, 637, 349, 299];
    var kb = [29.0, 20.6, 11.3, 9.7];

    var chart = echarts.init(el, null, { renderer: 'svg' });
    chart.setOption({
      animation: false,
      tooltip: { trigger: 'axis', appendToBody: true },
      legend: { data: ['行程段数', 'Gerber 体积 (KB)'], textStyle: { color: ink } },
      grid: { left: 56, right: 56, top: 44, bottom: 40 },
      xAxis: {
        type: 'category',
        data: layers,
        axisLine: { lineStyle: { color: rule } },
        axisLabel: { color: ink },
        axisTick: { show: false }
      },
      yAxis: [
        {
          type: 'value', name: '行程段数',
          nameTextStyle: { color: muted },
          splitLine: { lineStyle: { color: rule } },
          axisLabel: { color: muted }
        },
        {
          type: 'value', name: 'KB',
          nameTextStyle: { color: muted },
          splitLine: { show: false },
          axisLabel: { color: muted }
        }
      ],
      series: [
        {
          name: '行程段数',
          type: 'bar',
          data: runs,
          barWidth: '42%',
          itemStyle: { color: accent, borderRadius: [3, 3, 0, 0] },
          label: { show: true, position: 'top', color: accent, fontWeight: 700 }
        },
        {
          name: 'Gerber 体积 (KB)',
          type: 'line',
          yAxisIndex: 1,
          data: kb,
          smooth: true,
          lineStyle: { color: accent2, width: 2 },
          itemStyle: { color: accent2 },
          symbol: 'circle',
          symbolSize: 8,
          label: { show: true, position: 'top', color: accent2, fontWeight: 700 }
        }
      ]
    });
    window.addEventListener('resize', function () { chart.resize(); });
  }
})();