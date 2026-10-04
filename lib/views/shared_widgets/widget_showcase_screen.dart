import 'package:flutter/material.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/leads/sortable_groupable_list_widget.dart';
import 'advanced_carousel.dart';

class SampleItem {
  final String title;
  final String subtitle;
  final String status;
  final DateTime dateTime;
  final String assignee;

  SampleItem({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.dateTime,
    required this.assignee,
  });
}

class WidgetShowcaseScreen extends StatelessWidget {
  const WidgetShowcaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sampleItems = [
      SampleItem(title: 'Rahul Sharma', subtitle: 'Interested in 3BHK Apartment', status: 'Hot', dateTime: DateTime.now().subtract(const Duration(hours: 2)), assignee: 'Amit Kumar'),
      SampleItem(title: 'Priya Verma', subtitle: 'Site visit scheduled for tomorrow', status: 'Warm', dateTime: DateTime.now().subtract(const Duration(days: 1)), assignee: 'Neha Singh'),
      SampleItem(title: 'Vikram Malhotra', subtitle: 'Booking amount received', status: 'Booked', dateTime: DateTime.now().subtract(const Duration(days: 3)), assignee: 'Amit Kumar'),
      SampleItem(title: 'Anita Desai', subtitle: 'Looking for commercial space', status: 'Cold', dateTime: DateTime.now().subtract(const Duration(days: 5)), assignee: 'Rahul Verma'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('RSWA Widget Showcase & Playground'),
        backgroundColor: const Color(0xFFFF6B22),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 1. Advanced Carousel Preview
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('Advanced Carousel Widget', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const AdvancedCarousel(
            imageUrls: [
              'https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?w=600',
              'https://images.unsplash.com/photo-1564013799919-ab600027ffc6?w=600',
              'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=600',
            ],
          ),
          const Divider(height: 24),
          // 2. Sortable & Groupable List View Preview
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.0),
            child: Text('Sortable & Groupable List Widget (with Search & Sort By)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          Expanded(
            child: SortableGroupableListWidget<SampleItem>(
              items: sampleItems,
              getTitle: (item) => item.title,
              getSubtitle: (item) => item.subtitle,
              getStatus: (item) => item.status,
              getDateTime: (item) => item.dateTime,
              getAssignee: (item) => item.assignee,
              itemBuilder: (item, index) => Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFFF6B22),
                    child: Text(item.title[0], style: const TextStyle(color: Colors.white)),
                  ),
                  title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.subtitle),
                      const SizedBox(height: 2),
                      Text('Assignee: ${item.assignee} | Status: ${item.status}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                  trailing: Chip(
                    label: Text(item.status, style: const TextStyle(fontSize: 10, color: Colors.white)),
                    backgroundColor: item.status == 'Hot' ? Colors.red : (item.status == 'Booked' ? Colors.green : Colors.orange),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        currentTab: 'dashboard',
        backgroundColor: Colors.white,
        activeIconColor: Colors.black87,
        activeLabelColor: Colors.black87,
        inactiveIconColor: Colors.grey,
      ),
    );
  }
}
