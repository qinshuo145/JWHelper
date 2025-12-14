class ScheduleItem {
  final String name;
  final String teacher;
  final String classroom;
  final int dayIndex; // 0-6
  final int startUnit;
  final int endUnit;

  ScheduleItem({
    required this.name,
    required this.teacher,
    required this.classroom,
    required this.dayIndex,
    required this.startUnit,
    required this.endUnit,
  });

  factory ScheduleItem.fromJson(Map<String, dynamic> json) {
    return ScheduleItem(
      name: json['name'],
      teacher: json['teacher'],
      classroom: json['classroom'],
      dayIndex: json['dayIndex'],
      startUnit: json['startUnit'],
      endUnit: json['endUnit'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'teacher': teacher,
      'classroom': classroom,
      'dayIndex': dayIndex,
      'startUnit': startUnit,
      'endUnit': endUnit,
    };
  }

  String get periodString {
    int start = _mapStartUnitToPeriod(startUnit);
    int end = _mapEndUnitToPeriod(endUnit);
    return "$start-$end节";
  }

  int _mapStartUnitToPeriod(int unit) {
    if (unit >= 96 && unit < 107) return 1;
    if (unit >= 107 && unit < 120) return 2;
    if (unit >= 120 && unit < 131) return 3;
    if (unit >= 131 && unit < 162) return 4;
    if (unit >= 162 && unit < 173) return 5;
    if (unit >= 173 && unit < 186) return 6;
    if (unit >= 186 && unit < 197) return 7;
    if (unit >= 197 && unit < 222) return 8;
    if (unit >= 222 && unit < 233) return 9;
    if (unit >= 233 && unit < 244) return 10;
    if (unit >= 244) return 11;
    return 0;
  }

  int _mapEndUnitToPeriod(int unit) {
    if (unit <= 105) return 1;
    if (unit <= 116) return 2;
    if (unit <= 129) return 3;
    if (unit <= 140) return 4;
    if (unit <= 171) return 5;
    if (unit <= 181) return 6;
    if (unit <= 195) return 7;
    if (unit <= 205) return 8;
    if (unit <= 231) return 9;
    if (unit <= 242) return 10;
    return 11;
  }
}
