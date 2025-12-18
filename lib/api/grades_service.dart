import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart';
import '../config.dart';
import 'client.dart';
import '../models/grade.dart';

// Top-level function for compute
List<Grade> _parseAllGrades(String html) {
  final document = parser.parse(html);
  final semesterDivs = document.querySelectorAll('div.div_semestertitle');
  List<Grade> allGrades = [];

  for (var div in semesterDivs) {
    String semesterName = "";
    var h1 = div.querySelector('h1');
    if (h1 != null) {
      semesterName = h1.text.trim();
    }

    // Find next table
    Element? table;
    var nextElement = div.nextElementSibling;
    while (nextElement != null) {
      if (nextElement.localName == 'table') {
        table = nextElement;
        break;
      }
      nextElement = nextElement.nextElementSibling;
    }

    if (table != null) {
      var rows = table.querySelectorAll('tr');
      // Skip header
      for (var i = 1; i < rows.length; i++) {
        var cols = rows[i].querySelectorAll('td');
        if (cols.isEmpty) continue;
        
        var rowData = cols.map((e) => e.text.trim()).toList();
        if (rowData.length >= 6) {
          allGrades.add(Grade(
            semester: semesterName,
            courseName: rowData[1],
            credit: rowData[2],
            score: rowData[4],
            gpa: rowData[5],
          ));
        }
      }
    }
  }
  return allGrades;
}

class GradesService {
  final ApiClient _client = ApiClient();

  // Kept for compatibility if needed, but getAllGrades is preferred
  Future<List<String>> getSemesters() async {
    // This is less efficient now if we want to use compute for everything, 
    // but for just getting semesters, we can still parse lightly or use the full parse.
    // Let's just fetch and parse quickly.
    try {
      var response = await _client.dio.get(Config.gradesUrl);
      return await compute(_parseSemestersOnly, response.data.toString());
    } catch (e) {
      debugPrint("Get semesters failed: $e");
      rethrow;
    }
  }

  Future<List<Grade>> getAllGrades() async {
    try {
      var response = await _client.dio.get(Config.gradesUrl);
      return await compute(_parseAllGrades, response.data.toString());
    } catch (e) {
      debugPrint("Get all grades failed: $e");
      rethrow;
    }
  }
}

List<String> _parseSemestersOnly(String html) {
  final document = parser.parse(html);
  var semesterDivs = document.querySelectorAll('div.div_semestertitle');
  List<String> semesters = [];
  for (var div in semesterDivs) {
    var h1 = div.querySelector('h1');
    if (h1 != null) {
      semesters.add(h1.text.trim());
    }
  }
  return semesters;
}
