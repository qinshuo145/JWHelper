import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import '../config.dart';
import 'client.dart';
import '../models/exam.dart';
import 'package:flutter/rendering.dart';

class ExamService {
  final ApiClient _client = ApiClient();

  Future<List<Semester>> getSemesters() async {
    try {
      final response = await _client.dio.get(
        "${Config.baseUrl}/Student/StudentExamArrangeTable.aspx",
      );
      
      final document = html_parser.parse(response.data);
      final options = document.querySelectorAll("#ddlSemester option");
      
      return options.map((e) => Semester(
        id: e.attributes['value'] ?? "",
        name: e.text.trim(),
      )).toList();
    } catch (e) {
      debugPrint("Error fetching semesters: $e");
      rethrow;
    }
  }

  Future<List<ExamRound>> getExamRounds(String semId) async {
    try {
      final response = await _client.dio.post(
        "${Config.baseUrl}/Student/StudentExamArrangeTableHandler.ashx",
        queryParameters: {
          "action": "thirdchange",
          "rondom": DateTime.now().millisecondsSinceEpoch / 1000,
        },
        data: {"semId": semId},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            "X-Requested-With": "XMLHttpRequest",
          },
        ),
      );

      if (response.data == null || response.data.toString().isEmpty) {
        return [];
      }

      final List<dynamic> jsonList = jsonDecode(response.data);
      if (jsonList.isNotEmpty && jsonList[0]['EtLst'] != null) {
        final List<dynamic> etList = jsonList[0]['EtLst'];
        return etList.map((e) => ExamRound(
          id: e['id'].toString(),
          name: e['name'].toString(),
        )).toList();
      }
      return [];

    } catch (e) {
      debugPrint("Error fetching exam rounds: $e");
      rethrow;
    }
  }

  Future<List<Exam>> getExamList(String semId, String etId) async {
    try {
      final response = await _client.dio.post(
        "${Config.baseUrl}/Student/StudentExamArrangeTableHandler.ashx",
        data: {
          "semId": semId,
          "etID": etId,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            "X-Requested-With": "XMLHttpRequest",
          },
        ),
      );

      // The response is JSON
      // {"a":true,"b":[{"periodTime":"","CourseNO":"...","CourseName":"...","serialNumber":"3",...}]}
      
      if (response.data == null || response.data.toString().isEmpty) {
        return [];
      }

      final Map<String, dynamic> jsonResponse = jsonDecode(response.data);
      if (jsonResponse['b'] == null) {
        return [];
      }

      final List<dynamic> list = jsonResponse['b'];
      return list.map((e) {
        return Exam(
          courseName: e['CourseName']?.toString() ?? "",
          courseNo: e['CourseNO']?.toString() ?? "",
          time: e['periodTime']?.toString() ?? "",
          location: e['learningSpace']?.toString() ?? "",
          classNo: e['serialNumber']?.toString() ?? "",
          type: e['EvaluationMethod']?.toString() ?? "",
          applyStatus: e['ApplyStatus']?.toString() ?? "",
        );
      }).toList();

    } catch (e) {
      debugPrint("Error fetching exam list: $e");
      rethrow;
    }
  }
}
