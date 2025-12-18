import 'dart:convert';
import 'package:flutter/rendering.dart';
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart';
import 'package:dio/dio.dart';
import '../config.dart';
import 'client.dart';
import '../models/progress_item.dart';

class ProgressService {
  final ApiClient _client = ApiClient();
  String _systemNumber = "";

  Future<Map<String, dynamic>> getProgressData() async {
    try {
      var response = await _client.dio.get(Config.progressUrl);
      
      
      var doc = parser.parse(response.data);
      
      // Extract systemNumber
      var sysInput = doc.querySelector('input#systemNumber');
      if (sysInput != null) {
        _systemNumber = sysInput.attributes['value'] ?? "";
      }

      List<ProgressInfo> basicInfo = [];
      List<ProgressGroup> groups = [];

      // 1. Parse Basic Info
      // Strategy: Direct ID extraction based on provided HTML structure
      Map<String, String> idMap = {
        'lblMainAvgCreditHour': '学位课程绩点',
        // 'spAllCredit': '主修与方案外获得学分', // Removed as it's not returned by server
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
          // Skip the tree table which contains course groups
          if (table.id == 'tableTree') continue;

          var rows = table.querySelectorAll('tr');
          for (var row in rows) {
            var cols = row.querySelectorAll('td, th');
            // Try to find key-value pairs
            for (var i = 0; i < cols.length; i++) {
              var text = cols[i].text.trim();
              
              // Check if this cell contains one of our target labels
              
              // Special handling for "Earned (Required)" combined field
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

              // Robust check for Major Credits and GPA
              bool isMajorCredit = text.contains("主修") && text.contains("方案外");
              bool isGPA = text.contains("学位课程绩点");

              if (isMajorCredit || isGPA) {
                String label = isMajorCredit ? "主修与方案外获得学分" : "学位课程绩点";
                
                // The value should be in the next cell
                if (i + 1 < cols.length) {
                  var value = cols[i+1].text.trim().replaceAll(RegExp(r'\s+'), ' ');
                  
                  // Clean value for GPA if it contains notes
                  if (isGPA) {
                     var match = RegExp(r'(\d+(\.\d+)?)').firstMatch(value);
                     if (match != null) {
                       value = match.group(1)!;
                     }
                  }

                  if (value.isNotEmpty && !foundLabels.contains(label)) {
                    basicInfo.add(ProgressInfo(label: label, value: value));
                    foundLabels.add(label);
                  }
                }
              }
            }
          }
        }
      }
      
      var treeTable = doc.querySelector('table#tableTree');
      if (treeTable != null) {
        var links = treeTable.querySelectorAll('a');
        
        for (var i = 0; i < links.length; i++) {
          var a = links[i];
          var text = a.text.trim();
          
          if (text.contains("展开") || text.contains("折叠") || text.isEmpty) continue;
          
          // Regex to parse "GroupName (Earned/Required)"
          // e.g. "通识教育必修课(10.0/14.0)"
          RegExp regExp = RegExp(r'(.+)\((\d+(\.\d+)?)/(\d+(\.\d+)?)\)');
          var match = regExp.firstMatch(text);
          
          if (match != null) {
            String name = match.group(1)!.trim();
            double earned = double.parse(match.group(2)!);
            double required = double.parse(match.group(4)!);
            
            // Find ID
            String? id = _extractId(a);
            
            // Try next link
            if (id == null && i + 1 < links.length) {
              id = _extractId(links[i+1]);
            }
            // Try prev link
            if (id == null && i - 1 >= 0) {
              id = _extractId(links[i-1]);
            }
            
            // Fallback: use name as ID if not found, so we can at least display it
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
      debugPrint("Start parsing Out of Program courses...");
      var outOfProgBoxes = doc.querySelectorAll('div.box.box-primary');
      debugPrint("Found ${outOfProgBoxes.length} box-primary divs");
      
      for (var outOfProgBox in outOfProgBoxes) {
        var titleEl = outOfProgBox.querySelector('h3.box-title');
        debugPrint("Box title: ${titleEl?.text}");
        
        if (titleEl != null && titleEl.text.contains("方案外课程")) {
          debugPrint("Found '方案外课程' box");
          double earned = 0;
          var earnedEl = outOfProgBox.querySelector('#lblAcquiredCreditsOutOfProg2');
          if (earnedEl != null) {
            earned = double.tryParse(earnedEl.text.trim()) ?? 0;
            debugPrint("Parsed earned credits: $earned");
          }

          List<ProgressCourse> outCourses = [];
          var table = outOfProgBox.querySelector('table#tableCourseOutOfProg');
          if (table != null) {
            var rows = table.querySelectorAll('tr');
            debugPrint("Found table with ${rows.length} rows");
            // Skip header (index 0)
            for (var i = 1; i < rows.length; i++) {
              var cols = rows[i].querySelectorAll('td');
              if (cols.length >= 8) {
                // Index 2: Course Name
                // Index 3: Score
                // Index 5: Earned Credit
                // Index 6: Course Credit
                String name = cols[2].text.trim();
                String score = cols[3].text.trim();
                String credit = cols[5].text.trim();
                
                debugPrint("Parsed course: $name, Score: $score");

                // Determine pass status (simple check: score >= 60 or "合格" or "P")
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
          } else {
            debugPrint("Table tableCourseOutOfProg not found in box");
          }

          groups.add(ProgressGroup(
            id: "out_of_program",
            name: "方案外课程",
            required: 0, // Not displayed per requirement
            earned: earned,
            courses: outCourses, // Pre-populated
          ));
          debugPrint("Added '方案外课程' group with ${outCourses.length} courses");
          break; // Found the box, stop looking
        }
      }

      // Calculate "Major & Extra Credits" (主修与方案外获得学分)
      // Formula: In-Program Credits (已获得学分) + Out-of-Program Credits (方案外课程已获学分)
      // Since the HTML field might be populated by JS or not returned, we calculate it manually.
      
      // Try to find "Extra Credits" (Out of Program)
      String? extraCreditsStr;
      var extraCreditsEl = doc.querySelector('#lblAcquiredCreditsOutOfProg2');
      if (extraCreditsEl != null) {
        extraCreditsStr = extraCreditsEl.text.trim();
      }

      // Try to calculate from In-Program + Out-of-Program
      var inProgInfo = basicInfo.firstWhere((i) => i.label == "已获得学分", orElse: () => ProgressInfo(label: "", value: ""));
      
      if (inProgInfo.value.isNotEmpty && extraCreditsStr != null) {
          double inProg = double.tryParse(inProgInfo.value) ?? 0;
          double outProg = double.tryParse(extraCreditsStr) ?? 0;
          double total = inProg + outProg;
          String value = total % 1 == 0 ? total.toInt().toString() : total.toString();
          
          // Remove existing if any (e.g. from table scan)
          basicInfo.removeWhere((i) => i.label == "主修与方案外获得学分");
          basicInfo.insert(0, ProgressInfo(label: "主修与方案外获得学分", value: value));
      } else {
        // Fallback: Sum up groups if calculation failed
        bool hasTotalCredits = basicInfo.any((i) => i.label.contains("主修与方案外获得学分"));
        if (!hasTotalCredits && groups.isNotEmpty) {
          double total = 0;
          for (var g in groups) {
            total += g.earned;
          }
          // Format: 110.0 -> 110, 110.5 -> 110.5
          String value = total % 1 == 0 ? total.toInt().toString() : total.toString();
          
          // Insert at the beginning or appropriate position
          basicInfo.insert(0, ProgressInfo(label: "主修与方案外获得学分", value: value));
        }
      }
      
      return {
        "groups": groups,
        "info": basicInfo,
      };
    } catch (e) {
      debugPrint("Get progress failed: $e");
      rethrow;
    }
  }

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
