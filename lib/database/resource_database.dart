/// Simple data class representing a wellness resource.
class Resource {
  final String name;
  final String category;
  final String contact;
  final String description;

  const Resource({
    required this.name,
    required this.category,
    required this.contact,
    required this.description,
  });
}

/// A curated list of sample resources for the MindMatrix hackathon demo.
/// Categories: exam_anxiety, sleep_issues, isolation, digital_overload, general_stress, other.
final List<Resource> sampleResources = [
  // --- Exam Anxiety ---
  const Resource(
    name: "Student Success Center - Exam Prep",
    category: "exam_anxiety",
    contact: "success@uni.edu | 555-0101",
    description: "Offers workshops on test-taking strategies and anxiety management during finals week. [Sample Data]",
  ),
  const Resource(
    name: "Quiet Study Zone Coordinator",
    category: "exam_anxiety",
    contact: "Library Desk, Floor 3",
    description: "Assistance in finding low-sensory study environments during high-stress periods. [Sample Data]",
  ),

  // --- Sleep Issues ---
  const Resource(
    name: "Campus Health - Sleep Clinic",
    category: "sleep_issues",
    contact: "health-center@uni.edu | 555-0102",
    description: "Consultations for students struggling with insomnia or irregular sleep patterns. [Sample Data]",
  ),
  const Resource(
    name: "Blue Light Filter Guide",
    category: "sleep_issues",
    contact: "wellness-portal.uni.edu/sleep",
    description: "Instructions for setting up devices to minimize circadian rhythm disruption. [Sample Data]",
  ),

  // --- Isolation ---
  const Resource(
    name: "Peer Support Network",
    category: "isolation",
    contact: "Student Union Room 204",
    description: "Drop-in sessions to connect with fellow students in a relaxed, non-judgmental space. [Sample Data]",
  ),
  const Resource(
    name: "International Student Lounge",
    category: "isolation",
    contact: "intl-office@uni.edu",
    description: "Cultural events and social mixers designed to build community on campus. [Sample Data]",
  ),

  // --- Digital Overload ---
  const Resource(
    name: "Digital Wellness Hub",
    category: "digital_overload",
    contact: "wellness-portal.uni.edu/digital",
    description: "Resources for managing social media fatigue and implementing 'digital detox' periods. [Sample Data]",
  ),
  const Resource(
    name: "Screen Time Focus Group",
    category: "digital_overload",
    contact: "IT Services Helpdesk",
    description: "Workshops on using app blockers and focus tools effectively for deep work. [Sample Data]",
  ),

  // --- General Stress ---
  const Resource(
    name: "Central Counselling Services",
    category: "general_stress",
    contact: "Emergency: 555-9999 | Office: 555-0105",
    description: "General mental health support and one-on-one counseling for academic and life stress. [Sample Data]",
  ),

  // --- Other ---
  const Resource(
    name: "General Student Welfare Office",
    category: "other",
    contact: "welfare@uni.edu",
    description: "Guidance on financial, housing, or administrative issues affecting your wellness. [Sample Data]",
  ),
];

/// Filters the resource database by category and returns the top 1-2 results.
/// Fallbacks to the "other" category if no match is found.
List<Resource> getResourcesForCategory(String category) {
  // 1. Filter by exact category match
  List<Resource> results = sampleResources.where((r) => r.category == category).toList();

  // 2. If no match found, fallback to "other" category
  if (results.isEmpty) {
    results = sampleResources.where((r) => r.category == 'other').toList();
  }

  // 3. Return the top 2 results (1-2 entries as requested)
  return results.take(2).toList();
}
