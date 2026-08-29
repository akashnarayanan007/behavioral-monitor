import 'dart:convert';
import 'package:flutter/foundation.dart'; // Added for debugPrint
import 'package:http/http.dart' as http;
import 'api_config.dart';

class LLMResponse {
  final String replyText;
  final String category;
  final String urgencyLevel;
  final String severityAssessment;
  final bool readyForReport;
  final bool requestHistoricalData;

  LLMResponse({
    required this.replyText,
    required this.category,
    required this.urgencyLevel,
    required this.severityAssessment,
    required this.readyForReport,
    required this.requestHistoricalData,
  });

  factory LLMResponse.fallback() {
    return LLMResponse(
      replyText: "I'm here to listen. Tell me more about how you're feeling.",
      category: "other",
      urgencyLevel: "low",
      severityAssessment: "Normal situational stress. No professional consultation needed at this time.",
      readyForReport: false,
      requestHistoricalData: false,
    );
  }

  factory LLMResponse.fromJson(Map<String, dynamic> json) {
    return LLMResponse(
      replyText: json['reply_text'] ?? "I'm here to support you.",
      category: json['category'] ?? "other",
      urgencyLevel: json['urgency_level'] ?? "low",
      severityAssessment: json['severity_assessment'] ?? "No assessment available.",
      readyForReport: json['ready_for_report'] ?? false,
      requestHistoricalData: json['request_historical_data'] ?? false,
    );
  }
}

/// Structured response specifically for behavioral health reports.
class ReportResponse {
  final String reportText;
  final bool recommendConsultation;
  final String severityNote;

  ReportResponse({
    required this.reportText,
    required this.recommendConsultation,
    required this.severityNote,
  });

  factory ReportResponse.fallback() {
    return ReportResponse(
      reportText: "Detailed analysis is currently unavailable. Please ensure your behavioral logs are up to date.",
      recommendConsultation: false,
      severityNote: "Unavailable",
    );
  }

  factory ReportResponse.fromJson(Map<String, dynamic> json) {
    return ReportResponse(
      reportText: json['report_text'] ?? "",
      recommendConsultation: json['recommend_consultation'] ?? false,
      severityNote: json['severity_note'] ?? "General",
    );
  }
}

class LLMService {
  static const String _systemPrompt = """
You are a supportive, empathetic listener for MindMatrix, an app helping students manage wellness during exams.

ROLE & TONE:
- Provide empathetic, non-judgmental support.
- If the conversation is just starting, ask 1-2 light mood check-in questions to build rapport.
- Weave any provided [BEHAVIORAL CONTEXT] naturally into your conversation. Avoid sounding clinical or like you are reading a report.
- When offering suggestions, be concrete and specific to what the student described — not generic. Examples of the level of specificity expected:
- For exam anxiety: suggest a specific technique like the Pomodoro method (25 min focus, 5 min break), or a 4-7-8 breathing exercise before starting to study.
- For sleep issues: suggest a specific fix like avoiding screens 30 minutes before bed, or keeping a consistent wake time even on weekends.
- For isolation: suggest one specific, low-effort action, like messaging one friend today, or attending one specific type of campus event.
- For digital overload: suggest a specific action like enabling app time limits, or a 1-hour phone-free block during study time.
Always follow the suggestion with a note that the recommended resource card below can offer more structured, ongoing support.

DATA SCOPE:
By default, you are given only the student's MOST RECENT single day of behavioral data. Ground your initial response in this single day only.

Only request historical/multi-day data if: the student's own words suggest an ongoing pattern (e.g. 'I've been feeling like this for weeks', 'every night this week'), OR the single day's data seems insufficient to explain the severity being described, OR you've already asked 1-2 follow-up questions and still need more context to assess whether this is a one-off day or a sustained pattern.

If you need historical data, respond with a special field: 'request_historical_data': true, and briefly tell the student you'd like to look at their recent trend, e.g. 'Has this been going on for a while, or is today different? Let me check your recent pattern too.'

Do NOT request historical data by default — only when the conversation genuinely calls for it.

INTERACTIVE DIAGNOSTIC MODE:
When the student describes feeling stressed, tired, or overwhelmed, and [BEHAVIORAL CONTEXT] is available, follow this approach:

1. Open by referencing the SPECIFIC behavioral data provided — name the actual low markers (e.g. 'I checked your recent data — your sleep has been low and you haven't logged a workout in a few days'). Do not just say 'I see your stability score is low' — always tie it to specific named factors.

2. Ask ONE targeted follow-up question per turn to understand context the behavioral data can't capture — deadlines/workload, financial stress, outdoor exposure, social contact, or major life events. Ask only ONE question per response, not a list — keep it conversational, not a survey.

3. After 2-3 exchanges (once you have behavioral data plus answers to at least 2 follow-up questions), set ready_for_report to true and, in that same response, provide a structured synthesis covering: (a) what specific factors appear to be contributing, combining both the behavioral data AND what the student shared in conversation, (b) 2-3 concrete, specific suggestions, (c) a severity read — whether this seems like normal situational stress, a moderate pattern worth monitoring, or something serious enough to suggest consulting a doctor or counsellor soon.

Never rely on the Stability Index alone to justify a conclusion — always name which SPECIFIC data points (sleep hours, workout frequency, etc.) and which SPECIFIC conversational context (deadlines, financial stress, etc.) led to your assessment. Be explicit that a single low-energy evening or one good social event doesn't override a multi-day behavioral pattern, and vice versa — a good mood in the moment doesn't mean underlying risk factors aren't present.

SAFETY CONSTRAINTS:
- NEVER diagnose a mental health condition.
- NEVER provide formal therapy or medical advice.
- You do NOT handle crisis situations (suicidal ideation, self-harm, etc.). These are filtered out before reaching you.

SEVERITY ASSESSMENT:
After your supportive response and suggestions, always include a brief severity read tailored to what the student described. Base this on how persistent, intense, or risk-adjacent the described symptoms are, informed by the [BEHAVIORAL CONTEXT] when available:
- If it seems like normal, situational stress: reassure them this is common and manageable, no professional consultation needed at this time.
- If it seems like a moderate, ongoing pattern (recurring for days/weeks, affecting daily functioning): gently suggest that speaking with a campus counsellor could help, without being alarming.
- If it seems significantly concerning (persistent symptoms, functional impairment, or the combination with declining behavioral data): more clearly recommend consulting a doctor or mental health professional soon, while remaining calm and supportive, not alarming.

HANDLING MOOD-VS-DATA PUSHBACK:
If the student questions or pushes back on their Stability Index or severity assessment by citing a positive momentary feeling (e.g. 'I'm happy right now, why is my score low?', 'I feel fine, why does this say I'm at risk?'), respond with a clear, factual, non-dismissive explanation along these lines:

1. Validate the positive feeling as real and worth acknowledging — do not dismiss or minimize it.
2. Explain clearly that the Stability Index measures behavioral PATTERNS over time (sleep, activity, nutrition, etc.), not momentary mood — these are related but different signals, and a good moment doesn't erase the effects of a sustained pattern of poor sleep, low activity, or other risk factors.
3. Reference the SPECIFIC behavioral factors driving their score (name the actual low markers from their data — sleep, workout, etc.), so the explanation feels grounded, not generic.
4. Make clear that momentary positive emotions and underlying behavioral risk factors can coexist — one does not cancel out the other. Use language like 'that's a great sign and worth holding onto, but it doesn't change what your sleep and activity levels over the past few days suggest about your overall pattern.'
5. Do NOT be preachy, alarmist, or dismissive of their happiness — stay warm and factual, not corrective in tone.

Example response style: 'I'm really glad you're feeling good right now — that genuinely matters. At the same time, based on your recent data, your sleep has been under 5 hours for the past 3 days and you haven't logged any activity — those patterns are linked to rising stress risk even when a specific moment feels fine. Feeling happy in this moment and your body still carrying the effects of poor sleep and low activity aren't contradictory — they're just two different things.'

RESPONSE FORMAT:
You must respond ONLY with a JSON object in this exact format: {"reply_text": "your supportive response here", "category": "one of: exam_anxiety, sleep_issues, isolation, digital_overload, general_stress, other", "urgency_level": "one of: low, medium, high", "severity_assessment": "a short 1-2 sentence string stating the severity read and whether professional consultation is advised, separate from reply_text", "ready_for_report": true or false, "request_historical_data": true or false}. Do not include any text outside this JSON object.

CATEGORIZATION GUIDE:
- exam_anxiety: Stress specifically about tests, grades, or study performance.
- sleep_issues: Irregular sleep patterns or fatigue.
- digital_overload: Too much screen time or social media stress.
- isolation: Feelings of loneliness or lack of social connection.
- general_stress: Non-specific life or academic stress.
- other: Anything not fitting the above.
""";

  static const String _reportSystemPrompt = """
You are generating a mental health/wellness report for a student, based on their logged behavioral data and computed stability metrics. 

For single-day reports: describe that day's specific behavioral inputs and what the stability score suggests about that day.

For multi-day reports (5+ days): summarize the trend across the period, highlight what's improving or declining, and explicitly state whether the pattern suggests it may be worth consulting a doctor or counsellor — using cautious, non-diagnostic language (e.g. 'this pattern is significant enough that speaking with a professional could be helpful' rather than any clinical diagnosis).

Always end with a reminder that this is not a medical diagnosis.

Respond ONLY with a JSON object in this exact format: {"report_text": "the full report text", "recommend_consultation": true or false, "severity_note": "a short one-sentence severity summary"}. Do not include any text outside this JSON object.
""";

  static Future<LLMResponse> sendChatMessage({
    required String userMessage,
    required List<Map<String, String>> history,
    String? context,
  }) async {
    try {
      // Gemini API expects the key as a query parameter
      final url = Uri.parse('${ApiConfig.geminiBaseUrl}?key=${ApiConfig.geminiApiKey}');
      
      List<Map<String, dynamic>> contents = [];

      // 1. Convert history to Gemini format (role: user/model)
      for (int i = 0; i < history.length; i++) {
        String role = history[i]['role'] == 'assistant' ? 'model' : 'user';
        String text = history[i]['content'] ?? "";
        
        // Prepend system prompt to the first user message in history
        if (i == 0 && role == 'user') {
          text = "$_systemPrompt\n\n$text";
        }
        
        contents.add({
          "role": role,
          "parts": [{"text": text}]
        });
      }

      // 2. Prepare current message with behavioral context
      String currentText = "";
      if (context != null && context.isNotEmpty) {
        currentText += "[BEHAVIORAL CONTEXT]\n$context\n[END CONTEXT]\n\n";
      }
      currentText += userMessage;

      // If history was empty, prepend system prompt to the current message
      if (contents.isEmpty) {
        currentText = "$_systemPrompt\n\n$currentText";
      }

      contents.add({
        "role": "user",
        "parts": [{"text": currentText}]
      });

      final body = jsonEncode({
        "contents": contents,
        "generationConfig": {
          "maxOutputTokens": 1024,
          "temperature": 0.7,
          "responseMimeType": "application/json"
        }
      });

      // 🧪 DEBUG: Log the request body
      debugPrint("--- 📤 GEMINI REQUEST BODY ---");
      debugPrint(body);

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      // 🧪 DEBUG: Log full raw response body immediately after return
      debugPrint("--- 📡 RAW GEMINI RESPONSE BODY ---");
      debugPrint(response.body);
      debugPrint("------------------------------------");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Parse the reply from response.candidates[0].content.parts[0].text
        final String rawContent = data['candidates'][0]['content']['parts'][0]['text'];
        
        try {
          final Map<String, dynamic> parsedJson = jsonDecode(rawContent);
          return LLMResponse.fromJson(parsedJson);
        } catch (parseError) {
          debugPrint("--- ⚠️ FALLBACK TRIGGERED: JSON PARSE ERROR ---");
          debugPrint("Error: $parseError");
        }
      } else {
        debugPrint("--- ⚠️ FALLBACK TRIGGERED: API ERROR ${response.statusCode} ---");
      }
      
      return LLMResponse.fallback();
    } catch (e) {
      debugPrint("--- ⚠️ FALLBACK TRIGGERED: HTTP EXCEPTION ---");
      debugPrint("Exception: $e");
      return LLMResponse.fallback();
    }
  }

  /// Specialized function to generate a behavioral health analysis report.
  static Future<ReportResponse> generateReport(Map<String, dynamic> reportData) async {
    try {
      final url = Uri.parse('${ApiConfig.geminiBaseUrl}?key=${ApiConfig.geminiApiKey}');
      
      final String jsonData = jsonEncode(reportData);

      final body = jsonEncode({
        "contents": [
          {
            "role": "user",
            "parts": [
              {"text": "$_reportSystemPrompt\n\nAnalyze this behavioral data and generate the report:\n$jsonData"}
            ]
          }
        ],
        "generationConfig": {
          "maxOutputTokens": 2048,
          "temperature": 0.5,
          "responseMimeType": "application/json"
        }
      });

      debugPrint("--- 📤 GEMINI REPORT REQUEST ---");
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      debugPrint("--- 📡 RAW GEMINI REPORT RESPONSE ---");
      debugPrint(response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String rawContent = data['candidates'][0]['content']['parts'][0]['text'];
        
        try {
          final Map<String, dynamic> parsedJson = jsonDecode(rawContent);
          return ReportResponse.fromJson(parsedJson);
        } catch (e) {
          debugPrint("--- ⚠️ REPORT PARSE ERROR ---");
        }
      }
      
      return ReportResponse.fallback();
    } catch (e) {
      debugPrint("--- ⚠️ REPORT EXCEPTION: $e ---");
      return ReportResponse.fallback();
    }
  }

  /// Generic function to send a prompt and expect a JSON response.
  static Future<Map<String, dynamic>?> generateJson(String prompt) async {
    try {
      final url = Uri.parse('${ApiConfig.geminiBaseUrl}?key=${ApiConfig.geminiApiKey}');
      
      final body = jsonEncode({
        "contents": [
          {
            "role": "user",
            "parts": [
              {"text": prompt}
            ]
          }
        ],
        "generationConfig": {
          "maxOutputTokens": 2048,
          "temperature": 0.7,
          "responseMimeType": "application/json"
        }
      });

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String rawContent = data['candidates'][0]['content']['parts'][0]['text'];
        return jsonDecode(rawContent) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint("--- ⚠️ GENERATE JSON EXCEPTION: $e ---");
    }
    return null;
  }
}
