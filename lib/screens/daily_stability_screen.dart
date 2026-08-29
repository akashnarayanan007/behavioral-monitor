import 'package:flutter/material.dart';
import '../database/database_service.dart';
import '../analysis/daily_score.dart';
import '../services/llm_service.dart';
import '../analysis/mental_state_service.dart';

class DailyStabilityScreen extends StatefulWidget {
  const DailyStabilityScreen({super.key});

  @override
  State<DailyStabilityScreen> createState() => _DailyStabilityScreenState();
}

class _DailyStabilityScreenState extends State<DailyStabilityScreen> {
  List<Map<String, dynamic>> dailyData = [];
  bool isLoading = true;
  bool isReversed = false; // Default: Newest First (DESC from DB)

  @override
  void initState() {
    super.initState();
    _loadDailyData();
  }

  Future<void> _loadDailyData() async {
    final data = await DatabaseService.getLast10();
    setState(() {
      dailyData = List<Map<String, dynamic>>.from(data);
      isLoading = false;
    });

    // Process AI Interpretation for the latest entry if missing
    if (dailyData.isNotEmpty) {
      final latestEntry = dailyData.first;
      if (latestEntry['ai_interpretation'] == null || latestEntry['ai_interpretation'].toString().isEmpty) {
        _generateAIInterpretation(latestEntry);
      }
    }
  }

  Future<void> _generateAIInterpretation(Map<String, dynamic> entry) async {
    final double score = DailyScore.compute(entry);
    final mentalState = MentalStateService.computeMentalState(entry);

    final String contextString = MentalStateService.generateStabilitySummary(
      stabilityIndex: score,
      latestEntry: entry,
      trend: "stable",
    );

    final String prompt = "Please provide a 1-2 sentence plain-language interpretation of my stability score of ${score.toStringAsFixed(1)}/10 today. $contextString";

    try {
      final response = await LLMService.sendChatMessage(
        userMessage: prompt,
        history: [],
      );

      final String interpretation = response.replyText;

      // Save to database
      await DatabaseService.updateAIInterpretation(entry['id'], interpretation);

      // Update local state to reflect change without full reload
      if (mounted) {
        setState(() {
          int index = dailyData.indexWhere((element) => element['id'] == entry['id']);
          if (index != -1) {
            final updatedEntry = Map<String, dynamic>.from(dailyData[index]);
            updatedEntry['ai_interpretation'] = interpretation;
            dailyData[index] = updatedEntry;
          }
        });
      }
    } catch (e) {
      debugPrint("Error generating AI interpretation: $e");
    }
  }

  Color _getScoreColor(double score) {
    if (score >= 7.5) return Colors.green;
    if (score >= 5.0) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> displayData = isReversed 
        ? dailyData.reversed.toList() 
        : dailyData;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Daily Stability Score"),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_vert),
            tooltip: isReversed ? "Newest First" : "Oldest First",
            onPressed: () {
              setState(() {
                isReversed = !isReversed;
              });
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : dailyData.isEmpty
              ? const Center(child: Text("No data available"))
              : Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      color: Colors.blue.withOpacity(0.05),
                      child: const Text(
                        "Your data stays on your device and is never uploaded.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.blueGrey,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: displayData.length,
                        itemBuilder: (context, index) {
                          final entry = displayData[index];
                          final score = DailyScore.compute(entry);
                          final color = _getScoreColor(score);
                          final date = entry['date'] ?? "Entry ${dailyData.length - index}";
                          final aiInterpretation = entry['ai_interpretation'] as String?;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(date, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: color.withOpacity(0.5)),
                                        ),
                                        child: Text(
                                          score.toStringAsFixed(1),
                                          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  const Text("AI Interpretation", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueGrey)),
                                  const SizedBox(height: 4),
                                  if (aiInterpretation != null && aiInterpretation.isNotEmpty)
                                    Text(
                                      aiInterpretation,
                                      style: const TextStyle(fontSize: 14, height: 1.4, color: Colors.black87),
                                    )
                                  else if (index == 0 && !isReversed) // Only show loading for the latest entry being processed
                                    const Row(
                                      children: [
                                        SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                                        SizedBox(width: 10),
                                        Text("Generating insight...", style: TextStyle(fontSize: 12, color: Colors.grey)),
                                      ],
                                    )
                                  else
                                    const Text("No interpretation available.", style: TextStyle(fontSize: 14, color: Colors.grey, fontStyle: FontStyle.italic)),
                                  const SizedBox(height: 16),
                                  const Text("Key Suggestions", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blue)),
                                  const SizedBox(height: 4),
                                  const Text("• Maintain 7-9h consistent sleep\n• Reduce digital exposure before rest\n• Keep a stable workout routine", style: TextStyle(fontSize: 13, height: 1.5, color: Colors.black54)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  ],
                ),
    );
  }
}