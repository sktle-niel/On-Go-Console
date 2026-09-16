import 'package:flutter/material.dart';

import 'package:on_go_console_backend/console_backend.dart';
import '../theme/console_theme.dart';
import 'console_formats.dart';
import 'console_widgets.dart';

/// The two revenue charts, ported from the Admin panel this console replaced.
///
/// Both answer a pointer the same way: a month lights up under a hovering
/// mouse or a pressed finger, and goes dark again when the mouse leaves or the
/// finger lifts. See [ChartProbe], which is where that behaviour lives.
///
/// Both read the same [MonthlyIncome] list and share the axis and the callout,
/// so the Overview line and the Income bars cannot drift apart.

/// THE colour each urgency is drawn in, wherever it appears in the console —
/// the two charts, the legend and the rings all read this one function, so a
/// reader who learns the key on the Overview can use it on Income.
///
/// It is the same severity ramp the mobile app paints urgency in (green →
/// amber → red), so a Normal job looks like a Normal job in both applications.
/// The colours come from the shared palette, never from a literal here.
Color revenueUrgencyColor(RevenueUrgency urgency) {
  switch (urgency) {
    case RevenueUrgency.normal:
      return ConsoleColors.success;
    case RevenueUrgency.urgent:
      return ConsoleColors.warning;
    case RevenueUrgency.emergency:
      return ConsoleColors.danger;
  }
}

/// The horizontal rules behind either chart.
///
/// Deliberately fainter than a card border. The grid is there to let the eye
/// carry a value across to the axis, not to be looked at — in the reference
/// the lines are barely present, and the curves are the only thing with any
/// weight. Both charts read this, so they cannot end up on two different
/// grids.
Color get revenueGridColor => ConsoleColors.border.withValues(alpha: 0.55);

/// One urgency plotted across the months on screen.
///
/// Built once per chart and handed to the painter, so the three series are
/// read out of [MonthlyIncome] in exactly one place rather than each chart
/// reaching into the model its own way.
class RevenueSeries {
  final RevenueUrgency urgency;
  final Color color;

  /// Revenue per month, in the order the months were given.
  final List<double> revenue;

  /// Completed payments per month, same order.
  final List<int> transactions;

  const RevenueSeries({
    required this.urgency,
    required this.color,
    required this.revenue,
    required this.transactions,
  });

  String get label => urgency.label;
}

List<RevenueSeries> buildRevenueSeries(List<RevenuePeriod> periods) => [
      for (final urgency in RevenueUrgency.values)
        RevenueSeries(
          urgency: urgency,
          color: revenueUrgencyColor(urgency),
          revenue: [for (final period in periods) period.revenueFor(urgency)],
          transactions: [for (final period in periods) period.transactionsFor(urgency)],
        ),
    ];

/// The top of the scale for OVERLAID series — the tallest single point across
/// all three, with headroom. Scaling to the period TOTAL instead would flatten
/// every line into the bottom third, since the total is the three added up.
double revenueSeriesMax(List<RevenueSeries> series) {
  var max = 0.0;
  for (final line in series) {
    for (final value in line.revenue) {
      if (value > max) max = value;
    }
  }
  // A ledger with no fees yet still needs a scale to draw an axis against.
  return max <= 0 ? 100 : max * 1.15;
}

/// The top of the scale for STACKED bars — the tallest period total, since a
/// stack is the three urgencies piled on each other rather than laid over.
double revenuePeriodMax(List<RevenuePeriod> periods) {
  var max = 0.0;
  for (final period in periods) {
    if (period.revenue > max) max = period.revenue;
  }
  return max <= 0 ? 100 : max * 1.15;
}

/// The pointer handling both charts sit under, so a mouse and a finger pick a
/// month the same way on either of them.
///
/// [onProbe] is called with a position inside the plot whenever the pointer is
/// over it — moving a mouse, or pressing and dragging a finger. [onClear] is
/// called the moment the pointer stops being there: the mouse leaves, or the
/// finger lifts.
///
/// Horizontal drag rather than pan, deliberately. These charts sit inside a
/// vertically scrolling page, and a pan recognizer would claim vertical drags
/// too — the chart would eat the scroll, and a reader who swiped up over it
/// would find the page stuck. Claiming only horizontal movement leaves the
/// scroll to the list it belongs to.
class ChartProbe extends StatelessWidget {
  const ChartProbe({
    super.key,
    required this.onProbe,
    required this.onClear,
    required this.child,
  });

  final ValueChanged<Offset> onProbe;
  final VoidCallback onClear;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (event) => onProbe(event.localPosition),
      onExit: (_) => onClear(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // A press shows the month under the finger straight away, rather than
        // waiting to see whether a drag is coming.
        onTapDown: (d) => onProbe(d.localPosition),
        onTapUp: (_) => onClear(),
        onTapCancel: onClear,
        onHorizontalDragStart: (d) => onProbe(d.localPosition),
        onHorizontalDragUpdate: (d) => onProbe(d.localPosition),
        onHorizontalDragEnd: (_) => onClear(),
        onHorizontalDragCancel: onClear,
        child: child,
      ),
    );
  }
}

/// The left-hand '₱Xk' axis labels.
class RevenueAxis extends StatelessWidget {
  final double maxValue;
  final double height;
  final int steps;

  const RevenueAxis({
    super.key,
    required this.maxValue,
    required this.height,
    this.steps = 4,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: height,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(steps + 1, (i) {
          final value = maxValue * (steps - i) / steps;
          // One unit for the whole axis, picked from the top of the scale, so
          // small real amounts read as ₱150 rather than a column of ₱0k.
          final label = maxValue >= 1000
              ? '₱${(value / 1000).toStringAsFixed(0)}k'
              : '₱${value.toStringAsFixed(0)}';
          return Text(label, style: Theme.of(context).textTheme.bodySmall);
        }),
      ),
    );
  }
}

/// The floating callout naming the highlighted month, its total, and what each
/// urgency contributed to it.
///
/// Three lines rather than one, because the charts now draw three series: a
/// callout reporting only the total would name a figure no line on screen is
/// actually at.
class RevenueCallout extends StatelessWidget {
  final String label;
  final RevenuePeriod period;

  const RevenueCallout({super.key, required this.label, required this.period});

  /// Fixed, because the charts position it by half its width — a callout that
  /// sized itself to its content would drift off the point it is naming.
  static const double width = 168;

  @override
  Widget build(BuildContext context) {
    final onDark = ConsoleColors.canvas;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: width,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: ConsoleColors.text,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(color: Color(0x33000000), blurRadius: 14, offset: Offset(0, 5)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 0.7,
                  fontWeight: FontWeight.w700,
                  color: onDark.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '₱${period.revenue.toStringAsFixed(0)}',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: onDark),
              ),
              Text(
                period.transactions == 1 ? '1 payment' : '${period.transactions} payments',
                style: TextStyle(fontSize: 11, color: onDark.withValues(alpha: 0.75)),
              ),
              const SizedBox(height: 6),
              for (final urgency in RevenueUrgency.values)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: revenueUrgencyColor(urgency),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          urgency.label,
                          style: TextStyle(
                            fontSize: 11,
                            color: onDark.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                      Text(
                        '₱${period.revenueFor(urgency).toStringAsFixed(0)} · '
                        '${period.transactionsFor(urgency)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: onDark,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        CustomPaint(size: const Size(12, 6), painter: _CalloutTail(ConsoleColors.text)),
      ],
    );
  }
}

class _CalloutTail extends CustomPainter {
  const _CalloutTail(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_CalloutTail old) => old.color != color;
}

/// Monthly revenue as three curves — Normal, Urgent and Emergency — for the
/// Admin Overview.
///
/// Three flowing lines on a faint horizontal grid, with the key underneath,
/// and nothing else: no shading under the curves, no dots along them, no
/// vertical rules. Each line is a single continuous stroke the eye can follow
/// from January to December, which is the whole job of this chart.
///
/// The area washes that used to sit under each curve are gone. With one series
/// a wash reads as volume; with three overlaid it reads as mud — the front
/// one tints the two behind it, and a reader comparing Urgent against
/// Emergency is comparing two colours that have been mixed with a third.
class RevenueLineChart extends StatefulWidget {
  final List<RevenuePeriod> income;
  final double height;

  const RevenueLineChart({super.key, required this.income, this.height = 170});

  @override
  State<RevenueLineChart> createState() => _RevenueLineChartState();
}

class _RevenueLineChartState extends State<RevenueLineChart> {
  int? _hovered;

  @override
  Widget build(BuildContext context) {
    final income = widget.income;
    final series = buildRevenueSeries(income);
    final maxRevenue = revenueSeriesMax(series);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: widget.height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RevenueAxis(maxValue: maxRevenue, height: widget.height),
              const SizedBox(width: 8),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final segment =
                        income.length > 1 ? width / (income.length - 1) : width;

                    void probe(Offset local) {
                      final raw =
                          income.length > 1 ? (local.dx / segment).round() : 0;
                      final clamped = raw.clamp(0, income.length - 1);
                      if (clamped != _hovered) setState(() => _hovered = clamped);
                    }

                    return ChartProbe(
                      onProbe: probe,
                      onClear: () {
                        if (_hovered != null) setState(() => _hovered = null);
                      },
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _LineChartPainter(
                                series: series,
                                maxRevenue: maxRevenue,
                                highlight: _hovered,
                                grid: revenueGridColor,
                                surface: ConsoleColors.surface,
                              ),
                            ),
                          ),
                          ..._callout(income, series, maxRevenue, segment, width),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _PeriodAxisLabels(periods: income, highlight: _hovered),
        const SizedBox(height: 14),
        // The key, doubling as the monthly transaction counts asked of it.
        RevenueUrgencyLegend(periods: income, highlight: _hovered),
      ],
    );
  }

  List<Widget> _callout(
    List<RevenuePeriod> income,
    List<RevenueSeries> series,
    double maxRevenue,
    double segment,
    double width,
  ) {
    final index = _hovered;
    if (index == null) return const [];

    // Anchor the callout above the HIGHEST of the three points at this month,
    // so it never lands on top of a line it is describing.
    var topFraction = 0.0;
    for (final line in series) {
      final fraction =
          maxRevenue == 0 ? 0.0 : (line.revenue[index] / maxRevenue).clamp(0.0, 1.0);
      if (fraction > topFraction) topFraction = fraction;
    }
    final pointY = widget.height - topFraction * (widget.height - 12);

    final maxLeft = (width - RevenueCallout.width).clamp(0.0, double.infinity);
    return [
      Positioned(
        left: (segment * index - RevenueCallout.width / 2).clamp(0.0, maxLeft),
        top: (pointY - 132).clamp(0.0, widget.height),
        child: IgnorePointer(
          child: RevenueCallout(
            label: income[index].periodLabel,
            period: income[index],
          ),
        ),
      ),
    ];
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.series,
    required this.maxRevenue,
    required this.highlight,
    required this.grid,
    required this.surface,
  });

  final List<RevenueSeries> series;
  final double maxRevenue;
  final int? highlight;
  final Color grid;
  final Color surface;

  /// How heavy a curve is drawn.
  ///
  /// Three lines crossing each other need enough weight that a reader can tell
  /// which one they are following through a crossing. With nothing shaded
  /// underneath them any more, the strokes are all this chart has.
  static const double _stroke = 3.0;

  /// How far a curve may bow past the straight line between two months.
  ///
  /// 1.0 is a full Catmull-Rom spline, which flows nicely but overshoots hard
  /// around a spike — on a revenue chart that draws a dip below a month that
  /// earned nothing, or a hump above a peak that was never reached. Pulling it
  /// back to two-thirds keeps the flow and takes most of the overshoot out;
  /// the clamp in [_smoothPath] catches whatever is left.
  static const double _tension = 0.66;

  @override
  void paint(Canvas canvas, Size size) {
    if (series.isEmpty || series.first.revenue.isEmpty) return;
    final count = series.first.revenue.length;

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Months are spaced across the full width, matching the segment the chart
    // itself divides a pointer's position by — so the month under the finger
    // is the month whose point is drawn there.
    final dx = count > 1 ? size.width / (count - 1) : size.width;

    Offset pointFor(RevenueSeries line, int index) {
      final fraction =
          maxRevenue == 0 ? 0.0 : (line.revenue[index] / maxRevenue).clamp(0.0, 1.0);
      return Offset(dx * index, size.height - fraction * (size.height - 12));
    }

    // The vertical marker goes down first, so it sits behind every line
    // instead of cutting across them.
    final index = highlight;
    if (index != null) {
      final x = dx * index.clamp(0, count - 1);
      _dashedLine(canvas, Offset(x, 0), Offset(x, size.height), grid);
    }

    final curves = <RevenueSeries, Path>{};
    final plotted = <RevenueSeries, List<Offset>>{};
    for (final line in series) {
      final points = [for (var i = 0; i < count; i++) pointFor(line, i)];
      plotted[line] = points;
      curves[line] = _smoothPath(points, size.height);
    }

    for (final line in series) {
      canvas.drawPath(
        curves[line]!,
        Paint()
          ..color = line.color
          ..strokeWidth = _stroke
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );

      if (index != null) {
        final points = plotted[line]!;
        final point = points[index.clamp(0, points.length - 1)];
        canvas.drawCircle(point, 5, Paint()..color = line.color);
        canvas.drawCircle(
          point,
          5,
          Paint()
            ..color = surface
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }
  }

  /// A flowing curve that passes THROUGH every point in [points].
  ///
  /// One cubic per pair of months, with the control points taken from the
  /// neighbours either side — a Catmull-Rom spline, softened by [_tension].
  /// That is what gives the long rolling waves in the reference rather than a
  /// series of straight runs with the corners taken off.
  ///
  /// The earlier version bent a quadratic AROUND each point and joined the
  /// midpoints, which is cheap and never overshoots, but it does not actually
  /// touch the months it is plotting: a peak was drawn lower than the month it
  /// stood for. A chart a reader points at to read a figure should put its
  /// line where the figure is.
  ///
  /// [height] is the plot's height, and it is a hard floor and ceiling. A
  /// spline can bow past its own points on the way between two of them, and on
  /// revenue that would draw a month dipping below zero — money that was never
  /// un-earned. Clamping the control points keeps the curve inside the plot.
  Path _smoothPath(List<Offset> points, double height) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    if (points.length == 1) return path;

    for (var i = 0; i < points.length - 1; i++) {
      final start = points[i];
      final end = points[i + 1];
      // Outside the ends there is no neighbour, so the end point stands in for
      // one. The curve leaves the first month and arrives at the last one
      // straight, rather than curling off the edge of the plot.
      final before = i > 0 ? points[i - 1] : start;
      final after = i + 2 < points.length ? points[i + 2] : end;

      // Months run left to right, so a control point is kept inside its own
      // segment horizontally and inside the plot vertically. Without the
      // first the curve can double back on itself; without the second it can
      // leave the card.
      Offset held(Offset c) => Offset(
            c.dx.clamp(start.dx, end.dx),
            c.dy.clamp(0.0, height),
          );

      final cp1 = held(start + (end - before) * (_tension / 6));
      final cp2 = held(end - (after - start) * (_tension / 6));

      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, end.dx, end.dy);
    }
    return path;
  }

  void _dashedLine(Canvas canvas, Offset start, Offset end, Color color) {
    const dash = 4.0;
    const gap = 3.0;
    final length = (end - start).distance;
    if (length == 0) return;
    final direction = (end - start) / length;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    var current = start;
    for (var i = 0; i < (length / (dash + gap)).floor(); i++) {
      final next = current + direction * dash;
      canvas.drawLine(current, next, paint);
      current = next + direction * gap;
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) =>
      old.series != series ||
      old.maxRevenue != maxRevenue ||
      old.highlight != highlight ||
      old.grid != grid;
}

/// The key under either chart, and the three transaction indicators in one.
///
/// A swatch, the urgency, and how many payments of it that period saw. Which
/// period is whichever one the reader is pointing at, falling back to the most
/// recent — so the counts always describe the part of the chart being looked
/// at rather than a fixed one that may be off the point.
class RevenueUrgencyLegend extends StatelessWidget {
  const RevenueUrgencyLegend({
    super.key,
    required this.periods,
    required this.highlight,
  });

  final List<RevenuePeriod> periods;
  final int? highlight;

  @override
  Widget build(BuildContext context) {
    if (periods.isEmpty) return const SizedBox.shrink();
    final period =
        periods[(highlight ?? periods.length - 1).clamp(0, periods.length - 1)];
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${period.periodLabel} · '
          '${period.transactions} ${period.transactions == 1 ? 'transaction' : 'transactions'}',
          style: text.bodySmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 20,
          runSpacing: 10,
          children: [
            for (final urgency in RevenueUrgency.values)
              _LegendEntry(
                color: revenueUrgencyColor(urgency),
                label: urgency.label,
                count: period.transactionsFor(urgency),
              ),
          ],
        ),
      ],
    );
  }
}

class _LegendEntry extends StatelessWidget {
  const _LegendEntry({
    required this.color,
    required this.label,
    required this.count,
  });

  final Color color;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 7),
        Text(label.toUpperCase(),
            style: text.labelSmall?.copyWith(letterSpacing: 0.6)),
        const SizedBox(width: 6),
        Text(
          '$count',
          style: text.titleSmall?.copyWith(color: color),
        ),
      ],
    );
  }
}

/// Revenue as stacked bars — one bar per period, segmented by urgency.
///
/// The Income screen hands it years, so each bar is a whole year of platform
/// revenue and its height is that year's total. Stacked rather than grouped
/// because the question the Income screen asks is "how much did the year
/// earn", and a stack answers that with its height while still showing where
/// the money came from.
class RevenueBarChart extends StatefulWidget {
  final List<RevenuePeriod> periods;
  final double height;

  const RevenueBarChart({super.key, required this.periods, this.height = 190});

  @override
  State<RevenueBarChart> createState() => _RevenueBarChartState();
}

class _RevenueBarChartState extends State<RevenueBarChart> {
  int? _hovered;

  /// Stacked bottom-up in urgency order, so the same band is in the same place
  /// in every bar and the eye can follow one urgency across the chart.
  static const List<RevenueUrgency> _stackOrder = [
    RevenueUrgency.normal,
    RevenueUrgency.urgent,
    RevenueUrgency.emergency,
  ];

  @override
  Widget build(BuildContext context) {
    final periods = widget.periods;
    final maxRevenue = revenuePeriodMax(periods);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: widget.height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RevenueAxis(maxValue: maxRevenue, height: widget.height),
              const SizedBox(width: 8),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final slot = width / periods.length;

                    void probe(Offset local) {
                      final index =
                          (local.dx / slot).floor().clamp(0, periods.length - 1);
                      if (index != _hovered) setState(() => _hovered = index);
                    }

                    return ChartProbe(
                      onProbe: probe,
                      onClear: () {
                        if (_hovered != null) setState(() => _hovered = null);
                      },
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(child: _bars(periods, maxRevenue)),
                          ..._callout(periods, maxRevenue, slot, width),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _PeriodAxisLabels(periods: periods, highlight: _hovered),
        const SizedBox(height: 14),
        RevenueUrgencyLegend(periods: periods, highlight: _hovered),
      ],
    );
  }

  /// How wide one bar is, given the room each period has.
  ///
  /// A proportion of the slot rather than a fixed width, so two years and
  /// twelve months both look deliberate — but capped, because a single year
  /// spread across the whole card would be a block, not a bar.
  double _barWidth(double slot) => (slot * 0.55).clamp(10.0, 76.0);

  Widget _bars(List<RevenuePeriod> periods, double maxRevenue) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final slot = constraints.maxWidth / periods.length;
        final barWidth = _barWidth(slot);

        return Stack(
          children: [
            for (var i = 0; i <= 4; i++)
              Positioned(
                left: 0,
                right: 0,
                top: widget.height * i / 4,
                child: Container(height: 1, color: revenueGridColor),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < periods.length; i++)
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: SizedBox(
                        width: barWidth,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Top of the stack first, since a Column paints
                            // downwards and the highest urgency sits on top.
                            for (final urgency in _stackOrder.reversed)
                              _StackSegment(
                                height: widget.height *
                                    (maxRevenue == 0
                                        ? 0.0
                                        : (periods[i].revenueFor(urgency) / maxRevenue)
                                            .clamp(0.0, 1.0)),
                                color: revenueUrgencyColor(urgency),
                                dimmed: _hovered != null && _hovered != i,
                                isTop: urgency == _stackOrder.last,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  List<Widget> _callout(
    List<RevenuePeriod> periods,
    double maxRevenue,
    double slot,
    double width,
  ) {
    final index = _hovered;
    if (index == null) return const [];

    // Above the whole stack — its height is the period's total, which is what
    // the callout leads with.
    final fraction =
        maxRevenue == 0 ? 0.0 : (periods[index].revenue / maxRevenue).clamp(0.0, 1.0);
    final barHeight = widget.height * fraction;

    const calloutHeight = 134.0;
    final maxLeft = (width - RevenueCallout.width).clamp(0.0, double.infinity);
    final centre = slot * index + slot / 2;
    final wantedTop = widget.height - barHeight - calloutHeight;

    // The tallest bar reaches the top of the plot, leaving nothing above it to
    // put the callout in. Rather than dropping it onto the bar it is
    // describing, move it alongside — there is always room, because a bar is
    // only ever part of its slot.
    final double left;
    final double top;
    if (wantedTop >= 0) {
      left = (centre - RevenueCallout.width / 2).clamp(0.0, maxLeft);
      top = wantedTop;
    } else {
      final barEdge = _barWidth(slot) / 2 + 12;
      final toTheLeft = centre > width / 2;
      left = (toTheLeft
              ? centre - barEdge - RevenueCallout.width
              : centre + barEdge)
          .clamp(0.0, maxLeft);
      top = 0;
    }

    return [
      Positioned(
        left: left,
        top: top,
        child: IgnorePointer(
          child: RevenueCallout(
            label: periods[index].periodLabel,
            period: periods[index],
          ),
        ),
      ),
    ];
  }
}

/// One urgency's band inside a stacked bar.
class _StackSegment extends StatelessWidget {
  const _StackSegment({
    required this.height,
    required this.color,
    required this.dimmed,
    required this.isTop,
  });

  final double height;
  final Color color;

  /// Faded because another bar is being read. The whole stack dims together,
  /// so the highlighted period stands out as one thing.
  final bool dimmed;

  /// The band that caps the bar, and the only one with a rounded edge.
  final bool isTop;

  @override
  Widget build(BuildContext context) {
    // A band worth nothing is drawn as nothing rather than as a hairline that
    // reads as a small amount.
    if (height <= 0) return const SizedBox.shrink();

    return Padding(
      // The hairline gap between bands in the reference: enough to separate
      // two similar colours, not enough to break the bar into blocks.
      padding: const EdgeInsets.only(bottom: 1.5),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: dimmed ? color.withValues(alpha: 0.45) : color,
          borderRadius: isTop
              ? const BorderRadius.vertical(top: Radius.circular(3))
              : BorderRadius.zero,
        ),
      ),
    );
  }
}

/// The period names under either chart — month names on the Overview, years
/// on Income.
///
/// Twelve months do not fit across a phone, so on a narrow screen only every
/// nth label is printed — the highlighted one always is, because that is the
/// one being read. A handful of years always fit, and the same stride rule
/// leaves them all printed.
class _PeriodAxisLabels extends StatelessWidget {
  const _PeriodAxisLabels({required this.periods, required this.highlight});

  final List<RevenuePeriod> periods;
  final int? highlight;

  @override
  Widget build(BuildContext context) {
    final stride = context.layout.monthLabelStride(periods.length);

    return Row(
      children: [
        const SizedBox(width: 54),
        for (final entry in periods.asMap().entries)
          Expanded(
            child: Text(
              entry.key % stride == 0 || entry.key == highlight
                  ? entry.value.axisLabel
                  : '',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: TextStyle(
                fontSize: 11,
                color: entry.key == highlight
                    ? ConsoleColors.brand
                    : ConsoleColors.textMuted,
                fontWeight:
                    entry.key == highlight ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
      ],
    );
  }
}

/// The year's transactions as three rings — one per urgency.
///
/// Each ring reports that urgency's completed payments for the year, and its
/// arc is that count as a share of the year's payments, so the three arcs add
/// up to a full circle between them. The figure in the middle is the count
/// itself rather than the percentage: a share tells you the mix, but the
/// number of jobs is what the Income screen is being asked for.
class RevenueUrgencyRings extends StatelessWidget {
  const RevenueUrgencyRings({
    super.key,
    required this.revenue,
    required this.year,
  });

  final PlatformRevenueSummary revenue;
  final int year;

  @override
  Widget build(BuildContext context) {
    final total = revenue.transactionsForYear(year);
    // A phone shows the same three-across row, just tighter: the three rings
    // are meant to be compared with each other, and a column of three turns
    // that comparison into a scroll.
    final compact = context.layout.isPhone;

    return ConsoleResponsiveGrid(
      columns: 3,
      // Narrower gutters on a phone, because every pixel taken from between
      // the cells goes into the rings themselves.
      spacing: compact ? 8 : 16,
      children: [
        for (final urgency in RevenueUrgency.values)
          _UrgencyRing(
            urgency: urgency,
            count: revenue.transactionsForYearBy(urgency, year),
            revenue: revenue.revenueForYearBy(urgency, year),
            total: total,
            compact: compact,
          ),
      ],
    );
  }
}

class _UrgencyRing extends StatelessWidget {
  const _UrgencyRing({
    required this.urgency,
    required this.count,
    required this.revenue,
    required this.total,
    this.compact = false,
  });

  final RevenueUrgency urgency;
  final int count;
  final double revenue;
  final int total;

  /// Three rings across a phone. The ring itself needs no special case — it
  /// measures its own cell — but the words around it do: a caption that reads
  /// on one line at 300 pixels becomes four wrapped lines at 95.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = revenueUrgencyColor(urgency);
    final share = total == 0 ? 0.0 : count / total;
    final percent = '${(share * 100).toStringAsFixed(0)}%';

    return Column(
      children: [
        // The ring is measured from the cell it was given rather than fixed,
        // so it fills a wide desktop column and shrinks into a third of a
        // phone's width without a breakpoint of its own. Clamped at both ends:
        // too small to read the count at the bottom, out of proportion with
        // its own caption at the top.
        LayoutBuilder(
          builder: (context, constraints) {
            final available = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : MediaQuery.sizeOf(context).width;
            // Nearly the whole cell, since the cell is already a third of the
            // row — the gaps between the rings come from the grid's spacing,
            // not from padding inside each one.
            final diameter = (available * 0.92).clamp(56.0, 150.0);
            final stroke = (diameter * 0.078).clamp(4.0, 12.0);
            // Under about a hundred pixels there is no room for a word as well
            // as the number, and the label directly beneath the ring already
            // says what is being counted.
            final showsUnit = diameter >= 100;

            return SizedBox(
              width: diameter,
              height: diameter,
              child: CustomPaint(
                painter: _RingPainter(
                  progress: share,
                  color: color,
                  stroke: stroke,
                  track: ConsoleColors.border,
                ),
                child: Center(
                  // The figure scales with the ring, so a long count never
                  // runs into the arc around it.
                  child: SizedBox(
                    width: diameter - stroke * 2 - 10,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$count',
                            style: text.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          if (showsUnit)
                            Text(
                              count == 1 ? 'payment' : 'payments',
                              style: text.bodySmall,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        SizedBox(height: compact ? 7 : 10),
        // Scaled down rather than wrapped or clipped: EMERGENCY beside its
        // swatch is wider than a third of a small phone.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 7),
              Text(
                urgency.label.toUpperCase(),
                style: text.labelSmall?.copyWith(letterSpacing: 0.6),
              ),
            ],
          ),
        ),
        const SizedBox(height: 3),
        if (total == 0)
          Text('No payments yet', style: text.bodySmall, textAlign: TextAlign.center)
        else if (compact) ...[
          // Two short lines instead of one long one — the same two facts, in
          // the width a third of a phone actually has.
          Text(
            '$percent of the year',
            style: text.bodySmall,
            textAlign: TextAlign.center,
          ),
          Text(
            formatPeso(revenue),
            style: text.bodySmall,
            textAlign: TextAlign.center,
          ),
        ] else
          Text(
            '$percent of the year · ${formatPeso(revenue)}',
            style: text.bodySmall,
            textAlign: TextAlign.center,
          ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.color,
    required this.stroke,
    required this.track,
  });

  final double progress;
  final Color color;

  /// Scaled with the ring, so a small one keeps the same proportions rather
  /// than turning into a thick band around a tiny hole.
  final double stroke;

  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );

    canvas.drawArc(
      rect,
      0,
      3.14159265 * 2,
      false,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );

    if (progress <= 0) return;
    canvas.drawArc(
      rect,
      // From twelve o'clock, clockwise, the way a dial is read.
      -3.14159265 / 2,
      3.14159265 * 2 * progress.clamp(0.0, 1.0),
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.stroke != stroke ||
      old.track != track;
}

/// What the revenue screens show before a single payment has been reported.
class RevenueEmptyChart extends StatelessWidget {
  final double height;
  final String message;

  const RevenueEmptyChart({
    super.key,
    this.height = 170,
    this.message = 'No payments reported yet.',
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.show_chart, size: 26, color: ConsoleColors.textMuted),
            const SizedBox(height: 10),
            Text(message, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// The line under the revenue tiles explaining where the number comes from.
String revenueSourceNote(int year) =>
    'Booked from client payments the mobile app reports. Since Jan $year.';

/// Formats a year-on-year comparison, or says there is nothing to compare to
/// yet — never a stand-in percentage.
({String label, bool positive})? revenueTrend({
  required double thisYear,
  required double lastYear,
  required int year,
}) {
  if (lastYear <= 0) return null;
  final change = (thisYear - lastYear) / lastYear * 100;
  return (
    label: '${change >= 0 ? '+' : ''}${change.toStringAsFixed(0)}% vs ${year - 1}',
    positive: change >= 0,
  );
}

/// Peso formatting, re-exported here so a chart caller needs one import.
String formatChartPeso(double value) => formatPeso(value);
