import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/cp_model.dart';
import '../../models/project_model.dart';
import '../../viewmodels/project_viewmodel.dart';
import '../../widgets/verified_p_badge.dart';

class DigitalVisitingCardView extends StatefulWidget {
  final CPModel cp;

  const DigitalVisitingCardView({super.key, required this.cp});

  @override
  State<DigitalVisitingCardView> createState() => _DigitalVisitingCardViewState();
}

class _DigitalVisitingCardViewState extends State<DigitalVisitingCardView> with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _shareProfile() {
    final baseUrl = Uri.base.origin.isNotEmpty ? Uri.base.origin : 'https://propertyplus.app';
    final shareLink = '$baseUrl/share/cp/${Uri.encodeComponent(widget.cp.fullName)}';
    final message = '🏢 *Digital Visiting Card — Property+*\n\n'
        '👤 *${widget.cp.fullName}*\n'
        '💼 Profession: ${widget.cp.profession.isNotEmpty ? widget.cp.profession : 'Channel Partner'}\n'
        '📞 Contact: ${widget.cp.contactNo}\n'
        '📍 Location: ${widget.cp.location.isNotEmpty ? widget.cp.location : 'N/A'}\n\n'
        '🔗 View Profile & Personal Projects:\n$shareLink';

    Share.share(message, subject: 'Digital Visiting Card | ${widget.cp.fullName}');
  }

  @override
  Widget build(BuildContext context) {
    final projectVM = Provider.of<ProjectViewModel>(context);
    final data = widget.cp.rawData;

    // Filter personal projects for this CP
    final cpProjects = projectVM.projects.where((project) {
      final createdBy = project.createdByUid;
      final addedBy = (project.rawData['addedBy'] ?? '').toString();
      final company = (project.propertyDetails['projectCompany'] ?? project.rawData['projectCompany'] ?? '').toString().toLowerCase();
      final cpName = widget.cp.cpName.toLowerCase();
      final fullName = widget.cp.fullName.toLowerCase();

      return project.builderIds.contains(widget.cp.id) ||
          createdBy == widget.cp.id ||
          addedBy == widget.cp.id ||
          (company.isNotEmpty && (company == cpName || company == fullName));
    }).toList();

    List<ProjectModel> filterByType(String type) {
      if (type == 'All') return cpProjects;
      return cpProjects.where((p) => p.propertyType.toLowerCase() == type.toLowerCase()).toList();
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        title: Text(
          '${widget.cp.fullName} — Visiting Card',
          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Color(0xFFFF6B22)),
            onPressed: _shareProfile,
            tooltip: 'Share Profile',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // ── Top Visiting Card Header ─────────────────────────────────────
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.white24,
                  backgroundImage: data['profilePhoto'] != null && data['profilePhoto'].toString().isNotEmpty
                      ? NetworkImage(data['profilePhoto'].toString())
                      : null,
                  child: (data['profilePhoto'] == null || data['profilePhoto'].toString().isEmpty)
                      ? Text(
                          widget.cp.fullName.isNotEmpty ? widget.cp.fullName[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  widget.cp.fullName,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.cp.profession.isNotEmpty ? widget.cp.profession : 'Real Estate Expert',
                  style: const TextStyle(fontSize: 13, color: Colors.white70, letterSpacing: 0.5),
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _headerInfoItem(
                      icon: Icons.phone_rounded,
                      label: 'Contact',
                      value: widget.cp.contactNo.isNotEmpty ? widget.cp.contactNo : 'N/A',
                      onTap: widget.cp.contactNo.isNotEmpty
                          ? () => launchUrl(Uri.parse('tel:${widget.cp.contactNo}'))
                          : null,
                    ),
                    Container(height: 30, width: 1, color: Colors.white24),
                    _headerInfoItem(
                      icon: Icons.location_on_rounded,
                      label: 'Office Location',
                      value: widget.cp.location.isNotEmpty
                          ? widget.cp.location
                          : (widget.cp.officeRef.isNotEmpty ? widget.cp.officeRef : 'N/A'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _shareProfile,
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('Share Digital Card'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B22),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Sub Tabs for Projects ────────────────────────────────────────
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFFFF6B22),
              unselectedLabelColor: Colors.grey.shade600,
              indicatorColor: const Color(0xFFFF6B22),
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(text: 'Project'),
                Tab(text: 'Flat'),
                Tab(text: 'Bungalow'),
                Tab(text: 'Plot'),
              ],
            ),
          ),

          // ── Tab View Content ─────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildProjectList(filterByType('All')),
                _buildProjectList(filterByType('Flat')),
                _buildProjectList(filterByType('Bungalow')),
                _buildProjectList(filterByType('Plot')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerInfoItem({required IconData icon, required String label, required String value, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: const Color(0xFFFF6B22)),
                const SizedBox(width: 4),
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.white60)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectList(List<ProjectModel> projects) {
    if (projects.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open_rounded, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'No personal projects found',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: projects.length,
      itemBuilder: (context, index) {
        final project = projects[index];
        final coverImage = project.coverImage;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 1,
          child: InkWell(
            onTap: () => context.push('/project-detail/${project.id}', extra: project),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 70,
                      height: 70,
                      child: coverImage != null && coverImage.isNotEmpty
                          ? Image.network(coverImage, fit: BoxFit.cover)
                          : Container(color: Colors.grey.shade200, child: const Icon(Icons.apartment, color: Colors.grey)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                project.projectName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (project.isLegallyVerified) ...[
                              const SizedBox(width: 6),
                              const VerifiedPBadge(compact: true),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          project.displayLocation,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF6B22).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                project.propertyType,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFFF6B22)),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              project.reraId,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
