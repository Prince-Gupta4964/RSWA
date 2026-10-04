import 'package:flutter/material.dart';

enum SortOption { dateNewest, dateOldest, nameAZ, nameZA, status }
enum GroupOption { none, status, assignee, date }

class SortableGroupableListWidget<T> extends StatefulWidget {
  final List<T> items;
  final String Function(T item) getTitle;
  final String Function(T item) getSubtitle;
  final String Function(T item) getStatus;
  final DateTime? Function(T item) getDateTime;
  final String Function(T item) getAssignee;
  final Widget Function(T item, int index) itemBuilder;

  const SortableGroupableListWidget({
    super.key,
    required this.items,
    required this.getTitle,
    required this.getSubtitle,
    required this.getStatus,
    required this.getDateTime,
    required this.getAssignee,
    required this.itemBuilder,
  });

  @override
  State<SortableGroupableListWidget<T>> createState() => _SortableGroupableListWidgetState<T>();
}

class _SortableGroupableListWidgetState<T> extends State<SortableGroupableListWidget<T>> {
  SortOption _currentSort = SortOption.dateNewest;
  GroupOption _currentGroup = GroupOption.none;
  String _searchQuery = '';

  List<T> get _processedItems {
    var list = List<T>.from(widget.items);

    if (_searchQuery.isNotEmpty) {
      list = list.where((item) {
        final title = widget.getTitle(item).toLowerCase();
        final subtitle = widget.getSubtitle(item).toLowerCase();
        return title.contains(_searchQuery.toLowerCase()) || subtitle.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    list.sort((a, b) {
      switch (_currentSort) {
        case SortOption.dateNewest:
          final dtA = widget.getDateTime(a) ?? DateTime(2000);
          final dtB = widget.getDateTime(b) ?? DateTime(2000);
          return dtB.compareTo(dtA);
        case SortOption.dateOldest:
          final dtA = widget.getDateTime(a) ?? DateTime(2000);
          final dtB = widget.getDateTime(b) ?? DateTime(2000);
          return dtA.compareTo(dtB);
        case SortOption.nameAZ:
          return widget.getTitle(a).compareTo(widget.getTitle(b));
        case SortOption.nameZA:
          return widget.getTitle(b).compareTo(widget.getTitle(a));
        case SortOption.status:
          return widget.getStatus(a).compareTo(widget.getStatus(b));
      }
    });

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final items = _processedItems;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Search items...',
                  prefixIcon: const Icon(Icons.search, color: Color(0xFFFF6B22)),
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFF6B22), width: 1.5)),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
                      child: Row(
                        children: [
                          const Text('Sort: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          Expanded(
                            child: DropdownButton<SortOption>(
                              value: _currentSort,
                              isExpanded: true,
                              underline: const SizedBox(),
                              items: const [
                                DropdownMenuItem(value: SortOption.dateNewest, child: Text('Newest First', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: SortOption.dateOldest, child: Text('Oldest First', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: SortOption.nameAZ, child: Text('Name (A-Z)', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: SortOption.nameZA, child: Text('Name (Z-A)', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: SortOption.status, child: Text('Status', style: TextStyle(fontSize: 12))),
                              ],
                              onChanged: (v) => setState(() => _currentSort = v!),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
                      child: Row(
                        children: [
                          const Text('Group: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          Expanded(
                            child: DropdownButton<GroupOption>(
                              value: _currentGroup,
                              isExpanded: true,
                              underline: const SizedBox(),
                              items: const [
                                DropdownMenuItem(value: GroupOption.none, child: Text('None', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: GroupOption.status, child: Text('By Status', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: GroupOption.assignee, child: Text('By Assignee', style: TextStyle(fontSize: 12))),
                              ],
                              onChanged: (v) => setState(() => _currentGroup = v!),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? const Center(child: Text('No results found.', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) => widget.itemBuilder(items[index], index),
                ),
        ),
      ],
    );
  }
}
