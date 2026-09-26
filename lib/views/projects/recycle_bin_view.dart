import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../viewmodels/recycle_bin_viewmodel.dart'; // 🚀 NAYA
import '../../models/project_model.dart';
import '../../models/cp_model.dart';

class RecycleBinView extends StatefulWidget {
  const RecycleBinView({super.key});

  @override
  State<RecycleBinView> createState() => _RecycleBinViewState();
}

class _RecycleBinViewState extends State<RecycleBinView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<String> _selectedIds = <String>{}; // These will be the recyclebin doc IDs

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Selection clearing removed to allow cross-tab multi-select 🚀
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool get _isSelectionMode => _selectedIds.isNotEmpty;

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll(List<DocumentSnapshot> list) {
    final Set<String> currentTabIds = list.map((doc) => doc.id).toSet();
    
    setState(() {
      if (_selectedIds.containsAll(currentTabIds) && currentTabIds.isNotEmpty) {
        _selectedIds.removeAll(currentTabIds);
      } else {
        _selectedIds.addAll(currentTabIds);
      }
    });
  }

  Future<void> _handleRestore(RecycleBinViewModel recycleVM) async {
    if (_selectedIds.isEmpty) return;
    
    // Show progress
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Row(children: [SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)), SizedBox(width: 15), Text('Restoring items...')]), duration: Duration(seconds: 1)),
    );

    try {
      await recycleVM.restoreMultiple(_selectedIds.toList());
      
      setState(() => _selectedIds.clear());
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Items restored successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Restore failed: $e')));
      }
    }
  }

  Future<void> _handlePermanentDelete(RecycleBinViewModel recycleVM) async {
    if (_selectedIds.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${_selectedIds.length} items permanently?'),
        content: const Text('This action cannot be undone. Data will be gone forever.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('DELETE FOREVER', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Show progress
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Row(children: [SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)), SizedBox(width: 15), Text('Deleting items forever...')]), duration: Duration(seconds: 1)),
    );

    try {
      await recycleVM.deleteMultipleForever(_selectedIds.toList());
      
      setState(() => _selectedIds.clear());
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Items deleted permanently'), backgroundColor: Colors.black),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final recycleVM = Provider.of<RecycleBinViewModel>(context);
    
    final deletedProjects = recycleVM.deletedItems.where((doc) => doc['type'] == 'project').toList();
    final deletedCPs = recycleVM.deletedItems.where((doc) => doc['type'] == 'cp').toList();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _isSelectionMode ? '${_selectedIds.length} Selected' : 'Recycle Bin',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        leading: _isSelectionMode 
          ? IconButton(icon: const Icon(Icons.close, color: Colors.black), onPressed: () => setState(() => _selectedIds.clear()))
          : IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: const Icon(Icons.select_all_rounded, color: Colors.black87),
            tooltip: 'Select All',
            onPressed: () {
              final isProjectTab = _tabController.index == 0;
              _selectAll(isProjectTab ? deletedProjects : deletedCPs);
            },
          ),
          if (_isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.restore_from_trash_rounded, color: Colors.green),
              tooltip: 'Restore',
              onPressed: () => _handleRestore(recycleVM),
            ),
            IconButton(
              icon: const Icon(Icons.delete_forever_rounded, color: Colors.red),
              tooltip: 'Delete Forever',
              onPressed: () => _handlePermanentDelete(recycleVM),
            ),
          ]
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFFF6B22),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFFFF6B22),
          tabs: [
            Tab(text: 'Projects (${deletedProjects.length})'),
            Tab(text: 'Network (${deletedCPs.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDeletedList(deletedProjects, isProject: true),
          _buildDeletedList(deletedCPs, isProject: false),
        ],
      ),
    );
  }

  Widget _buildDeletedList(List<DocumentSnapshot> list, {required bool isProject}) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline_rounded, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('No ${isProject ? "projects" : "partners"} in bin', style: const TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: list.length,
      itemBuilder: (ctx, idx) {
        final doc = list[idx];
        final id = doc.id;
        final data = doc.data() as Map<String, dynamic>;
        final innerData = data['data'] as Map<String, dynamic>;
        
        final name = isProject 
            ? (innerData['projectName'] ?? 'Unnamed Project') 
            : (CPModel.fromMap(innerData, '').fullName);
            
        final isSelected = _selectedIds.contains(id);
        final deletedAt = data['deletedAt'];
        
        String dateStr = 'Recently';
        if (deletedAt is Timestamp) {
          dateStr = DateFormat('dd MMM, hh:mm a').format(deletedAt.toDate());
        }

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: isSelected ? Colors.blue : Colors.grey.shade200, width: isSelected ? 2 : 1),
          ),
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            onTap: () {
              if (_isSelectionMode) _toggleSelection(id);
            },
            onLongPress: () => _toggleSelection(id),
            leading: CircleAvatar(
              backgroundColor: isSelected ? Colors.blue : Colors.grey.shade100,
              child: Icon(
                isSelected ? Icons.check : (isProject ? Icons.business_rounded : Icons.person_rounded), 
                color: isSelected ? Colors.white : Colors.grey.shade600
              ),
            ),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Deleted on: $dateStr', style: const TextStyle(fontSize: 12)),
            trailing: _isSelectionMode 
              ? Checkbox(value: isSelected, onChanged: (_) => _toggleSelection(id))
              : const Icon(Icons.more_vert_rounded, color: Colors.grey),
          ),
        );
      },
    );
  }
}
