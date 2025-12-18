import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as parser;
import '../config.dart';
import 'client.dart';
import '../models/schedule_item.dart';
import 'package:flutter/rendering.dart';


class ScheduleService {
  final ApiClient _client = ApiClient();

  Future<List<ScheduleItem>> getSchedule() async {
    try {
      // 1. Get Semester ID
      var pageResp = await _client.dio.get("${Config.baseUrl}/Student/CourseTimetable/MyCourseTimeTable.aspx");
      var doc = parser.parse(pageResp.data);
      var semId = "";
      var select = doc.querySelector('select#ddlSemester');
      if (select != null) {
        var option = select.querySelector('option[selected]') ?? select.querySelector('option');
        if (option != null) {
          semId = option.attributes['value'] ?? "";
        }
      }

      // 2. Get Data
      var formData = FormData.fromMap({
        "action": "getTeacherTimeTable",
        "isShowStudent": "1",
        "classes": "",
        "semId": semId,
        "isPublic": ""
      });

      var apiResp = await _client.dio.post(Config.timetableAPI, data: formData);
      var json = jsonDecode(apiResp.data);
      var data = json['Data'] as List?;
      
      if (data == null) return [];

      List<ScheduleItem> items = [];
      for (var course in data) {
        int? startUnit = course['TimeSlotStart'];
        int? endUnit = course['TimeSlotEnd'];
        if (startUnit == null || endUnit == null) continue;

        int dayIdx = -1;
        if (course['OnMonday'] == true) {
          dayIdx = 0;
        } else if (course['OnTuesday'] == true) {dayIdx = 1;}
        else if (course['OnWednesday'] == true) {dayIdx = 2;}
        else if (course['OnThursday'] == true) {dayIdx = 3;}
        else if (course['OnFriday'] == true) {dayIdx = 4;}
        else if (course['OnSaturday'] == true) {dayIdx = 5;}
        else if (course['OnSunday'] == true) {dayIdx = 6;}

        if (dayIdx != -1) {
          String classroom = course['Classroom'] ?? "";
          if (classroom.isEmpty) {
            String remark = course['Remark'] ?? "";
            if (remark.isNotEmpty) {
              var parts = remark.split(' ');
              if (parts.isNotEmpty) classroom = parts.last;
            }
          }
          
          // Simplify classroom name (last 4 digits)
          RegExp regExp = RegExp(r'(\d+)$');
          var match = regExp.firstMatch(classroom);
          if (match != null) {
            var digits = match.group(1)!;
            if (digits.length > 4) digits = digits.substring(digits.length - 4);
            classroom = digits;
          }

          items.add(ScheduleItem(
            name: course['LUName'] ?? "",
            teacher: course['FullName'] ?? "",
            classroom: classroom,
            dayIndex: dayIdx,
            startUnit: startUnit,
            endUnit: endUnit,
          ));
        }
      }
      return items;
    } catch (e) {
      debugPrint("Get schedule failed: $e");
      rethrow;
    }
  }
}
