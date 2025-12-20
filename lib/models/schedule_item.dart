class ScheduleItem {
  final String name;
  final String teacher;
  final String classroom;
  final int dayIndex; // 0-6
  final int startUnit;
  final int endUnit;
  final int weekStart;
  final int weekEnd;

  ScheduleItem({
    required this.name,
    required this.teacher,
    required this.classroom,
    required this.dayIndex,
    required this.startUnit,
    required this.endUnit,
    this.weekStart = 0,
    this.weekEnd = 0,
  });

  factory ScheduleItem.fromJson(Map<String, dynamic> json) {
    return ScheduleItem(
      name: json['name'] ?? "",
      teacher: json['teacher'] ?? "",
      classroom: json['classroom'] ?? "",
      dayIndex: json['dayIndex'] ?? 0,
      startUnit: json['startUnit'] ?? 0,
      endUnit: json['endUnit'] ?? 0,
      weekStart: json['weekStart'] ?? 0,
      weekEnd: json['weekEnd'] ?? 0,
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
      'weekStart': weekStart,
      'weekEnd': weekEnd,
    };
  }

  String get periodString {
    return "$startPeriod-$endPeriod节";
  }

  int get startPeriod => startUnit;
  int get endPeriod => endUnit;
}
