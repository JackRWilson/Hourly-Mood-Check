import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/mood_entry.dart';
import '../constants/mood_scale.dart';

// This widget takes a list of mood entries and draws a line chart.
// It's a StatelessWidget because it doesn't manage any state itself —
// it just takes data and draws it. Like a pure function in Python.
class MoodChart extends StatelessWidget {
  final List<MoodEntry> entries;

  const MoodChart({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    // If there are no entries, show a friendly empty state
    // instead of an empty chart
    if (entries.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'No entries yet today',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return SizedBox(
      height: 220,
      child: Padding(
        // Padding adds space around the chart so axis labels aren't cut off
        padding: const EdgeInsets.only(right: 24, left: 8, top: 16, bottom: 8),
        child: LineChart(
          LineChartData(
            // Y axis range: -3 to +3
            minY: -3,
            maxY: 3,
            // X axis range: 0 to 24 hours
            minX: 0,
            maxX: 24,

            // Grid lines — horizontal only, one per mood score level
            gridData: FlGridData(
              drawHorizontalLine: true,
              horizontalInterval: 1,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (value) => FlLine(
                color: value == 0
                    ? Colors.grey.shade400  // Zero line is darker
                    : Colors.grey.shade200,
                strokeWidth: value == 0 ? 1.5 : 0.8,
              ),
            ),

            // Axis titles and labels
            titlesData: FlTitlesData(
              // Left axis — mood score labels
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  reservedSize: 30,
                  // For each value on the Y axis, show the number
                  getTitlesWidget: (value, meta) {
                    if (value != value.roundToDouble()) return const SizedBox();
                    return Text(
                      value.toInt().toString(),
                      style: const TextStyle(fontSize: 10),
                    );
                  },
                ),
              ),
              // Bottom axis — hour labels
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 3, // Show a label every 3 hours
                  getTitlesWidget: (value, meta) {
                    if (value != value.roundToDouble()) return const SizedBox();
                    final hour = value.toInt();
                    if (hour > 24) return const SizedBox();
                    // Format as "9a" or "3p" style
                    if (hour == 0 || hour == 24) return const Text('12a', style: TextStyle(fontSize: 9));
                    if (hour == 12) return const Text('12p', style: TextStyle(fontSize: 9));
                    return Text(
                      hour < 12 ? '${hour}a' : '${hour - 12}p',
                      style: const TextStyle(fontSize: 9),
                    );
                  },
                ),
              ),
              // Hide the right and top axis labels — we don't need them
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),

            // The border around the chart area
            borderData: FlBorderData(
              show: true,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300),
                left: BorderSide(color: Colors.grey.shade300),
              ),
            ),

            // Touch interaction — when user taps a point, show a tooltip
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    final score = spot.y.toInt();
                    return LineTooltipItem(
                      MoodScale.labelForScore(score),
                      TextStyle(
                        color: MoodScale.colorForScore(score),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    );
                  }).toList();
                },
              ),
            ),

            // The actual line data
            lineBarsData: [
              LineChartBarData(
                // Convert each MoodEntry into a chart point (x, y)
                // x = hour of day (as decimal, so 9:30 = 9.5)
                // y = mood score
                // This is like a list comprehension in Python:
                // [(entry.timestamp.hour + min/60, entry.moodScore) for entry in entries]
                spots: entries.map((entry) {
                  final x = entry.timestamp.hour +
                      (entry.timestamp.minute / 60.0);
                  return FlSpot(x, entry.moodScore.toDouble());
                }).toList(),

                isCurved: true,         // Smooth curve instead of sharp angles
                curveSmoothness: 0.3,
                color: Colors.indigo,
                barWidth: 2.5,

                // The dots on each data point
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, bar, index) {
                    return FlDotCirclePainter(
                      radius: 4,
                      color: MoodScale.colorForScore(spot.y.toInt()),
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    );
                  },
                ),

                // Shading below the line
                belowBarData: BarAreaData(
                  show: true,
                  color: Colors.indigo.withOpacity(0.08),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}