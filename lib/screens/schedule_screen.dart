import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';
import '../models/schedule_item.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DataProvider>(context, listen: false).loadSchedule();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dataProvider = Provider.of<DataProvider>(context);
    final items = dataProvider.schedule;
    final theme = Theme.of(context);

    if (dataProvider.scheduleLoading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // Simple Grid View for Schedule
    // 7 days x 6 slots (approx)
    // For mobile, maybe a list grouped by day is better?
    // Let's do a TabView for each day.
    
    return DefaultTabController(
      length: 7,
      initialIndex: DateTime.now().weekday - 1,
      child: Column(
        children: [
          Container(
            color: theme.cardTheme.color,
            child: const TabBar(
              isScrollable: false,
              labelPadding: EdgeInsets.zero,
              labelColor: Color(0xFF409EFF),
              unselectedLabelColor: Colors.grey,
              indicatorColor: Color(0xFF409EFF),
              tabs: [
                Tab(text: "周一"),
                Tab(text: "周二"),
                Tab(text: "周三"),
                Tab(text: "周四"),
                Tab(text: "周五"),
                Tab(text: "周六"),
                Tab(text: "周日"),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: List.generate(7, (dayIndex) {
                // Use optimized getter from provider
                final groupedSchedule = dataProvider.scheduleGroupedByDay;
                final dayItems = groupedSchedule[dayIndex] ?? [];
                
                if (dayItems.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () => dataProvider.loadSchedule(forceRefresh: true),
                    child: ListView(
                      children: const [
                        SizedBox(height: 100),
                        Center(child: Text("今天没有课哦 ~", style: TextStyle(color: Colors.grey))),
                      ],
                    ),
                  );
                }

                // Group items by start unit to handle overlaps
                Map<int, List<ScheduleItem>> groupedItems = {};
                for (var item in dayItems) {
                  if (!groupedItems.containsKey(item.startUnit)) {
                    groupedItems[item.startUnit] = [];
                  }
                  groupedItems[item.startUnit]!.add(item);
                }

                // Sort groups by start unit
                var sortedKeys = groupedItems.keys.toList()..sort();
                                
                // Helper to process a group
                Widget processGroup(int startUnit) {
                  var group = groupedItems[startUnit]!;
                  return _CourseGroup(items: group, currentWeek: dataProvider.currentWeek);
                }

                List<Widget> morningWidgets = [];
                List<Widget> afternoonWidgets = [];
                List<Widget> eveningWidgets = [];

                for (var key in sortedKeys) {
                  var item = groupedItems[key]!.first; // Representative for time check
                  var widget = processGroup(key);
                  
                  if (item.startPeriod <= 4) {
                    morningWidgets.add(widget);
                  } else if (item.startPeriod <= 8) {
                    afternoonWidgets.add(widget);
                  } else {
                    eveningWidgets.add(widget);
                  }
                }

                return RefreshIndicator(
                  onRefresh: () => dataProvider.loadSchedule(forceRefresh: true),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (morningWidgets.isNotEmpty) ...[
                        _buildSectionHeader("上午"),
                        ...morningWidgets,
                        const SizedBox(height: 16),
                      ],
                      if (afternoonWidgets.isNotEmpty) ...[
                        _buildSectionHeader("下午"),
                        ...afternoonWidgets,
                        const SizedBox(height: 16),
                      ],
                      if (eveningWidgets.isNotEmpty) ...[
                        _buildSectionHeader("晚上"),
                        ...eveningWidgets,
                      ],
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4, left: 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: const Color(0xFF409EFF),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseGroup extends StatefulWidget {
  final List<ScheduleItem> items;
  final int currentWeek;

  const _CourseGroup({required this.items, required this.currentWeek});

  @override
  State<_CourseGroup> createState() => _CourseGroupState();
}

class _CourseGroupState extends State<_CourseGroup> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    // Sort: Current -> Upcoming -> Finished
    var sortedItems = List<ScheduleItem>.from(widget.items);
    sortedItems.sort((a, b) {
      int getScore(ScheduleItem item) {
        if (widget.currentWeek >= item.weekStart && widget.currentWeek <= item.weekEnd) return 0; // Current
        if (widget.currentWeek < item.weekStart) return 1; // Upcoming
        return 2; // Finished
      }
      return getScore(a).compareTo(getScore(b));
    });

    final primaryItem = sortedItems.first;
    final otherItems = sortedItems.skip(1).toList();

    if (otherItems.isEmpty) {
      return _buildCourseCard(primaryItem);
    }

    return Column(
      children: [
        Stack(
          children: [
            _buildCourseCard(primaryItem),
            Positioned(
              right: 8,
              top: 8,
              child: InkWell(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color?.withValues(alpha: 0.8) ?? Colors.white.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                    boxShadow: [
                       BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 2)
                    ]
                  ),
                  child: Icon(
                    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 20,
                    color: Colors.blue,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_isExpanded)
          ...otherItems.map((item) => Padding(
            padding: const EdgeInsets.only(left: 16.0), // Indent secondary items
            child: _buildCourseCard(item, isSecondary: true),
          )),
      ],
    );
  }

  Widget _buildCourseCard(ScheduleItem item, {bool isSecondary = false}) {
    bool isCurrent = widget.currentWeek >= item.weekStart && widget.currentWeek <= item.weekEnd;
    bool isFinished = widget.currentWeek > item.weekEnd;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    Color bgColor;
    Color accentColor;
    Color textColor;
    
    if (isCurrent) {
      bgColor = isDark ? const Color(0xFF1B2E1B) : const Color(0xFFF0F9EB);
      accentColor = const Color(0xFF67C23A);
      textColor = isDark ? Colors.white : Colors.black;
    } else if (isFinished) {
      bgColor = isDark ? const Color(0xFF2C2C2C) : Colors.grey[100]!;
      accentColor = Colors.grey;
      textColor = Colors.grey;
    } else {
      bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
      accentColor = const Color(0xFF409EFF);
      textColor = isDark ? Colors.white : Colors.black;
    }

    if (isSecondary) {
       // Secondary items might override bg slightly if not current
       if (!isCurrent && !isFinished) bgColor = isDark ? const Color(0xFF252525) : Colors.grey[50]!;
    }

    return Card(
      elevation: 0,
      color: bgColor,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isCurrent ? accentColor.withValues(alpha: .3) : Colors.grey.withValues(alpha: .1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${item.teacher} #${item.classroom}${item.weekStart > 0 && item.weekEnd > 0 ? ' @${item.weekStart}-${item.weekEnd}周' : ''}",
                    style: TextStyle(color: isFinished ? Colors.grey : Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isCurrent ? (isDark ? const Color(0xFF1B2E1B) : const Color(0xFFF0F9EB)) : (isDark ? const Color(0xFF2C2C2C) : Colors.grey[100]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                item.periodString,
                style: TextStyle(color: isCurrent ? const Color(0xFF67C23A) : Colors.grey, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
