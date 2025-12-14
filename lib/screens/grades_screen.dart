import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/data_provider.dart';

class GradesScreen extends StatefulWidget {
  const GradesScreen({super.key});

  @override
  State<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends State<GradesScreen> {
  String _selectedSemester = '全部';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DataProvider>(context, listen: false).loadGrades();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dataProvider = Provider.of<DataProvider>(context);
    final grades = dataProvider.grades;

    if (dataProvider.gradesLoading && grades.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (grades.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text("暂无成绩数据", style: TextStyle(color: Colors.grey)),
            TextButton(
              onPressed: () => dataProvider.loadGrades(forceRefresh: true), 
              child: const Text("刷新")
            )
          ],
        ),
      );
    }

    // Get unique semesters
    final semesters = ['全部', ...grades.map((e) => e.semester).toSet().toList()..sort((a, b) => b.compareTo(a))];
    
    if (!semesters.contains(_selectedSemester)) {
      _selectedSemester = '全部';
    }

    final filteredGrades = _selectedSemester == '全部'
        ? grades
        : grades.where((g) => g.semester == _selectedSemester).toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.white,
          child: Row(
            children: [
              const Icon(Icons.filter_list, size: 20, color: Colors.grey),
              const SizedBox(width: 8),
              const Text("学期筛选: ", style: TextStyle(fontSize: 16)),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedSemester,
                    items: semesters.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      setState(() {
                        _selectedSemester = newValue!;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => dataProvider.loadGrades(forceRefresh: true),
            child: filteredGrades.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 100),
                      Center(child: Text("该学期暂无成绩")),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredGrades.length,
                    cacheExtent: 2000,
                    itemBuilder: (context, index) {
                      final grade = filteredGrades[index];
                      // 提取 Card 构建逻辑
                      final card = Card(
                        elevation: 0,
                        color: Colors.white,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.withOpacity(0.1)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      grade.courseName,
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: double.tryParse(grade.score) != null && double.parse(grade.score) < 60 
                                          ? Colors.red.withOpacity(0.1) 
                                          : const Color(0xFFECF5FF),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      grade.score,
                                      style: TextStyle(
                                        color: double.tryParse(grade.score) != null && double.parse(grade.score) < 60 
                                            ? Colors.red 
                                            : const Color(0xFF409EFF),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  _buildTag(Icons.calendar_today, grade.semester),
                                  const SizedBox(width: 12),
                                  _buildTag(Icons.class_, "${grade.credit} 学分"),
                                  const SizedBox(width: 12),
                                  _buildTag(Icons.grade, "绩点: ${grade.gpa}"),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );

                      // 性能优化：
                      // 1. 使用 RepaintBoundary 隔离重绘
                      // 2. 仅对前 10 个元素应用入场动画，后续元素直接显示，避免滚动时的动画计算开销
                      if (index < 10) {
                        return RepaintBoundary(
                          child: card.animate().fadeIn(
                            delay: (index * 50).ms, 
                            duration: 300.ms
                          ).slideX(begin: 0.1, end: 0),
                        );
                      } else {
                        return RepaintBoundary(child: card);
                      }
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildTag(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
