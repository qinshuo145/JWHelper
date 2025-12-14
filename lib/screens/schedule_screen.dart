import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';

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

    if (dataProvider.scheduleLoading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // Simple Grid View for Schedule
    // 7 days x 6 slots (approx)
    // For mobile, maybe a list grouped by day is better?
    // Let's do a TabView for each day.
    
    return DefaultTabController(
      length: 7,
      child: Column(
        children: [
          Container(
            color: Colors.white,
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
                var dayItems = items.where((e) => e.dayIndex == dayIndex).toList();
                dayItems.sort((a, b) => a.startUnit.compareTo(b.startUnit));
                
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

                return RefreshIndicator(
                  onRefresh: () => dataProvider.loadSchedule(forceRefresh: true),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: dayItems.length,
                    itemBuilder: (context, index) {
                      final item = dayItems[index];
                      return Card(
                        elevation: 0,
                        color: Colors.white,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.withOpacity(0.1)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF409EFF),
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
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "${item.teacher} @ ${item.classroom}",
                                      style: const TextStyle(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0F9EB),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  item.periodString,
                                  style: const TextStyle(color: Color(0xFF67C23A), fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
