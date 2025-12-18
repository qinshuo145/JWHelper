import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/data_provider.dart';
import '../models/progress_item.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final Map<String, bool> _showAllMap = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DataProvider>(context, listen: false).loadProgress();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dataProvider = Provider.of<DataProvider>(context);
    final groups = dataProvider.progressGroups;

    Widget buildCourseItem(ProgressCourse course) {
      return Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.1))),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(course.name, style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 2),
                  Text("学分: ${course.credit}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: course.isPassed ? const Color(0xFFF0F9EB) : const Color(0xFFFEF0F0),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                course.score,
                style: TextStyle(
                  fontSize: 12,
                  color: course.isPassed ? const Color(0xFF67C23A) : const Color(0xFFF56C6C),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (dataProvider.progressLoading && groups.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () => dataProvider.loadProgress(forceRefresh: true),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Basic Info Card
          if (dataProvider.progressInfo.isNotEmpty)
            Card(
              elevation: 0,
              color: const Color(0xFF409EFF),
              margin: const EdgeInsets.only(bottom: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("学位课程绩点", style: TextStyle(color: Colors.white70, fontSize: 13)),
                              const SizedBox(height: 4),
                              Text(
                                (() {
                                  final val = dataProvider.progressInfo.firstWhere((i) => i.label.contains("学位课程绩点"), orElse: () => ProgressInfo(label: "", value: "-")).value;
                                  final match = RegExp(r'\d+(\.\d+)?').firstMatch(val);
                                  return match?.group(0) ?? (val.length > 4 ? val.substring(0, 4) : val);
                                })(),
                                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("主修与方案外获得学分", style: TextStyle(color: Colors.white70, fontSize: 13), overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Text(
                                dataProvider.progressInfo.firstWhere((i) => i.label.contains("主修与方案外获得学分"), orElse: () => ProgressInfo(label: "", value: "-")).value,
                                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("已获得学分", style: TextStyle(color: Colors.white70, fontSize: 13)),
                              const SizedBox(height: 4),
                              Text(
                                dataProvider.progressInfo.firstWhere((i) => i.label.contains("已获得学分"), orElse: () => ProgressInfo(label: "", value: "-")).value,
                                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("要求最低学分", style: TextStyle(color: Colors.white70, fontSize: 13)),
                              const SizedBox(height: 4),
                              Text(
                                dataProvider.progressInfo.firstWhere((i) => i.label.contains("要求最低学分"), orElse: () => ProgressInfo(label: "", value: "-")).value,
                                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn().slideY(begin: -0.2, end: 0),

          // Groups List
          ...groups.asMap().entries.map((entry) {
            final index = entry.key;
            final group = entry.value;
            
            double progress = group.required > 0 ? (group.earned / group.required) : 0;
            if (progress > 1) progress = 1;

            // Special handling for "Out of Program" group progress bar
            if (group.name == "方案外课程") {
              progress = 1.0; // Always full for extra credits
            }

            return Card(
              elevation: 0,
              color: Colors.white,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  title: Text(
                    group.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      if (group.name != "方案外课程") ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: const Color(0xFFEBEEF5),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              progress >= 1 ? const Color(0xFF67C23A) : const Color(0xFF409EFF),
                            ),
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "已修: ${group.earned}",
                            style: const TextStyle(color: Color(0xFF409EFF), fontWeight: FontWeight.bold),
                          ),
                          if (group.name != "方案外课程")
                            Text(
                              "要求: ${group.required}",
                              style: const TextStyle(color: Colors.grey),
                            ),
                        ],
                      ),
                    ],
                  ),
                  onExpansionChanged: (expanded) {
                    if (expanded && group.courses == null) {
                      dataProvider.loadGroupCourses(group);
                    }
                  },
                  children: [
                    if (group.courses == null)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (group.courses!.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text("该类别下暂无课程", style: TextStyle(color: Colors.grey)),
                      )
                    else ...[
                      ...group.courses!.where((c) => c.score != '-').map((course) => buildCourseItem(course)),
                      
                      if (group.courses!.any((c) => c.score == '-')) ...[
                        if (_showAllMap[group.id] == true)
                          ...group.courses!.where((c) => c.score == '-').map((course) => buildCourseItem(course)),
                          
                        Container(
                          decoration: BoxDecoration(
                            border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.1))),
                          ),
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () {
                              setState(() {
                                _showAllMap[group.id] = !(_showAllMap[group.id] ?? false);
                              });
                            },
                            child: Text(_showAllMap[group.id] == true ? "收起未修课程" : "查看未修课程 (${group.courses!.where((c) => c.score == '-').length})"),
                          ),
                        ),
                      ]
                    ],
                  ],
                ),
              ),
            ).animate().fadeIn(delay: (50 * index).ms).slideX();
          }),
        ],
      ),
    );
  }
}
