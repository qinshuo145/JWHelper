class ProgressGroup {
  final String id;
  final String name;
  final double required;
  final double earned;
  List<ProgressCourse>? courses;

  ProgressGroup({
    required this.id,
    required this.name,
    required this.required,
    required this.earned,
    this.courses,
  });

  factory ProgressGroup.fromJson(Map<String, dynamic> json) {
    return ProgressGroup(
      id: json['id'],
      name: json['name'],
      required: (json['required'] as num).toDouble(),
      earned: (json['earned'] as num).toDouble(),
      courses: json['courses'] != null
          ? (json['courses'] as List).map((i) => ProgressCourse.fromJson(i)).toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'required': required,
      'earned': earned,
      'courses': courses?.map((e) => e.toJson()).toList(),
    };
  }
}

class ProgressInfo {
  final String label;
  final String value;

  ProgressInfo({required this.label, required this.value});

  factory ProgressInfo.fromJson(Map<String, dynamic> json) {
    return ProgressInfo(
      label: json['label'],
      value: json['value'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'value': value,
    };
  }
}

class ProgressCourse {
  final String name;
  final String credit;
  final String score;
  final bool isPassed;

  ProgressCourse({
    required this.name,
    required this.credit,
    required this.score,
    required this.isPassed,
  });

  factory ProgressCourse.fromJson(Map<String, dynamic> json) {
    return ProgressCourse(
      name: json['name'],
      credit: json['credit'],
      score: json['score'],
      isPassed: json['isPassed'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'credit': credit,
      'score': score,
      'isPassed': isPassed,
    };
  }
}
