import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/cp_model.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/cp_viewmodel.dart';
import '../../viewmodels/lead_viewmodel.dart';
import '../../utils/role_permissions.dart';
import '../../widgets/app_bottom_nav.dart';

class CPListView extends StatefulWidget {
  const CPListView({super.key});

  @override
  State<CPListView> createState() => _CPListViewState();
}

class _CPListViewState extends State<CPListView> with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authVM = Provider.of<AuthViewModel>(context);
    final cpVM = Provider.of<CPViewModel>(context);
    final leadVM = Provider.of<LeadViewModel>(context);

    // No access fallback UI
    if (!authVM.permissions.dashboardTabs.contains('cp')) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'Channel Partners',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => context.go('/dashboard'),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 52, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                const Text(
                  'Channel Partner access is not enabled for your role.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your available dashboard sections are still accessible.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, height: 1.4),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: const AppBottomNav(
          currentTab: 'dashboard',
          backgroundColor: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          border: Border.fromBorderSide(
            BorderSide(color: Color(0xFFFF6B22), width: 1),
          ),
          activeBackgroundColor: Color(0xFFFF6B22),
          activeIconColor: Colors.white,
          activeLabelColor: Color(0xFFFF6B22),
          inactiveIconColor: Color(0xFFFF6B22),
        ),
      );
    }

    // List calculations
    final allCPs = authVM.appRole == AppRole.cp
        ? cpVM.cps.where((cp) => cp.parentUid == authVM.userUid).toList()
        : cpVM.cps;

    final activeCPs = allCPs.where((cp) => _isActive(cp.status)).toList();
    final inactiveCPs = allCPs.where((cp) => !_isActive(cp.status)).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF6B22),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Channel Partners',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.search, color: Colors.white),
          ),
        ],
      ),
      body: cpVM.isLoading
          ? const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF6B22)),
      )
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🚀 NAYA: Clean text tabs with underline (No Containers)
          Container(
            color: Colors.white,
            width: double.infinity,
            child: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFFFF6B22),
              indicatorWeight: 3.0,
              dividerColor: Colors.transparent,
              labelColor: Colors.black,
              labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
              unselectedLabelColor: Colors.grey.shade500,
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              tabs: [
                Tab(text: 'All (${allCPs.length})'),
                Tab(text: 'Active (${activeCPs.length})'),
                Tab(text: 'Inactive (${inactiveCPs.length})'),
              ],
            ),
          ),
          const SizedBox(height: 4), // Thoda space tabs aur list ke beech

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCPList(allCPs, leadVM),
                _buildCPList(activeCPs, leadVM),
                _buildCPList(inactiveCPs, leadVM),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 20.0),
        child: FloatingActionButton(
          onPressed: () => context.push('/add-cp'),
          backgroundColor: const Color(0xFFFF6B22),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(
        currentTab: 'cp',
        backgroundColor: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        border: Border.fromBorderSide(
          BorderSide(color: Color(0xFFFF6B22), width: 1),
        ),
        activeBackgroundColor: Color(0xFFFF6B22),
        activeIconColor: Colors.white,
        activeLabelColor: Color(0xFFFF6B22),
        inactiveIconColor: Color(0xFFFF6B22),
      ),
    );
  }

  // Helper method for generating the individual CP Lists
  Widget _buildCPList(List<CPModel> list, LeadViewModel leadVM) {
    if (list.isEmpty) {
      return const Center(
        child: Text(
          'No Channel Partners found for this category.',
          style: TextStyle(color: Colors.grey, fontSize: 15),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      itemCount: list.length,
      separatorBuilder: (context, index) => const Divider(
        height: 1,
        thickness: 1,
        color: Color(0xFFECECEC),
        indent: 80,
        endIndent: 12,
      ),
      itemBuilder: (context, index) {
        final cp = list[index];
        final leadCount = _leadCountForCP(cp, leadVM);

        return InkWell(
          onTap: () => context.push('/cp-detail', extra: cp),
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAvatar(cp.cpName),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  cp.cpName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                cp.status.isEmpty ? 'Inactive' : cp.status,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _isActive(cp.status)
                                      ? const Color(0xFFFF6B22)
                                      : Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${cp.location.isEmpty ? "No location" : cp.location}${cp.addedBy != null ? " • Added by: ${cp.addedBy}" : ""}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            cp.contactNo.isNotEmpty
                                ? cp.contactNo
                                : (cp.profession.isNotEmpty
                                ? cp.profession
                                : 'No contact number'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$leadCount leads',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildCountButton(leadCount),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _isActive(String status) => status.trim().toLowerCase() == 'active';

  int _leadCountForCP(CPModel cp, LeadViewModel leadVM) {
    return leadVM.leads.where((lead) {
      final source = lead.rawData['source']?.toString().toLowerCase() ?? '';
      final caller = lead.rawData['caller']?.toString().toLowerCase() ?? '';
      final cpNameStr = cp.cpName.toLowerCase();
      return source == cpNameStr || caller == cpNameStr;
    }).length;
  }

  Widget _buildAvatar(String name) {
    final firstLetter = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

    return Container(
      width: 56,
      height: 56,
      decoration: const BoxDecoration(
        color: Color(0xFFFFF1EA),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          firstLetter,
          style: const TextStyle(
            color: Color(0xFFFF6B22),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildCountButton(int count) {
    return Container(
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: count > 0 ? const Color(0xFFFF6B22) : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Center(
        child: Text(
          '$count',
          style: TextStyle(
            color: count > 0 ? Colors.white : Colors.grey.shade700,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}