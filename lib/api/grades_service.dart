import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart';
import '../config.dart';
import 'client.dart';
import '../models/grade.dart';
import 'package:flutter/rendering.dart';

class GradesService {
  final ApiClient _client = ApiClient();
  Document? _cachedSoup;

  Future<List<String>> getSemesters() async {
    try {
      var response = await _client.dio.get(Config.gradesUrl);
      _cachedSoup = parser.parse(response.data);
      
      var semesterDivs = _cachedSoup!.querySelectorAll('div.div_semestertitle');
      List<String> semesters = [];
      for (var div in semesterDivs) {
        var h1 = div.querySelector('h1');
        if (h1 != null) {
          semesters.add(h1.text.trim());
        }
      }
      return semesters;
    } catch (e) {
      debugPrint("Get semesters failed: $e");
      rethrow;
    }
  }

  Future<List<Grade>> getGradesForSemester(int index) async {
    if (_cachedSoup == null) {
      await getSemesters();
    }
    if (_cachedSoup == null) return [];

    var semesterDivs = _cachedSoup!.querySelectorAll('div.div_semestertitle');
    if (index >= semesterDivs.length) return [];

    var targetDiv = semesterDivs[index];
    // Find next table
    Element? table;
    var nextElement = targetDiv.nextElementSibling;
    while (nextElement != null) {
      if (nextElement.localName == 'table') {
        table = nextElement;
        break;
      }
      nextElement = nextElement.nextElementSibling;
    }

    List<Grade> grades = [];
    if (table != null) {
      var rows = table.querySelectorAll('tr');
      // Skip header
      for (var i = 1; i < rows.length; i++) {
        var cols = rows[i].querySelectorAll('td');
        if (cols.isEmpty) continue;
        
        var rowData = cols.map((e) => e.text.trim()).toList();
        if (rowData.length >= 6) {
          grades.add(Grade(
            semester: "", // Will be filled by caller if needed
            courseName: rowData[1],
            credit: rowData[2],
            score: rowData[4],
            gpa: rowData[5],
          ));
        }
      }
    }
    return grades;
  }

  Future<List<Grade>> getAllGrades() async {
    var semesters = await getSemesters();
    List<Grade> allGrades = [];
    for (var i = 0; i < semesters.length; i++) {
      var grades = await getGradesForSemester(i);
      for (var grade in grades) {
        allGrades.add(Grade(
          semester: semesters[i],
          courseName: grade.courseName,
          credit: grade.credit,
          score: grade.score,
          gpa: grade.gpa,
        ));
      }
    }
    return allGrades;
  }
}
