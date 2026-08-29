import 'package:flutter/material.dart';
import '../services/llm_service.dart';
import '../services/crisis_detection.dart';
import '../analysis/daily_score.dart';
import '../analysis/mental_state_service.dart';
import '../database/database_service.dart';
import '../database/resource_database.dart';
import 'session_summary_screen.dart';

enum MessageType { user, assistant, crisis, report, diagnostic }

class ChatMessage {
  final String text;
  final MessageType type;
  final List<Resource>? resources;
  final String? category;
  final String? severityNote;
  final String? severityAssessment;
  final String? urgencyLevel;

  ChatMessage({
    required this.text,
    required this.type,
    this.resources,
    this.category,
    this.severityNote,
    this.severityAssessment,
    this.urgencyLevel,
  });
}

class ChatScreen extends StatefulWidget {
  final String? initialMessage;
  const ChatScreen({super.key, this.initialMessage});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  // Stores the text of the last generated report to provide context for follow-up questions
  String? _activeReportContext;

  @override
  void initState() {
    super.initState();
    if (widget.initialMessage != null) {
      _messageController.text = widget.initialMessage!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleSendMessage();
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Pulls a longer range of historical data when explicitly triggered.
  Future<List<Map<String, dynamic>>> fetchHistoricalTrend(int days) async {
    return await DatabaseService.getRecentEntries(days);
  }

  dynamic _detectReportRequest(String message) {
    final msg = message.toLowerCase();
    
    // Check for "report" or "analysis" intent
    final hasIntent = msg.contains('report') || 
                     msg.contains('analyze') || 
                     msg.contains('summary') || 
                     msg.contains('how am i doing') || 
                     msg.contains('how have i been') ||
                     msg.contains('my progress') ||
                     msg.contains('trends');

    if (!hasIntent) return null;

    // Determine requested range
    if (msg.contains('today')) return 'today';
    if (msg.contains('yesterday')) return 'yesterday';
    
    // Look for numerical days (e.g. "past 5 days")
    final daysRegex = RegExp(r'(\d+)\s*day');
    final match = daysRegex.firstMatch(msg);
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? 7;
    }

    if (msg.contains('week')) return 7;
    if (msg.contains('month')) return 30;

    // FIXED: Default to 'today' (Branch A) if intent is found but range is unspecified
    return 'today';
  }

  Future<void> _handleSendMessage() async {
    final String userText = _messageController.text.trim();
    if (userText.isEmpty || _isLoading) return;

    _messageController.clear();
    setState(() {
      _messages.add(ChatMessage(text: userText, type: MessageType.user));
      _isLoading = true;
    });
    _scrollToBottom();

    // 1. Crisis Check
    if (CrisisDetection.isCrisisMessage(userText)) {
      setState(() {
        _messages.add(ChatMessage(
          text: CrisisDetection.crisisEscalationMessage,
          type: MessageType.crisis,
        ));
        _isLoading = false;
      });
      _scrollToBottom();
      return;
    }

    // 2. Report Request Detection
    final reportRange = _detectReportRequest(userText);
    if (reportRange != null) {
      try {
        final int? range = reportRange is int ? reportRange : (reportRange == 'yesterday' ? 1 : null);
        // Uses the newly defined fetchHistoricalTrend logic internally via MentalStateService
        final reportData = await MentalStateService.generateHealthReport(range);
        final reportResponse = await LLMService.generateReport(reportData);

        setState(() {
          _activeReportContext = reportResponse.reportText;
          _messages.add(ChatMessage(
            text: reportResponse.reportText,
            type: MessageType.report,
            severityNote: reportResponse.severityNote,
          ));
          _isLoading = false;
        });
        _scrollToBottom();
        return;
      } catch (e) {
        debugPrint("Error generating report: $e");
      }
    }

    // 3. Normal LLM Flow
    try {
      // DEFAULT BEHAVIOR: Fetch the last 2 entries to determine the stability trend for context
      final recentData = await DatabaseService.getRecentEntries(2);
      final Map<String, dynamic> latest = recentData.isNotEmpty ? recentData.first : <String, dynamic>{};
      
      String trend = "stable";
      if (recentData.length >= 2) {
        double currentScore = DailyScore.compute(recentData[0]);
        double previousScore = DailyScore.compute(recentData[1]);
        if (currentScore > previousScore + 0.3) trend = "up";
        else if (currentScore < previousScore - 0.3) trend = "down";
      }

      final stabilityIndex = latest.isNotEmpty ? DailyScore.compute(latest) : 0.0;

      // Build context using the updated MentalStateService signature with trend awareness
      String contextString = MentalStateService.generateStabilitySummary(
        stabilityIndex: stabilityIndex,
        latestEntry: latest,
        trend: trend,
      );

      // Inject active report context if it exists
      if (_activeReportContext != null) {
        contextString = "[ACTIVE REPORT CONTEXT]\n$_activeReportContext\n[END REPORT CONTEXT]\n\n" + contextString;
      }

      final history = _messages
          .where((m) => m.type == MessageType.user || m.type == MessageType.assistant)
          .map((m) => {
                "role": m.type == MessageType.user ? "user" : "assistant",
                "content": m.text
              })
          .toList();

      final response = await LLMService.sendChatMessage(
        userMessage: userText,
        history: history,
        context: contextString,
      );

      final List<Resource> resources = getResourcesForCategory(response.category);

      setState(() {
        _messages.add(ChatMessage(
          text: response.replyText,
          type: response.readyForReport ? MessageType.diagnostic : MessageType.assistant,
          resources: resources,
          category: response.category,
          severityAssessment: response.severityAssessment,
          urgencyLevel: response.urgencyLevel,
        ));
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: "Sorry, I'm having trouble connecting right now. Please try again.",
          type: MessageType.assistant,
        ));
        _isLoading = false;
      });
    }
    _scrollToBottom();
  }

  Future<void> _finishSession() async {
    if (_messages.isEmpty) {
      Navigator.pop(context);
      return;
    }

    String mainCategory = "other";
    List<String> assistantReplies = [];

    for (var m in _messages) {
      if (m.type == MessageType.assistant || m.type == MessageType.diagnostic) {
        assistantReplies.add(m.text);
        if (m.category != null && m.category != "other") {
          mainCategory = m.category!;
        }
      }
    }

    final String summaryText = MentalStateService.generateSessionSummary(mainCategory, assistantReplies);
    final int summaryId = await DatabaseService.insertSummary(mainCategory, summaryText);

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => SessionSummaryScreen(
          summaryId: summaryId,
          category: mainCategory,
          summaryText: summaryText,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF4A90E2);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _finishSession();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text("MindMatrix Assistant"),
          elevation: 0,
          actions: [
            TextButton(
              onPressed: _finishSession,
              child: const Text("End", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          ],
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.blue.withOpacity(0.1),
              child: const Text(
                "This app supports you but is not a substitute for professional mental health care.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.w500),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length) {
                    return _buildTypingIndicator();
                  }
                  final msg = _messages[index];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBubble(msg),
                      if (msg.severityAssessment != null && msg.type == MessageType.assistant)
                        _buildSeverityAssessmentCard(msg.severityAssessment!, msg.urgencyLevel),
                      if (msg.resources != null && msg.resources!.isNotEmpty)
                        ...msg.resources!.map((r) => _buildResourceCard(r)).toList(),
                    ],
                  );
                },
              ),
            ),
            _buildInputArea(primaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4A90E2)),
            ),
            SizedBox(width: 10),
            Text("Thinking...", style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildBubble(ChatMessage msg) {
    if (msg.type == MessageType.report) return _buildReportCard(msg);
    if (msg.type == MessageType.diagnostic) return _buildDiagnosticCard(msg);

    final bool isUser = msg.type == MessageType.user;
    final bool isCrisis = msg.type == MessageType.crisis;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isCrisis ? Colors.red.shade50 : (isUser ? const Color(0xFF4A90E2) : Colors.white),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 0),
            bottomRight: Radius.circular(isUser ? 0 : 16),
          ),
          border: isCrisis ? Border.all(color: Colors.red.shade200) : null,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Text(
          msg.text,
          style: TextStyle(
            color: isUser ? Colors.white : Colors.black87,
            fontSize: 15,
            fontWeight: isCrisis ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildDiagnosticCard(ChatMessage msg) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      width: double.infinity,
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.fact_check_outlined, color: Color(0xFF4A90E2)),
                  SizedBox(width: 10),
                  Text(
                    "Diagnostic Summary",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF4A90E2)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Synthesis & Recommendations",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    msg.text,
                    style: const TextStyle(fontSize: 14, height: 1.6, color: Colors.black87),
                  ),
                  if (msg.severityAssessment != null) ...[
                    const Divider(height: 32),
                    const Text(
                      "Severity Read",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey),
                    ),
                    const SizedBox(height: 10),
                    _buildSeverityAssessmentCard(msg.severityAssessment!, msg.urgencyLevel, isEmbedded: true),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(ChatMessage msg) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      width: double.infinity,
      child: Card(
        elevation: 6,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.analytics_outlined, color: Colors.deepPurple),
                  const SizedBox(width: 10),
                  const Text("Behavioral Health Report", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                  const Spacer(),
                  if (msg.severityNote != null)
                    Text(msg.severityNote!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(msg.text, style: const TextStyle(fontSize: 14, height: 1.6, color: Colors.black87)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeverityAssessmentCard(String assessment, String? urgency, {bool isEmbedded = false}) {
    Color borderColor;
    Color bgColor;
    IconData icon;

    switch (urgency) {
      case 'high':
        borderColor = Colors.red.shade400;
        bgColor = Colors.red.shade50;
        icon = Icons.gpp_maybe_outlined;
        break;
      case 'medium':
        borderColor = Colors.amber.shade600;
        bgColor = Colors.amber.shade50;
        icon = Icons.info_outline;
        break;
      case 'low':
      default:
        borderColor = const Color(0xFF4A90E2).withOpacity(0.5);
        bgColor = const Color(0xFF4A90E2).withOpacity(0.05);
        icon = Icons.check_circle_outline;
        break;
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: isEmbedded ? double.infinity : MediaQuery.of(context).size.width * 0.72,
        margin: isEmbedded ? EdgeInsets.zero : const EdgeInsets.only(left: 12, bottom: 8, top: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border(
            left: BorderSide(color: borderColor, width: 4),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: borderColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  assessment,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResourceCard(Resource resource) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.7,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline, size: 18, color: Color(0xFF4A90E2)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(resource.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                  ],
                ),
                const SizedBox(height: 8),
                Text(resource.description, style: const TextStyle(fontSize: 13, color: Colors.black54)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: "Type a message...",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                  fillColor: const Color(0xFFF5F7FA),
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                onSubmitted: (_) => _handleSendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            FloatingActionButton(onPressed: _handleSendMessage, backgroundColor: primaryColor, mini: true, child: const Icon(Icons.send, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
