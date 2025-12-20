import 'dart:convert';
import 'package:dio/dio.dart';
import '../config.dart';
import 'client.dart';
import '../models/schedule_item.dart';
import 'package:flutter/rendering.dart';


class ScheduleService {
  final ApiClient _client = ApiClient();

  Future<String> _fetchSemesterId() async {
    try {
      var initParams = {
        "action": "initTablePage",
        "isPublic": ""
      };
      
      var initResp = await _client.dio.post(
        Config.timetableAPI,
        data: initParams,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            "X-Requested-With": "XMLHttpRequest",
            "Referer": "${Config.baseUrl}/Teacher/TimeTable.aspx",
          },
        )
      );

      if (initResp.statusCode == 200) {
         var json = jsonDecode(initResp.data);
         var sems = json['Sems'] as List?;
         if (sems != null && sems.isNotEmpty) {
           // Try to find selected semester
           var selectedSem = sems.firstWhere(
             (s) => s['IsSelected'] == true, 
             orElse: () => null
           );
           
           if (selectedSem != null) {
             return selectedSem['Id'].toString();
           } else {
             // If no selected semester, use the last one (usually the latest)
             sems.sort((a, b) => (b['Id'] as int).compareTo(a['Id'] as int));
             return sems.first['Id'].toString();
           }
         }
      }
    } catch (e) {
      debugPrint("Failed to fetch initTablePage: $e");
    }
    return "";
  }

  Future<String> _probeSemesterId(Map<String, dynamic> params) async {
    try {
      var probeParams = Map<String, dynamic>.from(params);
      probeParams['semId'] = "0"; // Try 0 to trigger a response with CurrentSemId
      
      var probeResp = await _client.dio.post(
        Config.timetableAPI, 
        data: probeParams,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            "X-Requested-With": "XMLHttpRequest",
            "Referer": "${Config.baseUrl}/Teacher/TimeTable.aspx",
          },
          validateStatus: (status) => true,
        )
      );
      
      if (probeResp.statusCode == 200) {
         var json = jsonDecode(probeResp.data);
         if (json['CurrentSemId'] != null) {
            return json['CurrentSemId'].toString();
         }
      }
    } catch (e) {
      debugPrint("Probe failed: $e");
    }
    return "";
  }

  Future<Map<String, dynamic>> getSchedule() async {
    try {
      // 1. Get Semester ID using initTablePage
      var semId = await _fetchSemesterId();
      
      // 2. Get Data
      var params = {
        "action": "getTeacherTimeTable",
        "isShowStudent": "1",
        "classes": "",
        "lsCodes": "",
        "lsIds": "",
        "srNumbers": "",
        "semId": semId,
        "pbn": "",
        "testTeacherTimeTablePublishStatus": "1",
        "ttId": "",
        "isPublic": ""
      };

      // Fallback to probing if scraping failed
      if (semId.isEmpty) {
         debugPrint("Warning: Semester ID could not be scraped. Probing API for CurrentSemId...");
         semId = await _probeSemesterId(params);
         if (semId.isNotEmpty) {
           params['semId'] = semId;
         }
      }

      // Fallback to 35 if still empty (Temporary fix based on user logs)
      if (semId.isEmpty) {
         debugPrint("CRITICAL: Semester ID could not be found. Using fallback '35'.");
         semId = "35";
         params['semId'] = semId;
      }

      Response apiResp;
      try {
        apiResp = await _client.dio.post(
          Config.timetableAPI, 
          data: params,
          options: Options(
            contentType: Headers.formUrlEncodedContentType,
            headers: {
              "X-Requested-With": "XMLHttpRequest",
              "Referer": "${Config.baseUrl}/Teacher/TimeTable.aspx",
            },
            validateStatus: (status) => true,
          )
        );
      } catch (e) {
        debugPrint("Dio Post Error: $e");
        rethrow;
      }

      debugPrint("Schedule API Status: ${apiResp.statusCode}");
      
      if (apiResp.statusCode != 200) {
        throw Exception("Server returned ${apiResp.statusCode}");
      }

      var json = jsonDecode(apiResp.data);
      
      // Check if we need to retry with CurrentSemId
      var data = json['Data'] as List?;
      if ((data == null || data.isEmpty) && semId.isEmpty && json['CurrentSemId'] != null) {
        var currentSemId = json['CurrentSemId'].toString();
        debugPrint("Data empty, retrying with CurrentSemId: $currentSemId");
        params['semId'] = currentSemId;
        
        apiResp = await _client.dio.post(
          Config.timetableAPI, 
          data: params,
          options: Options(
            contentType: Headers.formUrlEncodedContentType,
            headers: {
              "X-Requested-With": "XMLHttpRequest",
              "Referer": "${Config.baseUrl}/Teacher/TimeTable.aspx",
            },
            validateStatus: (status) => true,
          )
        );
        json = jsonDecode(apiResp.data);
      }

      // Build Time Slot Maps
      Map<int, int> startSlotToUnit = {};
      Map<int, int> endSlotToUnit = {};
      
      if (json['ClassTimePatterns'] != null) {
        for (var pattern in json['ClassTimePatterns']) {
          var times = pattern['Time'] as List?;
          if (times != null) {
            for (int i = 0; i < times.length; i++) {
              var start = times[i]['StartTimeSlot'];
              var end = times[i]['EndTimeSlot'];
              if (start != null) startSlotToUnit[start] = i + 1;
              if (end != null) endSlotToUnit[end] = i + 1;
            }
          }
        }
      }

      var data1 = json['Data'] as List?;
      if (data1 == null) return {'items': <ScheduleItem>[], 'startDay': null};

      // Extract StartDay
      String? startDayStr;
      if (data1.isNotEmpty) {
        for (var item in data1) {
          if (item['StartDay'] != null && item['StartDay'].toString().isNotEmpty) {
            startDayStr = item['StartDay'];
            break;
          }
        }
      }
      debugPrint("Extracted StartDay: $startDayStr");
      
      List<ScheduleItem> items = [];
      for (var course in data1) {
        int? startSlot = course['TimeSlotStart'];
        int? endSlot = course['TimeSlotEnd'];
        
        if (startSlot == null || endSlot == null) continue;

        int startUnit = startSlotToUnit[startSlot] ?? -1;
        int endUnit = endSlotToUnit[endSlot] ?? -1;

        if (startUnit == -1 || endUnit == -1) {
           debugPrint("Warning: Unknown time slot $startSlot-$endSlot");
           continue;
        }

        int dayIdx = -1;
        if (course['OnMonday'] == true) {dayIdx = 0;}
        else if (course['OnTuesday'] == true) {dayIdx = 1;}
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
            weekStart: course['WeekStart'] ?? 0,
            weekEnd: course['WeekEnd'] ?? 0,
          ));
        }
      }
      debugPrint("Parsed Items Count: ${items.length}");
      return {
        'items': items,
        'startDay': startDayStr
      };
    } catch (e) {
      debugPrint("Get schedule failed: $e");
      rethrow;
    }
  }
}
