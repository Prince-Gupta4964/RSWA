import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../leads/lead_list_view.dart';

class DashboardView extends StatelessWidget {
  const DashboardView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchBar(),
          const SizedBox(height: 16),
          _buildStatusCards(),
          const SizedBox(height: 16),
          _buildFilterTabs(),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Recent Activities',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          const Expanded(
            child: LeadListView(),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 20.0),
        child: FloatingActionButton(
          onPressed: () {
            context.push('/add-lead');
          },
          backgroundColor: const Color(0xFFFF6B22),
          shape: const CircleBorder(),
          child: const Icon(Icons.add, color: Colors.white, size: 30),
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(context),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(icon: const Icon(Icons.menu, color: Colors.black), onPressed: () {}),
      title: const Text('Dashboard', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      actions: [
        IconButton(icon: const Icon(Icons.notifications_none, color: Colors.black), onPressed: () {}),
        IconButton(icon: const Icon(Icons.person_outline, color: Colors.black), onPressed: () {}),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            const Icon(Icons.search, color: Colors.grey),
            const SizedBox(width: 8),
            const Expanded(child: TextField(decoration: InputDecoration(hintText: 'Search for..', hintStyle: TextStyle(color: Colors.grey), border: InputBorder.none))),
            Padding(
              padding: const EdgeInsets.all(6.0),
              child: Container(
                decoration: BoxDecoration(color: const Color(0xFFFFE599), borderRadius: BorderRadius.circular(6)),
                child: IconButton(icon: const Icon(Icons.tune, color: Colors.orange, size: 20), onPressed: () {}),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCards() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          _statusCard('Urgent 3', Colors.red),
          const SizedBox(width: 12),
          _statusCard('Overdue 1', Colors.orange),
          const SizedBox(width: 12),
          _statusCard('IMP', const Color(0xFFD4AF37)),
        ],
      ),
    );
  }

  Widget _statusCard(String title, Color color) {
    return Container(
      width: 140, padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: color, width: 1.5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Immediate Follow-up', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Tap for Details', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          _activeTab('My View'), const SizedBox(width: 20),
          _inactiveTab('Done'), const SizedBox(width: 20),
          _inactiveTab('Assign'), const SizedBox(width: 20),
          _inactiveTab('Filter 1'), const SizedBox(width: 20),
          _inactiveTab('Filter 2'), const SizedBox(width: 20),
          Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Color(0xFFFFE599), shape: BoxShape.circle), child: const Icon(Icons.add, size: 16, color: Colors.orange))
        ],
      ),
    );
  }

  Widget _activeTab(String text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 4),
        Container(height: 2, width: 50, color: Colors.orange)
      ],
    );
  }

  Widget _inactiveTab(String text) {
    return Text(text, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14));
  }

  Widget _buildBottomNavBar(BuildContext context) {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white, border: Border.all(color: const Color(0xFFFF6B22), width: 1),
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
            icon: const Icon(Icons.home_outlined, color: Color(0xFFFF6B22), size: 30),
            onPressed: () {},
          ),

          // UPDATED: Ab yeh direct '/projects' yani list screen par le jayega
          IconButton(
            icon: const Icon(Icons.location_city_outlined, color: Color(0xFFFF6B22), size: 30),
            onPressed: () {
              context.push('/projects');
            },
          ),

          IconButton(icon: const Icon(Icons.person_outline, color: Color(0xFFFF6B22), size: 30), onPressed: () { context.push('/cp-list'); }),
          IconButton(icon: const Icon(Icons.bar_chart, color: Color(0xFFFF6B22), size: 30), onPressed: () {}),
          IconButton(icon: const Icon(Icons.outlined_flag, color: Color(0xFFFF6B22), size: 30), onPressed: () {}),
        ],
      ),
    );
  }
}