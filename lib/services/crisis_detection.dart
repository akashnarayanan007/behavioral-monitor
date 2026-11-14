// Deterministic crisis detection service for MindMatrix.
// This service uses keyword and phrase matching to identify potential 
// crisis signals related to self-harm or suicidal ideation.

class CrisisDetection {
  /// A fixed, pre-written response to show when a crisis message is detected.
  static const String crisisEscalationMessage = 
    "It sounds like you're going through a very difficult time. "
    "Please reach out for immediate support, as this app is not equipped to provide crisis care. "
    "You can contact the National Student Helpline at [placeholder number] or speak with a trusted person right away.";

  /// A list of keywords and phrases that signal potential crisis situations.
  /// Organized by type for easier review and expansion.
  static const List<String> _crisisPhrases = [
    // --- Direct Self-Harm & Suicidal Ideation ---
    'suicide',
    'suicidal',
    'kill myself',
    'killing myself',
    'end my life',
    'ending my life',
    'take my life',
    'taking my life',
    'end it all',
    'ending it all',
    'end it',
    'ending it',
    'cut myself',
    'cutting myself',
    'self harm',
    'self-harm',
    'harm myself',
    'harming myself',
    'hurt myself',
    'hurting myself',
    'overdose',
    'hang myself',
    'slit my wrist',
    'want to die',
    'desire to die',
    'ready to die',
    'shoot myself',
    'drown myself',
    'jump from the building',
    'jump off the building',
    'jump off',
    'jump from a bridge',
    'jump off a bridge',
    'jumping off',
    'jumping from',
    'throw myself off',
    'throw myself in front of',
    'step in front of a train',
    'step in front of a car',
    
    // --- Feelings of Hopelessness & Desire to Vanish ---
    'no reason to live',
    'no point in living',
    'nothing to live for',
    'better off dead',
    'better off without me',
    'better off if i was gone',
    'don\'t want to exist',
    'stop existing',
    'wish i was never born',
    'wish i never existed',
    'never wake up',
    'wont be here much longer',
    'won\'t be here much longer',
    'everyone would be better if i was gone',
    'disappear forever',
    'vanish forever',
    'want to vanish',
    'want to disappear',
    
    // --- Indirect / Euphemistic / Hopeless Phrases ---
    'can\'t take it anymore',
    'cant take it anymore',
    'can\'t go on',
    'cant go on',
    'done with everything',
    'done with life',
    'give up on everything',
    'giving up on everything',
    'give up on life',
    'giving up on life',
    'goodbye everyone',
    'last goodbye',
    'final note',
    'suicide note',
    'the only way out',
    'permanent solution',
    'forever sleep',
    'life is not worth it',
    'not worth living',
  ];

  /// Checks if the input message contains any crisis-signal keywords or phrases.
  ///
  /// Returns `true` if a match is found, `false` otherwise.
  /// The check is case-insensitive and ignores surrounding whitespace.
  static bool isCrisisMessage(String message) {
    if (message.isEmpty) return false;

    // Normalize input: trim whitespace and convert to lowercase for matching
    final String normalizedMessage = message.trim().toLowerCase();

    // Check against every phrase in the list
    for (final String phrase in _crisisPhrases) {
      // Substring matching ensures high sensitivity (catches "I'm thinking of suicide")
      if (normalizedMessage.contains(phrase)) {
        return true;
      }
    }

    return false;
  }
}

/// Helper function to match the exact signature required.
bool isCrisisMessage(String message) {
  return CrisisDetection.isCrisisMessage(message);
}
