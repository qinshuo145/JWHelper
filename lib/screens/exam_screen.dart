import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/data_provider.dart';
import '../models/exam.dart';

class ExamScreen extends StatefulWidget {
  const ExamScreen({super.key});

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> {
  // Selections
  Semester? _selectedSemester;
  ExamRound? _selectedRound;
  String _selectedCampus = '济南';
  bool _initLoading = false;
  bool _roundsLoading = false;
  bool _refreshingFilters = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initData();
    });
  }

  Future<void> _initData() async {
    setState(() => _initLoading = true);
    await _loadSavedCampus();
    await _loadSemesters();
    setState(() => _initLoading = false);
  }

  Future<void> _loadSavedCampus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('exam_selected_campus');
      if (saved != null && (saved == '济南' || saved == '日照')) {
        if (mounted) {
          setState(() {
            _selectedCampus = saved;
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading saved campus: $e");
    }
  }

  Future<void> _saveCampus(String campus) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('exam_selected_campus', campus);
    } catch (e) {
      debugPrint("Error saving campus: $e");
    }
  }

  Future<void> _loadSemesters() async {
    final provider = Provider.of<DataProvider>(context, listen: false);
    await provider.loadExamSemesters();
    
    if (mounted && provider.examSemesters.isNotEmpty) {

      if (_selectedSemester == null || !provider.examSemesters.contains(_selectedSemester)) {
         setState(() {
          _selectedSemester = provider.examSemesters.first;
        });
        await _loadRounds();
      }
    }
  }

  List<ExamRound> _getSortedRounds(List<ExamRound> rounds) {
    if (rounds.isEmpty) return [];
    final sorted = List<ExamRound>.from(rounds);
    sorted.sort((a, b) {
      final aIsCurrent = a.name.contains(_selectedCampus);
      final bIsCurrent = b.name.contains(_selectedCampus);
      if (aIsCurrent && !bIsCurrent) return -1;
      if (!aIsCurrent && bIsCurrent) return 1;
      return 0; // Keep original order for same priority
    });
    return sorted;
  }

  void _autoSelectRound(List<ExamRound> rounds) {
    if (rounds.isEmpty) {
      _selectedRound = null;
      return;
    }

    final sorted = _getSortedRounds(rounds);
    
    // Try to find "Current Campus" + "Final Exam"
    try {
      _selectedRound = sorted.firstWhere(
        (r) => r.name.contains(_selectedCampus) && r.name.contains("期末考试"),
      );
    } catch (_) {
      // Fallback: First of sorted (which should be current campus if available)
      _selectedRound = sorted.first;
    }
  }

  Future<void> _loadRounds() async {
    if (_selectedSemester == null) return;
    setState(() {
      _roundsLoading = true;
      _selectedRound = null;
    });
    final provider = Provider.of<DataProvider>(context, listen: false);
    
    await provider.loadExamRounds(_selectedSemester!.id);
    
    if (mounted) {
      setState(() => _roundsLoading = false);
      if (provider.examRounds.isNotEmpty) {
        setState(() {
          _autoSelectRound(provider.examRounds);
        });
        _loadExams();
      } else {
        setState(() {
          _selectedRound = null;
        });
      }
    }
  }

  Future<void> _loadExams() async {
    if (_selectedRound == null || _selectedSemester == null) return;
    final provider = Provider.of<DataProvider>(context, listen: false);
    await provider.loadExams(_selectedSemester!.id, _selectedRound!.id);
  }

  Future<void> _handleRefresh() async {
    setState(() => _refreshingFilters = true);
    final provider = Provider.of<DataProvider>(context, listen: false);
    
    try {
      // 1. Refresh Semesters
      await provider.loadExamSemesters(forceRefresh: true);
      
      if (mounted) {
        if (provider.examSemesters.isNotEmpty) {
           if (_selectedSemester == null || !provider.examSemesters.contains(_selectedSemester)) {
             _selectedSemester = provider.examSemesters.first;
           }
        } else {
          _selectedSemester = null;
        }
      }

      // 2. Refresh Rounds
      if (_selectedSemester != null) {
        await provider.loadExamRounds(_selectedSemester!.id, forceRefresh: true);
        
        if (mounted) {
          if (provider.examRounds.isNotEmpty) {
             // Re-run auto select logic if current selection is invalid or just to be safe?
             // If we want to keep user selection if valid, we check contains.
             // But user asked for "Default display current campus final exam", maybe on refresh too?
             // Let's stick to: if invalid, auto select.
             if (_selectedRound == null || !provider.examRounds.contains(_selectedRound)) {
               _autoSelectRound(provider.examRounds);
             }
          } else {
            _selectedRound = null;
          }
        }
      } else {
        _selectedRound = null;
      }

      // 3. Refresh Exams
      if (_selectedSemester != null && _selectedRound != null) {
        await provider.loadExams(_selectedSemester!.id, _selectedRound!.id, forceRefresh: true);
      }

    } catch (e) {
      debugPrint("Refresh failed: $e");
    } finally {
      if (mounted) {
        setState(() => _refreshingFilters = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("考试安排", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFECF5FF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFD9ECFF)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCampus,
                isDense: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF409EFF), size: 18),
                style: const TextStyle(color: Color(0xFF409EFF), fontWeight: FontWeight.bold, fontSize: 14),
                borderRadius: BorderRadius.circular(12),
                items: const [
                  DropdownMenuItem(value: "济南", child: Text("济南校区")),
                  DropdownMenuItem(value: "日照", child: Text("日照校区")),
                ],
                onChanged: (value) {
                  if (value != null && value != _selectedCampus) {
                    setState(() {
                      _selectedCampus = value;
                      _saveCampus(value);
                      // Re-sort and auto-select when campus changes
                      final provider = Provider.of<DataProvider>(context, listen: false);
                      if (provider.examRounds.isNotEmpty) {
                        _autoSelectRound(provider.examRounds);
                      }
                    });
                    // Reload exams for the new selection
                    _loadExams();
                  }
                },
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                // Semester Dropdown
                Selector<DataProvider, List<Semester>>(
                  selector: (_, p) => p.examSemesters,
                  builder: (context, semesters, _) {
                    final effectiveSelectedSemester = semesters.contains(_selectedSemester) ? _selectedSemester : null;
                    return DropdownButtonFormField<Semester>(
                      initialValue: effectiveSelectedSemester,
                      menuMaxHeight: 300,
                      hint: const Text("请选择学期"),
                      decoration: InputDecoration(
                        labelText: "学期",
                        prefixIcon: const Icon(Icons.calendar_today_outlined, size: 20, color: Color(0xFF409EFF)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(color: Color(0xFF409EFF), width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      icon: const Icon(Icons.arrow_drop_down_circle_outlined, color: Color(0xFF409EFF)),
                      dropdownColor: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      style: const TextStyle(color: Colors.black87, fontSize: 15),
                      items: (semesters.isEmpty || _initLoading || _refreshingFilters) ? null : semesters.map((s) {
                        return DropdownMenuItem(
                          value: s,
                          child: Text(s.name, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (semesters.isEmpty || _initLoading || _refreshingFilters) ? null : (value) {
                        if (value != null && value != _selectedSemester) {
                          setState(() => _selectedSemester = value);
                          _loadRounds();
                        }
                      },
                      disabledHint: (_initLoading || _refreshingFilters) ? const Text("正在加载学期...") : const Text("暂无学期数据"),
                    );
                  }
                ),
                
                const SizedBox(height: 12),
                
                // Round Dropdown
                Selector<DataProvider, List<ExamRound>>(
                  selector: (_, p) => p.examRounds,
                  builder: (context, roundsRaw, _) {
                    final rounds = _getSortedRounds(roundsRaw);
                    final effectiveSelectedRound = rounds.contains(_selectedRound) ? _selectedRound : null;
                    
                    return DropdownButtonFormField<ExamRound>(
                      key: ValueKey("rounds_$_selectedCampus"),
                      initialValue: effectiveSelectedRound,
                      menuMaxHeight: 300,
                      hint: const Text("请选择考试批次"),
                      decoration: InputDecoration(
                        labelText: "考试批次",
                        prefixIcon: const Icon(Icons.layers_outlined, size: 20, color: Color(0xFF409EFF)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(color: Color(0xFF409EFF), width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      icon: const Icon(Icons.arrow_drop_down_circle_outlined, color: Color(0xFF409EFF)),
                      dropdownColor: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      style: const TextStyle(color: Colors.black87, fontSize: 15),
                      items: (rounds.isEmpty || _roundsLoading || _refreshingFilters) ? null : rounds.map((r) {
                        return DropdownMenuItem(
                          value: r,
                          child: Text(r.name),
                        );
                      }).toList(),
                      onChanged: (rounds.isEmpty || _roundsLoading || _refreshingFilters) ? null : (value) {
                        if (value != null && value != _selectedRound) {
                          setState(() => _selectedRound = value);
                          _loadExams();
                        }
                      },
                      disabledHint: _selectedSemester == null 
                          ? const Text("请先选择学期") 
                          : ((_roundsLoading || _refreshingFilters) ? const Text("正在加载批次...") : const Text("暂无考试批次")),
                    );
                  }
                ),
              ],
            ),
          ),
          
          // Content
          Expanded(
            child: RefreshIndicator(
              onRefresh: _handleRefresh,
              child: Consumer<DataProvider>(
                builder: (context, provider, _) {
                  final isLoading = (provider.examsLoading && !_refreshingFilters) || _initLoading;
                  return _buildContent(provider, isLoading);
                }
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(DataProvider provider, bool isLoading) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Helper to make empty states scrollable for RefreshIndicator
    Widget buildScrollableState(Widget child) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: child,
            ),
          );
        },
      );
    }

    if (provider.examSemesters.isEmpty) {
       return buildScrollableState(
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              const Text("无法获取学期信息", style: TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _initData,
                child: const Text("重试"),
              ),
            ],
          ),
        ),
      );
    }

    if (provider.examRounds.isEmpty && _selectedSemester != null) {
      return buildScrollableState(
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.assignment_outlined, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text("该学期暂无考试安排", style: TextStyle(color: Colors.grey[600])),
            ],
          ),
        ),
      );
    }

    if (provider.exams.isEmpty) {
      return buildScrollableState(
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.assignment_turned_in_outlined, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text("未找到考试记录", style: TextStyle(color: Colors.grey[600])),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: provider.exams.length,
      itemBuilder: (context, index) {
        final exam = provider.exams[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        exam.courseName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF303133),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6F7FF),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF91D5FF)),
                      ),
                      child: Text(
                        exam.type,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF1890FF)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  "课程号: ${exam.courseNo}",
                  style: const TextStyle(fontSize: 12, color: Color(0xFF909399)),
                ),
                const Divider(height: 24),
                _buildInfoRow(Icons.access_time, "时间", exam.time),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.location_on_outlined, "地点", exam.location),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.numbers, "课序号", exam.classNo),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.info_outline, "缓考状态", exam.applyStatus),
              ],
            ),
          ),
        ).animate().fadeIn(delay: (50 * index).ms).slideY(begin: 0.1, end: 0);
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF909399)),
        const SizedBox(width: 8),
        Text("$label: ", style: const TextStyle(color: Color(0xFF909399))),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Color(0xFF606266), fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
