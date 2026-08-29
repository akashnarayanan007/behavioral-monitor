import 'package:flutter/material.dart';
import '../../database/database_service.dart';

class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  List<String> messages = [];
  int? latestEntryId; // Track ID for potential deletion

  @override
  void initState() {
    super.initState();
    generateAIResponse();
  }

  Future<void> generateAIResponse() async {
    List<Map<String, dynamic>> data = await DatabaseService.getLast10();

    if (data.isEmpty) {
      setState(() {
        messages.add("No data available. Start logging your behavior.");
      });
      return;
    }

    // Capture the ID of the record being discussed (the latest one)
    latestEntryId = data.first['id'];

    double avgSleep = 0;
    double avgScreen = 0;
    double avgWorkout = 0;

    for (var d in data) {
      avgSleep += (d['sleep'] ?? 0);
      avgScreen += (d['screenTime'] ?? 0);
      avgWorkout += (d['workout'] ?? 0);
    }

    avgSleep /= data.length;
    avgScreen /= data.length;
    avgWorkout /= data.length;

    List<String> aiMessages = [];
    aiMessages.add("🧠 Hello! Here's your mental health summary:");

    if (avgSleep < 6) {
      aiMessages.add("⚠️ You're sleeping less than recommended. Try 7–8 hours.");
    } else {
      aiMessages.add("✅ Your sleep schedule looks good.");
    }

    if (avgScreen > 5) {
      aiMessages.add("⚠️ High screen time detected. Consider reducing it.");
    } else {
      aiMessages.add("✅ Screen usage is under control.");
    }

    if (avgWorkout < 1) {
      aiMessages.add("⚠️ You need more physical activity.");
    } else {
      aiMessages.add("✅ Great job staying active!");
    }

    if (avgSleep < 5 && avgScreen > 6) {
      aiMessages.add("🧠 If this continues, consider consulting a professional.");
    } else {
      aiMessages.add("💡 Keep maintaining your routine!");
    }

    setState(() {
      messages = aiMessages;
    });
  }

  // TRIGGER: Handle Session End
  Future<void> _handleEndSession() async {
    // 1. Call teammate's session summary function (Placeholder)
    // Replace 'teammateSessionSummaryFunction' with the actual function name
    String summary = "Summary of session: Discussed sleep hygiene and digital usage."; 
    // Example: String summary = teammateSessionSummaryFunction(messages);

    // 2. Display the summary with a Delete button
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Session Summary"),
        content: Text(summary),
        actions: [
          // DELETE button
          TextButton(
            onPressed: () async {
              if (latestEntryId != null) {
                // 3. Remove corresponding record from SQLite
                await DatabaseService.deleteEntry(latestEntryId!);
                if (mounted) {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Leave chat screen
                }
              }
            },
            child: const Text("Delete Record", style: TextStyle(color: Colors.red)),
          ),
          // CLOSE button
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Leave chat screen
            },
            child: const Text("Exit"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent simple back button to force summary flow
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        _handleEndSession();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("AI Assistant"),
          actions: [
            TextButton(
              onPressed: _handleEndSession,
              child: const Text("Finish", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
        body: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            return Align(
              alignment: Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  messages[index],
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
