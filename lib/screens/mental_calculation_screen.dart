import 'package:flutter/material.dart';
import '../database/database_service.dart';
import '../analysis/hankel_matrix.dart';
import '../analysis/dmd_analysis.dart';
import '../analysis/daily_score.dart';
import '../services/llm_service.dart';
import '../analysis/mental_state_service.dart';

class MentalCalculationScreen extends StatefulWidget {
  const MentalCalculationScreen({super.key});

  @override
  State<MentalCalculationScreen> createState() => _MentalCalculationScreenState();
}

class _MentalCalculationScreenState extends State<MentalCalculationScreen> {
  List<double> dailyScores = [];
  List<List<double>> hankelMatrix = [];
  double variation = 0;
  double mentalHealthScore = 0;
  bool isLoading = true;
  String plainLanguageExplanation = "";
  bool isExplaining = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await DatabaseService.getLast10();
    if (data.isNotEmpty) {
      final chronologicalData = data.reversed.toList();
      List<double> scores = chronologicalData.map((e) => DailyScore.compute(e)).toList();

      List<List<double>> hankel = [];
      double v = 0;
      double mhScore = 0;

      if (scores.length >= 3) {
        List<List<double>> scoreVectors = scores.map((s) => [s]).toList();
        hankel = HankelMatrix.buildHankel(scoreVectors);
        v = DMDAnalysis.computeStability(hankel);
        
        int n = scores.length;
        double s1 = scores[n - 3];
        double s2 = scores[n - 2];
        double s3 = scores[n - 1];
        
        double weightedAvg = (s1 * 0.2) + (s2 * 0.3) + (s3 * 0.5);
        double trendFactor = (s3 - s1) * 0.15;
        
        mhScore = (weightedAvg + trendFactor).clamp(0.0, 10.0);
      }

      setState(() {
        dailyScores = scores;
        hankelMatrix = hankel;
        variation = v;
        mentalHealthScore = mhScore;
        isLoading = false;
      });

      if (scores.length >= 3) {
        _fetchPlainLanguageExplanation(mhScore, v);
      }
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _fetchPlainLanguageExplanation(double score, double varVal) async {
    final double eigenvalue = (1.0 - (varVal / 10)).clamp(0.0, 1.0);
    
    final String prompt = """
Please explain my mental health calculation results to me in 2-3 simple sentences.
My current Stability Index is ${score.toStringAsFixed(1)}/10.
The system eigenvalue (which measures how consistent my routine is) is ${eigenvalue.toStringAsFixed(4)}.
Translate these math terms into what they mean for my actual life and wellness. 
Do not use technical jargon.
""";

    try {
      final response = await LLMService.sendChatMessage(
        userMessage: prompt,
        history: [],
      );

      if (mounted) {
        setState(() {
          plainLanguageExplanation = response.replyText;
          isExplaining = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          plainLanguageExplanation = "Unable to generate explanation at this time.";
          isExplaining = false;
        });
      }
    }
  }

  Widget _buildSection(String title, Widget content) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            const Divider(),
            const SizedBox(height: 8),
            content,
          ],
        ),
      ),
    );
  }

  String _formatMatrix(List<List<double>> matrix) {
    if (matrix.isEmpty) return "Empty Matrix";
    return matrix.map((row) => "[ ${row.map((e) => e.toStringAsFixed(2).padLeft(6)).join(', ')} ]").join('\n');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mental Health Calculation")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : dailyScores.isEmpty
              ? const Center(child: Text("No data available"))
              : dailyScores.length < 3
                  ? const Center(child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text("Insufficient data for advanced analysis. Please log at least 3 entries.", textAlign: TextAlign.center),
                    ))
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildSection(
                            "1. Time Series of Daily Scores",
                            Text("Chronological score sequence:\n\n[ ${dailyScores.map((s) => s.toStringAsFixed(2)).join(', ')} ]"),
                          ),
                          _buildSection(
                            "2. Hankel Matrix Formation",
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Text(
                                _formatMatrix(hankelMatrix),
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                              ),
                            ),
                          ),
                          _buildSection(
                            "3. DMD Calculation & Snapshots",
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("The series is decomposed into two snapshots:"),
                                Text("X1: Snapshots at t=1 to n-1"),
                                Text("X2: Snapshots at t=2 to n"),
                                SizedBox(height: 8),
                                Text("Formula: X2 ≈ A × X1", style: TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          _buildSection(
                            "4. System Matrix (A)",
                            const Text("Matrix 'A' represents the linear operator that maps the current behavioral state to the next. The stability of 'A' determines the mental health trajectory."),
                          ),
                          _buildSection(
                            "5. Eigenvalues (λ)",
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("The magnitude |λ| is derived from the system variation:"),
                                const SizedBox(height: 8),
                                Text("|λ| ≈ ${(1.0 - (variation/10)).toStringAsFixed(4)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.purple)),
                              ],
                            ),
                          ),
                          _buildSection(
                            "6. Final Mental Health Score",
                            Center(
                              child: Text(
                                "${mentalHealthScore.toStringAsFixed(1)} / 10",
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
                              ),
                            ),
                          ),
                          _buildSection(
                            "7. Plain Language Explanation",
                            isExplaining
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(20.0),
                                      child: Column(
                                        children: [
                                          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                                          SizedBox(height: 10),
                                          Text("AI is translating math to English...", style: TextStyle(fontSize: 12, color: Colors.grey)),
                                        ],
                                      ),
                                    ),
                                  )
                                : Text(
                                    plainLanguageExplanation,
                                    style: const TextStyle(fontSize: 15, height: 1.5, fontStyle: FontStyle.italic),
                                  ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
    );
  }
}
