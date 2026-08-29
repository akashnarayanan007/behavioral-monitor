import 'daily_score.dart';
import '../database/database_service.dart';
import 'hankel_matrix.dart';
import 'dmd_analysis.dart';

class MentalStateService {
  /// Computes Stress, Anxiety, and Depression levels (0-100)
  /// based on 10 behavioral attributes.
  static Map<String, double> computeMentalState(Map<String, dynamic> data) {
    try {
      final breakdown = DailyScore.computeWithBreakdown(data);
      final scores = breakdown['intermediateScores'] as Map<String, dynamic>? ?? {};
      final inputs = (breakdown['inputs'] as Map<String, dynamic>?) ?? data;

      // 1. Stress Score (0-100)
      double stress = 0;
      stress += (1.0 - (scores['sleepScore'] ?? 0.0)) * 30;
      stress += (1.0 - (scores['screenScore'] ?? 0.0)) * 25;
      stress += (1.0 - (scores['productiveScore'] ?? 0.0)) * 20;
      stress += (1.0 - (scores['routineScore'] ?? 0.0)) * 25;
      
      // 2. Anxiety Score (0-100)
      double anxiety = 0;
      anxiety += (1.0 - (scores['screenScore'] ?? 0.0)) * 35;
      anxiety += (1.0 - (scores['routineScore'] ?? 0.0)) * 30;
      anxiety += (1.0 - (scores['phoneScore'] ?? 0.0)) * 35;

      // 3. Depression Score (0-100)
      double depression = 0;
      depression += (1.0 - (scores['workoutScore'] ?? 0.0)) * 30;
      depression += (1.0 - (scores['foodScore'] ?? 0.0)) * 20;
      depression += (1.0 - (scores['mealScore'] ?? 0.0)) * 25;
      
      double phone = ((inputs['calls'] ?? 0) as num).toDouble() / 10.0;
      double socialWithdrawal = (1.0 - phone).clamp(0.0, 1.0);
      depression += socialWithdrawal * 25;

      return {
        'Stress': stress.clamp(0.0, 100.0),
        'Anxiety': anxiety.clamp(0.0, 100.0),
        'Depression': depression.clamp(0.0, 100.0),
      };
    } catch (e) {
      return {
        'Stress': 0.0,
        'Anxiety': 0.0,
        'Depression': 0.0,
      };
    }
  }

  static String getLevel(double score) {
    if (score <= 20) return "Normal";
    if (score <= 40) return "Mild";
    if (score <= 60) return "Moderate";
    if (score <= 80) return "Severe";
    return "Extremely Severe";
  }

  /// Generates a factual summary of recent behavioral trends including raw values.
  static String generateStabilitySummary({
    required double stabilityIndex,
    required Map<String, dynamic> latestEntry,
    required String trend,
  }) {
    if (latestEntry.isEmpty) return "No recent behavioral data available.";

    final sleep = (latestEntry['sleep'] ?? 0).toString();
    final workout = (latestEntry['workout'] ?? 0);
    final screen = (latestEntry['screenTime'] ?? 0).toString();
    final calls = latestEntry['calls'] ?? 0;
    final food = latestEntry['food'] ?? 2;
    final work = latestEntry['work'] ?? 0;
    final study = latestEntry['study'] ?? 0;
    final productivityValue = (work as num) + (study as num);

    String workoutStr = (workout as num) > 0 ? "$workout minutes" : "No";
    String socialLevel = (calls as num) > 15 ? "High" : (calls >= 5 ? "Balanced" : "Low");
    String nutritionLevel = food == 3 ? "Healthy" : (food == 2 ? "Moderate" : "Unhealthy");
    String productivityLevel = productivityValue >= 8 ? "High" : (productivityValue >= 4 ? "Moderate" : "Low");

    return "Recent data (last entry): "
        "Sleep: $sleep hours, "
        "Workout: $workoutStr, "
        "Digital exposure: $screen hours, "
        "Social interaction: $socialLevel, "
        "Nutrition: $nutritionLevel, "
        "Productivity: $productivityLevel. "
        "Computed Stability Index: ${stabilityIndex.toStringAsFixed(1)}/10, "
        "trending $trend.";
  }

  /// Generates a short template-based summary of the chat session.
  static String generateSessionSummary(String category, List<String> assistantReplies) {
    final String topic = category.replaceAll('_', ' ').toLowerCase();
    return "You discussed $topic concerns. The assistant provided personalized guidance and matched you with relevant support resources.";
  }

  /// Generates a structured behavioral health report for a specific range.
  static Future<Map<String, dynamic>> generateHealthReport(int? dayRange) async {
    final allData = await DatabaseService.getLast10();
    final int totalAvailable = allData.length;
    if (totalAvailable == 0) return {'error': 'No data available'};

    // BRANCH A: Single Day (Requested null/0/1, or only 1 day available)
    if (dayRange == null || dayRange <= 1 || totalAvailable == 1) {
      final int index = (dayRange == 1 && totalAvailable > 1) ? 1 : 0;
      final targetEntry = allData[index];
      final breakdown = DailyScore.computeWithBreakdown(targetEntry);

      return {
        'type': 'single_day',
        'requestedRange': dayRange,
        'actualDayCount': 1,
        'date': targetEntry['date'] ?? (index == 0 ? 'Today' : 'Yesterday'),
        'rawInputs': {
          'sleep': targetEntry['sleep'],
          'screenTime': targetEntry['screenTime'],
          'productivity': (targetEntry['work'] ?? 0.0) + (targetEntry['study'] ?? 0.0),
          'calls': targetEntry['calls'],
          'workout': targetEntry['workout'],
        },
        'stabilityScore': breakdown['finalScore'],
        'mentalState': computeMentalState(targetEntry),
      };
    }

    // BRANCH B: Multi-Day Analysis
    int requested = dayRange ?? 7;
    int limit = requested.clamp(2, 10);
    if (limit > totalAvailable) {
      limit = totalAvailable; // Use the actual number of available days
    }

    final rangeData = allData.take(limit).toList().reversed.toList();
    List<double> scores = rangeData.map((e) => DailyScore.compute(e)).toList();
    double avgStability = scores.reduce((a, b) => a + b) / scores.length;

    double totalStress = 0, totalAnxiety = 0, totalDepression = 0;
    for (var entry in rangeData) {
      final states = computeMentalState(entry);
      totalStress += states['Stress'] ?? 0;
      totalAnxiety += states['Anxiety'] ?? 0;
      totalDepression += states['Depression'] ?? 0;
    }

    double stabilityFactor = 1.0;
    if (scores.length >= 3) {
      final vectors = scores.map((s) => [s]).toList();
      final hankel = HankelMatrix.buildHankel(vectors);
      final variation = DMDAnalysis.computeStability(hankel);
      stabilityFactor = (1.0 - (variation / 10.0)).clamp(0.5, 1.0);
    }

    return {
      'type': 'multi_day',
      'dayRange': limit,
      'confidence': limit >= 5 ? 'high' : 'low',
      'stabilityTrend': {
        'average': avgStability,
        'systemStabilityFactor': stabilityFactor,
        'isImproving': scores.last >= scores.first,
      },
      'mentalStateTrend': {
        'avgStress': totalStress / limit,
        'avgAnxiety': totalAnxiety / limit,
        'avgDepression': totalDepression / limit,
      },
      'rawDailyScores': scores,
    };
  }
}
