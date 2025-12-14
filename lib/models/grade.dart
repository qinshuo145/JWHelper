class Grade {
  final String semester;
  final String courseName;
  final String credit;
  final String score;
  final String gpa;

  Grade({
    required this.semester,
    required this.courseName,
    required this.credit,
    required this.score,
    required this.gpa,
  });

  factory Grade.fromJson(Map<String, dynamic> json) {
    return Grade(
      semester: json['semester'] ?? '',
      courseName: json['course_name'] ?? '',
      credit: json['credit'] ?? '',
      score: json['score'] ?? '',
      gpa: json['gpa'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'semester': semester,
      'course_name': courseName,
      'credit': credit,
      'score': score,
      'gpa': gpa,
    };
  }
}
