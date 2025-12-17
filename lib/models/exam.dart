class Exam {
  final String courseName;
  final String courseNo;
  final String time;
  final String location;
  final String classNo;
  final String type; // e.g. "Final", "Midterm"
  final String applyStatus;

  Exam({
    required this.courseName,
    required this.courseNo,
    required this.time,
    required this.location,
    required this.classNo,
    required this.type,
    required this.applyStatus,
  });

  factory Exam.fromJson(Map<String, dynamic> json) {
    return Exam(
      courseName: json['courseName'] ?? '',
      courseNo: json['courseNo'] ?? '',
      time: json['time'] ?? '',
      location: json['location'] ?? '',
      classNo: json['classNo'] ?? '',
      type: json['type'] ?? '',
      applyStatus: json['applyStatus'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'courseName': courseName,
      'courseNo': courseNo,
      'time': time,
      'location': location,
      'classNo': classNo,
      'type': type,
      'applyStatus': applyStatus,
    };
  }
}

class ExamRound {
  final String id;
  final String name;

  ExamRound({required this.id, required this.name});

  factory ExamRound.fromJson(Map<String, dynamic> json) {
    return ExamRound(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }

  @override
  String toString() => name;
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExamRound && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class Semester {
  final String id;
  final String name;

  Semester({required this.id, required this.name});

  factory Semester.fromJson(Map<String, dynamic> json) {
    return Semester(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Semester && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
