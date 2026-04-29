/// Describes what the user wants to do in PeerCraft.
enum IntentMode {
  learn,
  teach,
  both;

  bool get includesLearn => this == learn || this == both;
  bool get includesTeach => this == teach || this == both;

  String get label {
    switch (this) {
      case learn:
        return 'Learner';
      case teach:
        return 'Mentor';
      case both:
        return 'Learner & Mentor';
    }
  }
}
