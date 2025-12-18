import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart';
import 'package:dio/dio.dart';
import '../config.dart';
import 'client.dart';
import '../models/progress_item.dart';

// Top-level helper
String? _extractId(Element a) {
  // 1. Try href postback: javascript:__doPostBack('...','s100')
  var href = a.attributes['href'] ?? "";
  var match = RegExp(r"tvProgramProgress','([^']+)'").firstMatch(href);
  if (match != null) return match.group(1);
  
  // 2. Try id attribute: childA123
  var idAttr = a.attributes['id'] ?? "";
  if (idAttr.isNotEmpty) {
    // Remove non-digits
    var digits = idAttr.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isNotEmpty) return digits;
  }

  // 3. Try onclick: changeGroup(123) or clickNode('123')
  var onclick = a.attributes['onclick'] ?? "";
  if (onclick.isNotEmpty) {
    var clickMatch = RegExp(r'(\d+)').firstMatch(onclick);
    if (clickMatch != null) return clickMatch.group(1);
  }

  return null;
}

// Top-level function for compute
Map<String, dynamic> _parseProgressHtml(String html) {
  var doc = parser.parse(html);
  
  // Extract systemNumber
  String systemNumber = "";
  var sysInput = doc.querySelector('input#systemNumber');
  if (sysInput != null) {
    systemNumber = sysInput.attributes['value'] ?? "";
  }

  List<ProgressInfo> basicInfo = [];
  List<ProgressGroup> groups = [];

  // 1. Parse Basic Info
  Map<String, String> idMap = {
    'lblMainAvgCreditHour': '学位课程绩点',
    'lblAcquiredCreditsInProg2': '已获得学分',
    'lblLeastCreditsOfProg': '要求最低学分',
  };

  idMap.forEach((id, label) {
    var element = doc.querySelector('#$id');
    if (element != null) {
      var value = element.text.trim();
      if (value.isNotEmpty) {
        basicInfo.add(ProgressInfo(label: label, value: value));
      }
    }
  });

  // Fallback: If IDs fail, try to scan tables (Legacy support)
  if (basicInfo.isEmpty) {
    var tables = doc.querySelectorAll('table');
    Set<String> foundLabels = {};
    
    for (var table in tables) {
      if (table.id == 'tableTree') continue;

      var rows = table.querySelectorAll('tr');
      for (var row in rows) {
        var cols = row.querySelectorAll('td, th');
        for (var i = 0; i < cols.length; i++) {
          var text = cols[i].text.trim();
          
          if (text.contains("已获得学分") && text.contains("要求最低学分")) {
             if (i + 1 < cols.length) {
               var valueText = cols[i+1].text.trim().replaceAll(RegExp(r'\s+'), '');
               var match = RegExp(r'(\d+(\.\d+)?)[（\(](\d+(\.\d+)?)[）\)]').firstMatch(valueText);
               
               if (match != null) {
                 if (!foundLabels.contains("已获得学分")) {
                   basicInfo.add(ProgressInfo(label: "已获得学分", value: match.group(1)!));
                   foundLabels.add("已获得学分");
                 }
                 if (!foundLabels.contains("要求最低学分")) {
                   basicInfo.add(ProgressInfo(label: "要求最低学分", value: match.group(3)!));
                   foundLabels.add("要求最低学分");
                 }
               }
             }
             continue;
          }

          bool isMajorCredit = text.contains("主修") && text.contains("方案外");
          bool isGPA = text.contains("学位课程绩点");

          if (isMajorCredit || isGPA) {
            String label = isMajorCredit ? "主修与方案外获得学分" : "学位课程绩点";
            if (i + 1 < cols.length) {
              var value = cols[i+1].text.trim().replaceAll(RegExp(r'\s+'), ' ');
              if (isGPA) {
                 var match = RegExp(r'(\d+(\.\d+)?)').firstMatch(value);
                 if (match != null) value = match.group(1)!;
              }
              if (!foundLabels.contains(label)) {
                basicInfo.add(ProgressInfo(label: label, value: value));
                foundLabels.add(label);
              }
            }
          }
        }
      }
    }
  }

  // 2. Parse Course Groups (Tree Table)
  var treeTable = doc.querySelector('table#tableTree');
  if (treeTable != null) {
    var links = treeTable.querySelectorAll('a');
    
    for (var i = 0; i < links.length; i++) {
      var a = links[i];
      var text = a.text.trim();
      
      if (text.contains("展开") || text.contains("折叠") || text.isEmpty) continue;
      
      RegExp regExp = RegExp(r'(.+)\((\d+(\.\d+)?)/(\d+(\.\d+)?)\)');
      var match = regExp.firstMatch(text);
      
      if (match != null) {
        String name = match.group(1)!.trim();
        double earned = double.parse(match.group(2)!);
        double required = double.parse(match.group(4)!);
        
        String? id = _extractId(a);
        if (id == null && i + 1 < links.length) {
          id = _extractId(links[i+1]);
        }
        if (id == null && i - 1 >= 0) {
          id = _extractId(links[i-1]);
        }
        id ??= name;
        
        groups.add(ProgressGroup(
          id: id,
          name: name,
          required: required,
          earned: earned,
        ));
      }
    }
  }

  // Parse "Out of Program" Courses (方案外课程)
  var outOfProgBoxes = doc.querySelectorAll('div.box.box-primary');
  
  for (var outOfProgBox in outOfProgBoxes) {
    var titleEl = outOfProgBox.querySelector('h3.box-title');
    
    if (titleEl != null && titleEl.text.contains("方案外课程")) {
      double earned = 0;
      var earnedEl = outOfProgBox.querySelector('#lblAcquiredCreditsOutOfProg2');
      if (earnedEl != null) {
        earned = double.tryParse(earnedEl.text.trim()) ?? 0;
      }

      List<ProgressCourse> outCourses = [];
      var table = outOfProgBox.querySelector('table#tableCourseOutOfProg');
      if (table != null) {
        var rows = table.querySelectorAll('tr');
        for (var i = 1; i < rows.length; i++) {
          var cols = rows[i].querySelectorAll('td');
          if (cols.length >= 8) {
            String name = cols[2].text.trim();
            String score = cols[3].text.trim();
            String credit = cols[5].text.trim();
            
            bool isPassed = true;
            double? scoreNum = double.tryParse(score);
            if (scoreNum != null) {
              isPassed = scoreNum >= 60;
            } else {
              if (score.contains("不合格") || score.contains("F")) {
                isPassed = false;
              }
            }

            outCourses.add(ProgressCourse(
              name: name,
              credit: credit,
              score: score,
              isPassed: isPassed,
            ));
          }
        }
      }

      groups.add(ProgressGroup(
        id: "out_of_program",
        name: "方案外课程",
        required: 0,
        earned: earned,
        courses: outCourses,
      ));
      break;
    }
  }

  // Calculate "Major & Extra Credits"
  String? extraCreditsStr;
  var extraCreditsEl = doc.querySelector('#lblAcquiredCreditsOutOfProg2');
  if (extraCreditsEl != null) {
    extraCreditsStr = extraCreditsEl.text.trim();
  }

  var inProgInfo = basicInfo.firstWhere((i) => i.label == "已获得学分", orElse: () => ProgressInfo(label: "", value: ""));
  
  if (inProgInfo.value.isNotEmpty && extraCreditsStr != null) {
      double inProg = double.tryParse(inProgInfo.value) ?? 0;
      double outProg = double.tryParse(extraCreditsStr) ?? 0;
      double total = inProg + outProg;
      String value = total % 1 == 0 ? total.toInt().toString() : total.toString();
      
      basicInfo.removeWhere((i) => i.label == "主修与方案外获得学分");
      basicInfo.insert(0, ProgressInfo(label: "主修与方案外获得学分", value: value));
  } else {
    bool hasTotalCredits = basicInfo.any((i) => i.label.contains("主修与方案外获得学分"));
    if (!hasTotalCredits && groups.isNotEmpty) {
      double total = 0;
      for (var g in groups) {
        total += g.earned;
      }
      String value = total % 1 == 0 ? total.toInt().toString() : total.toString();
      basicInfo.insert(0, ProgressInfo(label: "主修与方案外获得学分", value: value));
    }
  }
  
  return {
    "groups": groups,
    "info": basicInfo,
    "systemNumber": systemNumber,
  };
}

class ProgressService {
  final ApiClient _client = ApiClient();
  String _systemNumber = "";

  Future<Map<String, dynamic>> getProgressData() async {
    try {
      var response = await _client.dio.get(Config.progressUrl);
      
      // Use compute for parsing
      var result = await compute(_parseProgressHtml, response.data.toString());
      
      _systemNumber = result['systemNumber'] ?? "";
      
      return {
        "groups": result['groups'],
        "info": result['info'],
      };
    } catch (e) {
      debugPrint("Get progress failed: $e");
      rethrow;
    }
  }

  Future<List<ProgressCourse>> getGroupCourses(String groupId) async {
    // systemNumber can be empty, so we don't check for isEmpty
    
    try {
      String url = "${Config.baseUrl}/Student/MyProgramProgressHandler.ashx?action=GetData&random=${DateTime.now().millisecondsSinceEpoch}";
      
      var formData = {
        "groupId": groupId,
        "systemNumber": _systemNumber,
      };

      var response = await _client.dio.post(
        url, 
        data: formData,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            "X-Requested-With": "XMLHttpRequest",
            "Referer": Config.progressUrl,
          },
        ),
      );

      debugPrint("Group Courses Response [$groupId]: ${response.data}");

      if (response.statusCode == 200) {
        var data = response.data;
        if (data is String) {
           try {
             data = jsonDecode(data);
           } catch (e) {
             debugPrint("JSON decode error: $e");
           }
        }

        if (data is Map && data.containsKey('Datas')) {
          List<dynamic> datas = data['Datas'];
          return datas.map((json) {
            return ProgressCourse(
              name: json['CourseName'] ?? '未知',
              credit: json['GetCredit']?.toString() ?? '0',
              score: (json['Mark']?.toString().isNotEmpty == true) ? json['Mark'].toString() : '-',
              isPassed: json['IsPass'] == true,
            );
          }).toList();
        }
      }
    } catch (e) {
      debugPrint("Get group courses failed: $e");
      rethrow;
    }
    return [];
  }
}
