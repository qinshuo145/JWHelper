import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';

class GradesScreen extends StatefulWidget {
  const GradesScreen({super.key});

  @override
  State<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends State<GradesScreen> {
  String? _selectedSemester;

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

    // Get unique semesters using optimized getter
    final rawSemesters = dataProvider.semesterList;
    final allOptions = ['全部', ...rawSemesters];
    
    // Set default selection logic
    if (_selectedSemester == null) {
      // Default to the latest semester (first in the sorted list) if available
      if (rawSemesters.isNotEmpty) {
        _selectedSemester = rawSemesters.first;
      } else {
        _selectedSemester = '全部';
      }
    } else if (!allOptions.contains(_selectedSemester)) {
      // If selected semester is no longer valid, reset to default
      _selectedSemester = '全部';
    }

    final filteredGrades = _selectedSemester == '全部'
        ? grades
        : grades.where((g) => g.semester == _selectedSemester).toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Theme.of(context).cardTheme.color,
          child: Row(
            children: [
              const Icon(Icons.filter_list, size: 20, color: Colors.grey),
              const SizedBox(width: 8),
              Text("学期筛选: ", style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface)),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF409EFF)),
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 15, fontWeight: FontWeight.w500),
                      dropdownColor: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(12),
                      value: _selectedSemester,
                      items: allOptions.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setState(() {
                          _selectedSemester = newValue;
                        });
                      },
                    ),
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
                        color: Theme.of(context).cardTheme.color,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
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
                                          ? Colors.red.withValues(alpha: 0.1) 
                                          : const Color(0xFF409EFF).withValues(alpha: 0.1),
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

                      return card;
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
