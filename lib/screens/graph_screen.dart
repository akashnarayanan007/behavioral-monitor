import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import '../database/database_service.dart';
import '../analysis/daily_score.dart';
import '../services/llm_service.dart';

class GraphScreen extends StatefulWidget {
  final List<FlSpot>? graphPoints;

  const GraphScreen({super.key, this.graphPoints});

  @override
  State<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends State<GraphScreen> {
  List<FlSpot> points = [];
  List<FlSpot> trendLinePoints = [];
  bool isLoading = true;
  String narrativeSummary = "";
  bool isNarrativeLoading = true;

  double mean = 0;
  double stdDev = 0;
  double trendSlope = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Fetch last 14 days for broader trend analysis
    final data = await DatabaseService.getRecentEntries(14);
    final chronologicalData = data.reversed.toList();
    
    List<FlSpot> loadedPoints = [];
    for (int i = 0; i < chronologicalData.length; i++) {
      final entry = chronologicalData[i];
      double score = DailyScore.compute(entry);
      loadedPoints.add(FlSpot(i.toDouble(), score));
    }

    if (loadedPoints.length >= 2) {
      List<double> scores = loadedPoints.map((p) => p.y).toList();
      mean = scores.reduce((a, b) => a + b) / scores.length;
      double variance = scores.map((x) => pow(x - mean, 2)).reduce((a, b) => a + b) / scores.length;
      stdDev = sqrt(variance);

      List<FlSpot> trendPoints = [];
      for (int i = 0; i < loadedPoints.length; i++) {
        double sum = 0;
        int count = 0;
        for (int j = i - 2; j <= i; j++) {
          if (j >= 0) {
            sum += loadedPoints[j].y;
            count++;
          }
        }
        trendPoints.add(FlSpot(i.toDouble(), sum / count));
      }

      if (trendPoints.length >= 2) {
        trendSlope = (trendPoints.last.y - trendPoints.first.y) / (trendPoints.length - 1);
      }
      
      trendLinePoints = trendPoints;
    }

    setState(() {
      points = loadedPoints;
      isLoading = false;
    });

    if (data.isNotEmpty) {
      _fetchNarrativeSummary(data);
    }
  }

  Future<void> _fetchNarrativeSummary(List<Map<String, dynamic>> rawData) async {
    String dataSummary = rawData.reversed.map((d) {
      final score = DailyScore.compute(d).toStringAsFixed(1);
      return "Date: ${d['date'] ?? 'N/A'}, Score: $score/10, Sleep: ${d['sleep']}h, Screen: ${d['screenTime']}h";
    }).join("\n");

    final String prompt = """
    Please provide a 2-3 sentence narrative summary of my behavioral stability trend based on these 14-day logs:
    $dataSummary
    
    Explain the trend simply (improving, declining, or stable). 
    If there are sharp drops, mention which logs they coincide with and highlight likely causes like sleep or screen time.
    """;

    try {
      final response = await LLMService.sendChatMessage(
        userMessage: prompt,
        history: [],
      );
      if (mounted) {
        setState(() {
          narrativeSummary = response.replyText;
          isNarrativeLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          narrativeSummary = "Trend narrative is currently unavailable.";
          isNarrativeLoading = false;
        });
      }
    }
  }

  String _generateClinicalReport() {
    if (points.length < 5) {
      return "Insufficient data for clinical trend analysis. A minimum of 5 longitudinal observations is required to establish a reliable behavioral trajectory.";
    }

    String trendDescription = trendSlope > 0.1 
        ? "an upward (improving) stability trajectory" 
        : trendSlope < -0.1 
            ? "a downward (declining) stability trajectory" 
            : "a relatively stable baseline";

    String consistency = stdDev > 1.5 
        ? "significant behavioral variability" 
        : "high consistency";

    String report = "Clinical Observation:\n";
    report += "The longitudinal assessment indicates $trendDescription. ";
    report += "Analysis of standard deviation (σ = ${stdDev.toStringAsFixed(2)}) reflects $consistency. ";

    return report;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Stability Trend Analysis"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : points.isEmpty
              ? const Center(child: Text("No clinical data available"))
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Behavioral Stability Index",
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const Text(
                          "Longitudinal monitoring of behavioral trajectory",
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 30),
                        
                        SizedBox(
                          height: 350,
                          child: LineChart(
                            LineChartData(
                              minY: 0,
                              maxY: 10,
                              minX: 0,
                              maxX: points.length.toDouble() - 1,
                              lineTouchData: const LineTouchData(enabled: true),
                              gridData: const FlGridData(show: true, drawVerticalLine: false),
                              titlesData: FlTitlesData(
                                show: true,
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) => Text("T-${(points.length - 1 - value.toInt())}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                  ),
                                ),
                                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 2, reservedSize: 30)),
                              ),
                              borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.withOpacity(0.2))),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: points,
                                  isCurved: true,
                                  barWidth: 3,
                                  gradient: const LinearGradient(colors: [Colors.blue, Colors.blueAccent]),
                                  dotData: const FlDotData(show: true),
                                ),
                                if (trendLinePoints.isNotEmpty)
                                  LineChartBarData(
                                    spots: trendLinePoints,
                                    isCurved: true,
                                    barWidth: 2,
                                    color: Colors.orange.withOpacity(0.6),
                                    dotData: const FlDotData(show: false),
                                    dashArray: [5, 5],
                                  ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 30),
                        _buildLegend(),
                        
                        const SizedBox(height: 30),
                        _buildReportSection(
                          "AI Narrative Summary",
                          Icons.auto_awesome,
                          Colors.indigo,
                          isNarrativeLoading
                            ? const Center(child: Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2)))
                            : Text(narrativeSummary, style: const TextStyle(fontSize: 14, height: 1.5, fontStyle: FontStyle.italic)),
                        ),
                        
                        const SizedBox(height: 20),
                        _buildClinicalReportCard(),
                        
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildReportSection(String title, IconData icon, Color color, Widget content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          const Divider(height: 25),
          content,
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendItem(Colors.blue, "Stability Index"),
        const SizedBox(width: 20),
        _legendItem(Colors.orange.withOpacity(0.6), "Trend Line", isDash: true),
      ],
    );
  }

  Widget _legendItem(Color color, String label, {bool isDash = false}) {
    return Row(
      children: [
        Container(width: 16, height: 3, color: isDash ? null : color),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black87)),
      ],
    );
  }

  Widget _buildClinicalReportCard() {
    return _buildReportSection(
      "Statistical Insights",
      Icons.analytics_outlined,
      Colors.blueGrey,
      Text(_generateClinicalReport(), style: const TextStyle(fontSize: 14, height: 1.5)),
    );
  }
}
