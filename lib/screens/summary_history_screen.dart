import 'package:flutter/material.dart';
import '../database/database_service.dart';

class SummaryHistoryScreen extends StatefulWidget {
  const SummaryHistoryScreen({super.key});

  @override
  State<SummaryHistoryScreen> createState() => _SummaryHistoryScreenState();
}

class _SummaryHistoryScreenState extends State<SummaryHistoryScreen> {
  List<Map<String, dynamic>> _summaries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSummaries();
  }

  Future<void> _loadSummaries() async {
    final data = await DatabaseService.getAllSummaries();
    setState(() {
      _summaries = data;
      _isLoading = false;
    });
  }

  Future<void> _deleteSummary(int id) async {
    await DatabaseService.deleteSessionSummary(id);
    // Remove from the list immediately for smooth UI feedback
    setState(() {
      _summaries.removeWhere((s) => s['id'] == id);
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Summary deleted")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Wellness Summaries"),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _summaries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_edu, size: 60, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        "No session summaries yet.",
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _summaries.length,
                  itemBuilder: (context, index) {
                    final summary = _summaries[index];
                    final String category = summary['category']?.toString() ?? "other";
                    final String date = summary['timestamp']?.toString().substring(0, 10) ?? "Unknown";

                    return Card(
                      elevation: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4A90E2).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    category.replaceAll('_', ' ').toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF4A90E2),
                                    ),
                                  ),
                                ),
                                Text(
                                  date,
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              summary['summary_text'] ?? "",
                              style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
                            ),
                            const Divider(height: 24),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () => _deleteSummary(summary['id']),
                                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                                label: const Text(
                                  "Delete",
                                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
