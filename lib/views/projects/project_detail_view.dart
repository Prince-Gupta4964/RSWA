import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart'; // 🚀 NAYA: For mouse/trackpad drag on web
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart'; // 🚀 NAYA
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/project_model.dart';
import '../../models/builder_model.dart';
import '../../models/cp_model.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/project_viewmodel.dart';
import '../../viewmodels/lead_viewmodel.dart';
import '../../viewmodels/builder_viewmodel.dart';
import '../../utils/role_permissions.dart';
import '../../utils/meta_tag_helper.dart'; // 🚀 NAYA

class ProjectDetailView extends StatefulWidget {
  final ProjectModel project;
  final bool isPublicView; // 🚀 NAYA
  const ProjectDetailView({super.key, required this.project, this.isPublicView = false});

  @override
  State<ProjectDetailView> createState() => _ProjectDetailViewState();
}

class _ProjectDetailViewState extends State<ProjectDetailView> with TickerProviderStateMixin {
  final Map<String, bool> _sectionStates = {
    'Basic Info': true,
    'Property Details': false,
    'Amenities & USP': false,
    'Legal Details': false,
    'Media & Gallery': false,
    'Associated Builders': false,
    'Associated Leads': false,
    'Admin Controls': false,
  };

  late TabController _tabController;

  final TextEditingController _wingCtrl = TextEditingController();
  final TextEditingController _unitNoCtrl = TextEditingController();
  final TextEditingController _areaCtrl = TextEditingController();
  String _selectedInventoryStatus = 'Available';
  bool _isLiked = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _wingCtrl.dispose();
    _unitNoCtrl.dispose();
    _areaCtrl.dispose();
    super.dispose();
  }

  void _globalToggle() {
    bool allOpen = _sectionStates.values.every((v) => v);
    setState(() {
      _sectionStates.updateAll((key, value) => !allOpen);
    });
  }

  Future<void> _makeCall(String? number) async {
    if (number == null || number.isEmpty) return;
    final Uri url = Uri.parse('tel:$number');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  Future<void> _openFile(String? url) async {
    if (url == null || url.isEmpty) return;
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final projectVM = context.watch<ProjectViewModel>();
    final authVM = context.watch<AuthViewModel>();
    final leadVM = Provider.of<LeadViewModel>(context);
    final builderVM = Provider.of<BuilderViewModel>(context);
    
    final project = projectVM.projects.firstWhere((p) => p.id == widget.project.id, orElse: () => widget.project);
    final data = project.rawData;
    final details = project.propertyDetails;

    final associatedBuilders = builderVM.builders.where((b) {
      final bool linkedById = project.builderIds.contains(b.id);
      final projCompany = (details['projectCompany'] ?? project.rawData['projectCompany'] ?? '').toString().trim().toLowerCase();
      return linkedById || b.companyNames.any((c) => c.trim().toLowerCase() == projCompany);
    }).toList();

    final List<dynamic> rawImages = (details['images'] is Iterable) ? details['images'] : [];
    final List<String> imageUrls = rawImages.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
    final String? coverImage = imageUrls.isNotEmpty ? imageUrls.first : null;

    final associatedLeads = leadVM.leads.where((l) {
      final leadProjectName = (l.rawData['project'] ?? '').toString().trim().toLowerCase();
      final currentProjectName = project.projectName.trim().toLowerCase();
      return leadProjectName == currentProjectName && leadProjectName.isNotEmpty;
    }).toList();

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { 
        if (!didPop) {
          if (widget.isPublicView) {
            _showPublicExitDialog(context);
          } else {
            context.go('/projects');
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverAppBar(
              expandedHeight: 440, pinned: true, backgroundColor: Colors.white, elevation: 0,
              leading: _headerCircle(Icons.arrow_back, () {
                if (widget.isPublicView) {
                  _showPublicExitDialog(context);
                } else {
                  context.go('/projects');
                }
              }),
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 440,
                      child: _ProjectHeaderCarousel(
                        imageUrls: imageUrls,
                        onImageTap: (index) => _showFullscreenImageViewer(context, imageUrls, index),
                      ),
                    ),
                    Positioned(bottom: 15, left: 0, right: 0, child: _headerQuickActions(details, coverImage)),
                  ],
                ),
              ),
            ),
          ],
          body: Container(
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _projectHeaderSection(project, data, details),
                  const SizedBox(height: 12),
                  TabBar(controller: _tabController, indicatorColor: const Color(0xFFFF6B22), labelColor: Colors.black, tabs: const [Tab(text: 'Overview'), Tab(text: 'Properties')]),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: [
                      _overviewTab(project, details, associatedBuilders, associatedLeads, authVM),
                      _propertiesTab(project),
                    ][_tabController.index],
                  ),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: widget.isPublicView ? _publicBottomActions(details) : _bottomActions(details),
        floatingActionButton: widget.isPublicView ? null : FloatingActionButton(backgroundColor: const Color(0xFFFF6B22), onPressed: () => context.push('/add-project', extra: project), child: const Icon(Icons.edit, color: Colors.white)),
      ),
    );
  }

  Widget _publicBottomActions(Map<String, dynamic> det) => Container(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
    decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
    child: Row(
      children: [
        if (det['brochurePdf'] != null) Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _openFile(det['brochurePdf']),
            icon: const Icon(Icons.download),
            label: const Text('Brochure'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade50, foregroundColor: Colors.blue, elevation: 0),
          ),
        ),
        if (det['brochurePdf'] != null) const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _handlePublicInterest(),
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('I am Interested'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B22), foregroundColor: Colors.white, elevation: 0),
          ),
        ),
      ],
    ),
  );

  void _handlePublicInterest() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Thank you! Please Login to contact the property manager.')),
    );
    context.go('/login?mode=viewer');
  }

  void _showPublicExitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Column(
          children: [
            const CircleAvatar(
              radius: 28,
              backgroundColor: Color(0xFFFFF1EA),
              child: Icon(Icons.domain_rounded, color: Color(0xFFFF6B22), size: 30),
            ),
            const SizedBox(height: 12),
            const Text(
              'Explore More Properties!',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black87),
            ),
          ],
        ),
        content: const Text(
          'Want to see more premium properties or share this listing with friends & family?',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.black54),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsOverflowButtonSpacing: 8,
        actions: [
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                _handleShare(context);
              },
              icon: const Icon(Icons.share_outlined, size: 18),
              label: const Text('Share Property', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFBE64E),
                foregroundColor: const Color(0xFF6B5800),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                context.go('/login?mode=viewer');
              },
              icon: const Icon(Icons.login_rounded, size: 18),
              label: const Text('Login / Register To See More', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B22),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Stay on Page', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _handleShare(BuildContext context) {
    final details = widget.project.propertyDetails;
    final String loc = (details['googleLocation'] ?? details['areaName'] ?? details['location'] ?? details['address'] ?? widget.project.rawData['googleLocation'] ?? '').toString().trim();
    final String location = loc.isNotEmpty && loc != 'null' ? loc : 'Location N/A';

    final String baseUrl = Uri.base.origin;
    final String encodedName = Uri.encodeComponent(widget.project.projectName);
    final String shareLink = "$baseUrl/#/share/project/$encodedName";

    // 🚀 NAYA: Rich Share Message
    final String message = "Property+\n\n"
        "🏢 Building: ${widget.project.projectName}\n"
        "📍 Location: $location\n\n"
        "🔗 View Property Details & Photos:\n$shareLink";

    List<String> imageUrls = (details['images'] is Iterable) ? List<String>.from(details['images']) : [];
    final String? coverImage = imageUrls.isNotEmpty ? imageUrls.first : null;

    // Dynamically update OpenGraph Meta Tags
    MetaTagHelper.updatePropertyMetaTags(
      title: '${widget.project.projectName} - $location',
      description: 'Location: $location',
      imageUrl: coverImage,
    );

    Clipboard.setData(ClipboardData(text: shareLink)).then((_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Property link copied to clipboard!'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.blue,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    Share.share(message, subject: 'Property+ | ${widget.project.projectName}');
  }

  Widget _overviewTab(ProjectModel p, Map<String, dynamic> det, List<BuilderModel> builders, List<dynamic> leads, AuthViewModel auth) {
    bool isAdmin = auth.appRole == AppRole.admin || auth.appRole == AppRole.superAdmin;
    final bool isLand = p.propertyType == 'Land';

    return Column(children: [
      _buildSection('Basic Info', Icons.info_outline, [
        _detailRow('Project Company', det['projectCompany']),
        _detailRow('Property Type', p.propertyType),
        _detailRow('Sub Type', det['subType']),
        if (!widget.isPublicView) _detailRow('Referral', det['referral']),
        _detailRow('Nearest Station', det['nearestStation']),
        _detailRow('Status', det['status']),
      ]),
      const SizedBox(height: 12),
      _buildSection('Property Details', Icons.location_on_outlined, [
        _detailRow('Starting Price', det['startingPrice']),
        if (isLand) ...[
          _detailRow('Survey No', det['surveyNo']),
          _detailRow('Hissa Number', det['hissaNumber']),
          _detailRow('Total Area (Guntha)', det['totalAreaGuntha']),
          _detailRow('Zone', det['zone']),
          _detailRow('Min Cost', det['minCostLand']),
          _detailRow('Min Percentage', det['minPercentageLand']),
          _detailRow('Max Cost', det['maxCostLand']),
          _detailRow('Max Percentage', det['maxPercentageLand']),
          _detailRow('Level 5 Percentage', det['level5Percentage']),
          _detailRow('Road Length', det['roadLength']),
          _detailRow('Road Direction', det['roadDirection']),
          _detailRow('Compounding Done', det['compoundingDone']),
          _detailRow('FSI', det['fsi']),
          _detailRow('Road Frontage', det['roadFrontage']),
          _detailRow('Boundary Wall', det['boundaryWall']),
          _detailRow('Road Access', det['roadAccess']),
        ] else ...[
          _detailRow('Wing', (det['wing'] is List) ? (det['wing'] as List).join(', ') : det['wing']),
          _detailRow('Flat/Shop No.', det['flatNoDetail']),
          _detailRow('Rera Carpet Area', det['reraArea'] != null ? '${det['reraArea']} Sq.ft' : null),
          _detailRow('Usable Carpet Area', det['usableArea'] != null ? '${det['usableArea']} Sq.ft' : null),
          _detailRow('BUA', det['bua'] != null ? '${det['bua']} Sq.ft' : null),
          _detailRow('Min Cost', det['minCost'] != null ? '₹ ${det['minCost']} ${det['minPercentage'] != null ? "(${det['minPercentage']}%)" : ""}' : null),
          _detailRow('Max Cost', det['maxCost'] != null ? '₹ ${det['maxCost']} ${det['maxPercentage'] != null ? "(${det['maxPercentage']}%)" : ""}' : null),
          _detailRow('Sq.ft Cost', det['sqFtCost'] != null ? '₹ ${det['sqFtCost']}' : null),
          _detailRow('Total Units', det['totalUnits'] != null ? '${det['totalUnits']} ${det['totalUnitsLeft'] != null ? "(Left: ${det['totalUnitsLeft']})" : ""}' : null),
        ],
        _detailRow('Building Name', det['buildingName']),
        _detailRow('Area Name', det['areaName']),
        _detailRow('Google Location', det['googleLocation']),
        _detailRow('Full Address', det['address']),
        const Divider(),
        _detailRow('Last Updated', det['lastUpdatedOn']),
      ]),
      const SizedBox(height: 12),
      if (!isLand) ...[
        _buildSection('Amenities & USP', Icons.pool_outlined, [
          _buildChipList('USP', det['usp']),
          _buildChipList('Key Amenities', det['keyAmenities']),
          _buildChipList('Nearby Facilities', det['nearbyFacilities']),
          _detailRow('Other Amenities', det['otherAmenities']),
          _detailRow('Internal Amenities', det['internalAmenities']),
          const Divider(height: 24),
          _buildFileRow('Project Brochure', det['brochurePdf']),
          _buildFileRow('Floor Plan PDF', det['floorPlanPdf']),
          _buildFileRow('Layout Plan PDF', det['layoutPlanPdf']),
        ]),
        const SizedBox(height: 12),
      ],
      _buildSection('Legal Details', Icons.gavel_outlined, [
        _detailRow('RERA Approved', det['isReraApproved']),
        _detailRow('RERA Number', det['reraNumber']),
        _detailRow('Title Clear', det['isTitleClear']),
        if (!widget.isPublicView) ...[
          const Divider(height: 24),
          _buildFileRow('Title & Search Report', det['titleSearchReport']),
          _buildFileRow('Sat Bata', det['satBara']),
          _buildFileRow('Non - Agriculture', det['nonAgriculture']),
          _buildFileRow('Zone Certificate', det['zoneCertificate']),
          _buildFileRow('Physical Survey', det['physicalSurvey']),
          _detailRow('Builders/Owner Name', det['buildersOwnerName']),
          _buildFileRow('Development Agreement', det['developmentAgreement']),
          _buildFileRow('Partnership Deed', det['partnershipDeed']),
          _buildFileRow('Commencement Cert', det['commencementCertificate']),
          _buildFileRow('Completion Cert', det['completionCertificate']),
          _buildFileRow('Project Report', det['projectReport']),
        ],
      ]),
      const SizedBox(height: 12),
      if (!widget.isPublicView) ...[
        _buildSection(
          'Associated Builders (${builders.length})',
          Icons.business_center_outlined,
          builders.isEmpty
              ? [const Text('No builders associated yet.', style: TextStyle(color: Colors.grey, fontSize: 13))]
              : builders.map((b) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  onTap: () {
                    final cpModel = CPModel.fromMap(b.rawData, b.id);
                    context.push('/cp-detail/${b.id}', extra: cpModel);
                  },
                  leading: const CircleAvatar(
                    radius: 14,
                    backgroundColor: Color(0xFFFFF1EA),
                    child: Icon(Icons.person, size: 14, color: Color(0xFFFF6B22)),
                  ),
                  title: Text(b.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text(
                    b.companyNames.isNotEmpty ? b.companyNames.join(', ') : 'No Company',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                )).toList(),
        ),
        const SizedBox(height: 12),
        _buildSection(
          'Associated Leads (${leads.length})',
          Icons.people_outline,
          leads.isEmpty
              ? [const Text('No leads interested yet.', style: TextStyle(color: Colors.grey, fontSize: 13))]
              : leads.map((l) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  leading: const CircleAvatar(
                    radius: 14,
                    backgroundColor: Color(0xFFFFF1EA),
                    child: Icon(Icons.person, size: 14, color: Color(0xFFFF6B22)),
                  ),
                  title: Text(l.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    l.status.toString(),
                    style: TextStyle(
                      fontSize: 11,
                      color: l.status.toString().toLowerCase() == 'hot' ? Colors.red : Colors.grey,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                  onTap: () => context.push('/lead-detail/${l.id}', extra: l),
                )).toList(),
        ),
        const SizedBox(height: 12),
      ],
      if (isAdmin && !widget.isPublicView) _buildSection('Admin Controls', Icons.admin_panel_settings_outlined, [
        _detailRow('Approved Status', det['isApproved']),
        _detailRow('Legally Verified', det['isLegallyVerified']),
        _detailRow('Priority Listing', det['isHot']),
        _detailRow('Property Points', det['points']),
        _detailRow('Already Exists', det['alreadyExists']),
      ]),
      if (widget.isPublicView) ...[
        const SizedBox(height: 32),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFFF6B22).withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFF6B22).withOpacity(0.2)),
          ),
          child: Column(
            children: [
              const Text(
                'Want to see more high-quality properties like this?',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/login?mode=viewer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B22),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('LOGIN / REGISTER NOW', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 100),
    ]);
  }

  Widget _propertiesTab(ProjectModel p) {
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Inventory Tracking', style: TextStyle(fontWeight: FontWeight.bold)), TextButton.icon(onPressed: () {}, icon: const Icon(Icons.add, size: 16), label: const Text('Add'))]),
      const Divider(),
      const Text('Inventory list will appear here.'),
      const SizedBox(height: 100),
    ]);
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    bool isExp = _sectionStates[title] ?? false;
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Column(children: [
        InkWell(
          onTap: () => setState(() => _sectionStates[title] = !isExp),
          onDoubleTap: _globalToggle,
          child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [Icon(icon, color: const Color(0xFFFF6B22), size: 20), const SizedBox(width: 12), Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), const Spacer(), Icon(isExp ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.grey)])),
        ),
        if (isExp) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children)),
      ]),
    );
  }

  Widget _detailRow(String label, dynamic value) {
    String val = 'N/A';
    if (value != null) {
      if (value is bool) val = value ? 'Yes' : 'No';
      else if (value.toString().trim().isNotEmpty) val = value.toString();
    }
    return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [
      Expanded(flex: 2, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13))),
      const Text(' :  ', style: TextStyle(color: Colors.grey)),
      Expanded(flex: 3, child: Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
    ]));
  }

  Widget _buildFileRow(String label, String? url) {
    if (url == null || url.isEmpty) return const SizedBox.shrink();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.picture_as_pdf_outlined, color: Colors.redAccent, size: 20),
      title: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      trailing: const Icon(Icons.open_in_new, size: 14),
      onTap: () => _openFile(url),
    );
  }

  Widget _buildChipList(String label, dynamic values) {
    List<String> list = [];
    if (values is List) {
      list = List<String>.from(values.map((e) => e.toString()).where((s) => s.isNotEmpty));
    } else if (values is String && values.trim().isNotEmpty) {
      list = values.split(',').map((e) => e.trim()).where((s) => s.isNotEmpty).toList();
    }

    if (list.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: list.map((s) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B22).withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFFF6B22).withOpacity(0.3)),
              ),
              child: Text(s, style: const TextStyle(fontSize: 11, color: Color(0xFFFF6B22), fontWeight: FontWeight.bold)),
            )).toList(),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _headerCircle(IconData icon, VoidCallback onTap) => Padding(padding: const EdgeInsets.all(8), child: CircleAvatar(backgroundColor: Colors.white.withOpacity(0.9), child: IconButton(icon: Icon(icon, color: Colors.black, size: 20), onPressed: onTap)));
  Widget _gradientOverlay() => Positioned.fill(child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(0.4), Colors.transparent, Colors.black.withOpacity(0.6)]))));
  Widget _headerQuickActions(Map<String, dynamic> d, String? img) => SingleChildScrollView(
    scrollDirection: Axis.horizontal, 
    padding: const EdgeInsets.symmetric(horizontal: 16), 
    child: Row(children: [
      if (d['brochurePdf'] != null) _headerTileButton('Brochure', Icons.menu_book_outlined, () => _openFile(d['brochurePdf'])),
      if (d['layoutPlanPdf'] != null) _headerTileButton('Layout', Icons.play_circle_outline, () => _openFile(d['layoutPlanPdf'])),
      _headerTileButton(
        'Fav',
        _isLiked ? Icons.favorite : Icons.favorite_border,
        () => setState(() => _isLiked = !_isLiked),
        iconColor: _isLiked ? Colors.red : Colors.white,
      ),
      _headerTileButton('Share', Icons.share_outlined, () => _handleShare(context)),
    ]),
  );

  Widget _headerTileButton(String label, IconData icon, VoidCallback onTap, {Color iconColor = Colors.white}) => GestureDetector(
    onTap: onTap, 
    child: Container(
      margin: const EdgeInsets.only(right: 12), 
      width: 85, 
      height: 70, 
      decoration: BoxDecoration(color: const Color(0xFF2C3843), borderRadius: BorderRadius.circular(12)), 
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center, 
        children: [
          Icon(icon, color: iconColor, size: 22), 
          const SizedBox(height: 4), 
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    ),
  );

  Widget _projectHeaderSection(ProjectModel p, Map<String, dynamic> d, Map<String, dynamic> det) => Padding(padding: const EdgeInsets.all(16), child: Row(children: [
    const CircleAvatar(radius: 30, backgroundColor: Color(0xFFFFF1EA), child: Icon(Icons.domain, color: Color(0xFFFF6B22))),
    const SizedBox(width: 16),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(p.projectName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), Text(d['areaName'] ?? 'Location', style: const TextStyle(color: Colors.grey))])),
  ]));

  Widget _bottomActions(Map<String, dynamic> det) => Container(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]), child: Row(children: [
    Expanded(child: ElevatedButton(onPressed: () => _openFile(det['brochurePdf']), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade50, elevation: 0), child: const Text('Brochure', style: TextStyle(color: Colors.blue)))),
    const SizedBox(width: 12),
    Expanded(child: ElevatedButton(onPressed: () => _makeCall(widget.project.contactNumber), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B22), elevation: 0), child: const Text('Call Now', style: TextStyle(color: Colors.white)))),
  ]));

  void _showFullscreenImageViewer(BuildContext context, List<String> imageUrls, int initialIndex) {
    if (imageUrls.isEmpty) return;

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogCtx) {
        int currentIndex = initialIndex;
        final PageController fullPageCtrl = PageController(initialPage: initialIndex);

        return StatefulBuilder(
          builder: (context, setViewerState) {
            return Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                ),
                title: Text(
                  '${currentIndex + 1} of ${imageUrls.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                centerTitle: true,
              ),
              body: Stack(
                children: [
                  ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(
                      dragDevices: {
                        PointerDeviceKind.touch,
                        PointerDeviceKind.mouse,
                        PointerDeviceKind.trackpad,
                        PointerDeviceKind.stylus,
                      },
                    ),
                    child: PageView.builder(
                      controller: fullPageCtrl,
                      itemCount: imageUrls.length,
                      onPageChanged: (idx) => setViewerState(() => currentIndex = idx),
                      itemBuilder: (context, idx) {
                        return InteractiveViewer(
                          minScale: 0.8,
                          maxScale: 4.0,
                          child: Center(
                            child: Image.network(
                              imageUrls[idx],
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white, size: 80),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Left Arrow Button
                  if (imageUrls.length > 1)
                    Positioned(
                      left: 16,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: Colors.white24,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
                            onPressed: () {
                              int prev = (currentIndex - 1 + imageUrls.length) % imageUrls.length;
                              fullPageCtrl.animateToPage(
                                prev,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  // Right Arrow Button
                  if (imageUrls.length > 1)
                    Positioned(
                      right: 16,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: Colors.white24,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.chevron_right, color: Colors.white, size: 28),
                            onPressed: () {
                              int next = (currentIndex + 1) % imageUrls.length;
                              fullPageCtrl.animateToPage(
                                next,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ProjectHeaderCarousel extends StatefulWidget {
  final List<String> imageUrls;
  final Function(int index) onImageTap;

  const _ProjectHeaderCarousel({
    required this.imageUrls,
    required this.onImageTap,
  });

  @override
  State<_ProjectHeaderCarousel> createState() => _ProjectHeaderCarouselState();
}

class _ProjectHeaderCarouselState extends State<_ProjectHeaderCarousel> {
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    if (widget.imageUrls.length > 1) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted || widget.imageUrls.isEmpty) return;
      int nextPage = (_currentPage + 1) % widget.imageUrls.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) {
      return Container(
        color: Colors.grey.shade200,
        child: const Icon(Icons.business, size: 100, color: Colors.grey),
      );
    }

    return Stack(
      children: [
        ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
              PointerDeviceKind.stylus,
            },
          ),
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.imageUrls.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => widget.onImageTap(index),
                child: Image.network(
                  widget.imageUrls[index],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.broken_image, size: 80, color: Colors.grey),
                  ),
                ),
              );
            },
          ),
        ),
        // Image Counter Badge
        Positioned(
          top: 65,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.photo_library_outlined, color: Colors.white, size: 12),
                const SizedBox(width: 6),
                Text(
                  '${_currentPage + 1} / ${widget.imageUrls.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        // 🚀 NAYA: Left Arrow Button
        if (widget.imageUrls.length > 1)
          Positioned(
            left: 12,
            top: 0,
            bottom: 0,
            child: Center(
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.black38,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.chevron_left, color: Colors.white, size: 22),
                  onPressed: () {
                    int prev = (_currentPage - 1 + widget.imageUrls.length) % widget.imageUrls.length;
                    _pageController.animateToPage(
                      prev,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut,
                    );
                  },
                ),
              ),
            ),
          ),
        // 🚀 NAYA: Right Arrow Button
        if (widget.imageUrls.length > 1)
          Positioned(
            right: 12,
            top: 0,
            bottom: 0,
            child: Center(
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.black38,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.chevron_right, color: Colors.white, size: 22),
                  onPressed: () {
                    int next = (_currentPage + 1) % widget.imageUrls.length;
                    _pageController.animateToPage(
                      next,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut,
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}
