import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;
import 'package:flutter/gestures.dart'; // 🚀 NAYA: For mouse/trackpad drag on web
import 'package:intl/intl.dart';
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
    final details = <String, dynamic>{...project.rawData, ...project.propertyDetails};

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
        body: Column(
          children: [
            if (widget.isPublicView) _buildPublicBrandingBanner(),
            Expanded(
              child: NestedScrollView(
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
                        TabBar(controller: _tabController, indicatorColor: const Color(0xFFFF6B22), labelColor: Colors.black, tabs: const [Tab(text: 'Overview'), Tab(text: 'Inventory')]),
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
            ),
          ],
        ),
        bottomNavigationBar: widget.isPublicView ? _publicBottomActions(details) : _bottomActions(details),
        floatingActionButton: (!widget.isPublicView && _canEditProject(authVM, project))
            ? FloatingActionButton(
                backgroundColor: const Color(0xFFFF6B22),
                onPressed: () => context.push('/add-project', extra: project),
                child: const Icon(Icons.edit, color: Colors.white),
              )
            : null,
      ),
    );
  }

  bool _canEditProject(AuthViewModel authVM, ProjectModel project) {
    if (authVM.appRole == AppRole.viewer) return false;
    if (authVM.appRole == AppRole.admin || authVM.appRole == AppRole.superAdmin || authVM.appRole == AppRole.officeStaff) {
      return true;
    }
    final String myUid = authVM.userUid.trim();
    final String myName = authVM.userName.trim().toLowerCase();
    final String myContact = (authVM.userData?['contactNo'] ?? '').toString().trim();

    final String cUid = (project.createdByUid ?? '').trim();
    final cb = project.rawData['createdBy'];
    final String cbUid = (cb is Map ? cb['uid'] ?? '' : '').toString().trim();
    final String cbName = (cb is Map ? cb['name'] ?? '' : '').toString().trim().toLowerCase();
    final String addedBy = (project.rawData['addedBy'] ?? '').toString().trim().toLowerCase();
    final String projContact = (project.rawData['contactNo'] ?? project.propertyDetails['contactNo'] ?? '').toString().trim();

    bool isMine = (myUid.isNotEmpty && (cUid == myUid || cbUid == myUid)) ||
        (myName.isNotEmpty && (cbName == myName || addedBy == myName || (project.rawData['createdBy']?.toString().toLowerCase() == myName))) ||
        (myContact.isNotEmpty && projContact.isNotEmpty && projContact == myContact);

    return isMine;
  }

  Widget _buildPublicBrandingBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Image.asset(
              'assets/logo.png',
              height: 28,
              width: 28,
              errorBuilder: (_, __, ___) => const Icon(Icons.domain_rounded, color: Color(0xFFFF6B22), size: 28),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Property+',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    letterSpacing: 0.3,
                  ),
                ),
                Text(
                  'Verified Real Estate Listings',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () => context.go('/customer-form'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B22),
                foregroundColor: Colors.white,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text('Explore App', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _publicBottomActions(Map<String, dynamic> det) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
    child: Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () => _handleGetDetailsWhatsApp(context),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade50, elevation: 0),
            child: const Text('Get Details', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              final String phone = (widget.project.contactNumber.isNotEmpty ? widget.project.contactNumber : '8793693314');
              _makeCall(phone);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B22), elevation: 0),
            child: const Text('Call Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            color: Colors.blue.shade600,
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.white, size: 20),
            onPressed: () => _handleShare(context),
          ),
        ),
      ],
    ),
  );

  void _handlePublicInterest() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Thank you! Please Login to contact the property manager.')),
    );
    context.go('/customer-form');
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
                context.go('/customer-form');
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
    final details = <String, dynamic>{...widget.project.rawData, ...widget.project.propertyDetails};
    final String location = widget.project.displayLocation;

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

    final String config = (details['configuration'] is List) ? (details['configuration'] as List).join(', ') : (details['configuration'] ?? '').toString();
    final String rawPrice = (details['minCost'] ?? details['startingPrice'] ?? details['minCostLand'] ?? '').toString().trim();
    final String priceStr = rawPrice.isNotEmpty ? _formatPrice(rawPrice) : '';

    String shareDesc = 'Location: $location';
    if (config.isNotEmpty) shareDesc += ' | $config';
    if (priceStr.isNotEmpty && priceStr != 'On Request') shareDesc += ' | Price: $priceStr';

    // Dynamically update OpenGraph Meta Tags
    MetaTagHelper.updatePropertyMetaTags(
      title: '${widget.project.projectName} - $location',
      description: shareDesc,
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

  void _handleGetDetailsWhatsApp(BuildContext context) {
    final details = widget.project.propertyDetails;
    final String propertyName = widget.project.projectName;
    final String companyName = (details['projectCompany'] ?? widget.project.rawData['projectCompany'] ?? '').toString().trim();
    final String loc = (details['location'] ?? details['googleLocation'] ?? details['areaName'] ?? details['address'] ?? widget.project.rawData['location'] ?? '').toString().trim();
    final String location = loc.isNotEmpty && loc != 'null' ? loc : 'Location N/A';

    final String message = "Property Name: $propertyName\n"
        "Company Name: ${companyName.isNotEmpty ? companyName : 'N/A'}\n"
        "Location: $location\n\n"
        "I want more details about this project";

    final String phone = '8793693314';
    final Uri whatsappUri = Uri.parse('https://wa.me/91$phone?text=${Uri.encodeComponent(message)}');
    
    launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
  }

  Widget _overviewTab(ProjectModel p, Map<String, dynamic> det, List<BuilderModel> builders, List<dynamic> leads, AuthViewModel auth) {
    bool isAdmin = auth.appRole == AppRole.admin || auth.appRole == AppRole.superAdmin;
    final bool isLand = p.propertyType == 'Land';

    // 🚀 Calculate 7 Essential Property Details fields
    final minC = isLand ? (det['minCostLand'] ?? det['minCost']) : (det['minCost'] ?? det['minCostLand']);
    final maxC = isLand ? (det['maxCostLand'] ?? det['maxCost']) : (det['maxCost'] ?? det['maxCostLand']);
    String propPriceRange = 'On Request';
    if (minC != null && minC.toString().trim().isNotEmpty) {
      final String minStr = _formatPrice(minC.toString().trim());
      if (maxC != null && maxC.toString().trim().isNotEmpty) {
        final String maxStr = _formatPrice(maxC.toString().trim());
        final String cleanMax = maxStr.replaceAll('₹', '').trim();
        if (minStr != maxStr && cleanMax.isNotEmpty && cleanMax != 'N/A') {
          propPriceRange = '$minStr - $cleanMax';
        } else {
          propPriceRange = minStr;
        }
      } else {
        propPriceRange = minStr;
      }
    } else if (det['startingPrice'] != null && det['startingPrice'].toString().trim().isNotEmpty) {
      propPriceRange = _formatPrice(det['startingPrice'].toString());
    }

    String propUnitLeft = 'N/A';
    final rawLeft = (det['totalUnitsLeft'] ?? '').toString().trim();
    final rawTotal = (det['totalUnits'] ?? '').toString().trim();
    if (rawLeft.isNotEmpty && rawLeft != 'null' && rawLeft != 'N/A') {
      propUnitLeft = rawTotal.isNotEmpty ? '$rawLeft / $rawTotal Units' : '$rawLeft Units';
    } else if (rawTotal.isNotEmpty && rawTotal != 'null' && rawTotal != 'N/A') {
      propUnitLeft = '$rawTotal Units';
    } else if (isLand) {
      final guntha = (det['totalAreaGuntha'] ?? '').toString().trim();
      propUnitLeft = guntha.isNotEmpty ? '$guntha Guntha' : 'Available';
    }

    String propCarpetArea = 'N/A';
    if (det['usableArea'] != null && det['usableArea'].toString().trim().isNotEmpty) {
      propCarpetArea = '${det['usableArea']} Sq.ft';
    } else if (det['reraArea'] != null && det['reraArea'].toString().trim().isNotEmpty) {
      propCarpetArea = '${det['reraArea']} Sq.ft';
    } else if (det['bua'] != null && det['bua'].toString().trim().isNotEmpty) {
      propCarpetArea = '${det['bua']} Sq.ft';
    } else if (isLand) {
      final guntha = (det['totalAreaGuntha'] ?? '').toString().trim();
      if (guntha.isNotEmpty) propCarpetArea = '$guntha Guntha';
    }

    String propSqftRate = 'N/A';
    final rawSqft = (det['sqFtCost'] ?? '').toString().trim();
    if (rawSqft.isNotEmpty && rawSqft != 'null' && rawSqft != 'N/A') {
      propSqftRate = '₹ $rawSqft / Sq.ft';
    }

    String propWing = 'N/A';
    final rawWing = det['wing'];
    if (rawWing != null) {
      if (rawWing is List) propWing = rawWing.join(', ');
      else if (rawWing.toString().trim().isNotEmpty) propWing = rawWing.toString().trim();
    }

    String propFlatNo = (det['flatNoDetail'] ?? det['flatNo'] ?? '').toString().trim();
    if (propFlatNo.isEmpty || propFlatNo == 'null') propFlatNo = 'N/A';

    String propFullAddr = (det['address'] ?? det['location'] ?? det['googleLocation'] ?? det['areaName'] ?? '').toString().trim();
    if (propFullAddr.isEmpty || propFullAddr == 'null') propFullAddr = 'N/A';

    String propLastUpdated = _formatDateValue(det['lastUpdatedOn']);
    if (propLastUpdated.isEmpty || propLastUpdated == 'null') propLastUpdated = 'N/A';

    final String landPlotCost = (det['plotCostLand'] != null && det['plotCostLand'].toString().trim().isNotEmpty) ? _formatPrice(det['plotCostLand'].toString()) : propPriceRange;
    final String landSqftCost = (det['sqFtCostLand'] != null && det['sqFtCostLand'].toString().trim().isNotEmpty) ? '₹ ${det['sqFtCostLand']} / Sq.ft' : 'N/A';

    final List<Map<String, String>> propertyDetailCards = isLand ? [
      {'label': 'Plot Cost', 'value': landPlotCost},
      {'label': 'Cost per sqft', 'value': landSqftCost},
      {'label': 'Survey No', 'value': (det['surveyNo'] ?? 'N/A').toString()},
      {'label': 'Hissa Number', 'value': (det['hissaNumber'] ?? 'N/A').toString()},
      {'label': 'Road Length', 'value': (det['roadLength'] ?? 'N/A').toString()},
      {'label': 'Road Facing', 'value': (det['roadDirection'] ?? 'N/A').toString()},
      {'label': 'Road Frontage', 'value': (det['roadFrontage'] ?? 'N/A').toString()},
      {'label': 'Compound Done', 'value': (det['compoundingDone'] == true || det['compoundingDone'] == 'Yes' ? 'Yes' : 'No')},
      {'label': 'FSI', 'value': (det['fsi'] ?? 'N/A').toString()},
      {'label': 'TDR', 'value': (det['tdr'] ?? 'N/A').toString()},
      {'label': 'District', 'value': (det['district'] ?? 'N/A').toString()},
      {'label': 'State', 'value': (det['state'] ?? 'N/A').toString()},
      {'label': 'Full Address', 'value': propFullAddr},
      {'label': 'Last Updated', 'value': propLastUpdated},
    ] : [
      {'label': 'Price (Min - Max)', 'value': propPriceRange},
      {'label': 'Unit Left', 'value': propUnitLeft},
      {'label': 'Carpet Area', 'value': propCarpetArea},
      {'label': 'Rate per sqft', 'value': propSqftRate},
      {'label': 'Wing', 'value': propWing},
      {'label': 'Flat/Shop No.', 'value': propFlatNo},
      {'label': 'District', 'value': (det['district'] ?? 'N/A').toString()},
      {'label': 'State', 'value': (det['state'] ?? 'N/A').toString()},
      {'label': 'Full Address', 'value': propFullAddr},
      {'label': 'Last Updated', 'value': propLastUpdated},
    ];

    final bool hasAmenities = (det['usp'] != null && det['usp'].toString().trim().isNotEmpty) ||
        (det['keyAmenities'] != null && det['keyAmenities'].toString().trim().isNotEmpty) ||
        (det['nearbyFacilities'] != null && det['nearbyFacilities'].toString().trim().isNotEmpty) ||
        (det['otherAmenities'] != null && det['otherAmenities'].toString().trim().isNotEmpty && det['otherAmenities'] != 'N/A') ||
        (det['internalAmenities'] != null && det['internalAmenities'].toString().trim().isNotEmpty && det['internalAmenities'] != 'N/A') ||
        (det['brochurePdf'] != null && det['brochurePdf'].toString().trim().isNotEmpty) ||
        (det['floorPlanPdf'] != null && det['floorPlanPdf'].toString().trim().isNotEmpty) ||
        (det['layoutPlanPdf'] != null && det['layoutPlanPdf'].toString().trim().isNotEmpty) ||
        (det['brochure'] != null && det['brochure'].toString().trim().isNotEmpty) ||
        (det['floorPlan'] != null && det['floorPlan'].toString().trim().isNotEmpty) ||
        (det['layoutPlan'] != null && det['layoutPlan'].toString().trim().isNotEmpty);

    return Column(children: [
      _buildSection('Basic Info', Icons.info_outline, [
        _buildBasicInfoHighlightCards(p, det),
      ]),
      const SizedBox(height: 12),
      _buildSection('Property Details', Icons.location_on_outlined, [
        _buildDetailGrid(propertyDetailCards),
      ]),
      const SizedBox(height: 12),
      if (hasAmenities) ...[
        _buildSection('Amenities & USP', Icons.pool_outlined, [
          _buildChipList('USP', det['usp']),
          _buildChipList('Key Amenities', det['keyAmenities']),
          _buildChipList('Nearby Facilities', det['nearbyFacilities']),
          _detailRow('Other Amenities', det['otherAmenities']),
          _detailRow('Internal Amenities', det['internalAmenities']),
          const Divider(height: 24),
          _buildFileRow('Project Brochure', det['brochurePdf'] ?? det['brochure']),
          _buildFileRow('Floor Plan PDF', det['floorPlanPdf'] ?? det['floorPlan']),
          _buildFileRow('Layout Plan PDF', det['layoutPlanPdf'] ?? det['layoutPlan']),
        ]),
        const SizedBox(height: 12),
      ],
      _buildSection('Legal Details', Icons.gavel_outlined, [
        _buildDetailGrid([
          if (!isLand) ...[
            {'label': 'RERA Approved', 'value': det['isReraApproved']},
            {'label': 'RERA Number', 'value': det['reraNumber']},
          ],
          {'label': 'Title Clear', 'value': det['isTitleClear']},
          if (!widget.isPublicView) {'label': 'Builders/Owner Name', 'value': det['buildersOwnerName']},
        ]),
        if (!widget.isPublicView) ...[
          const SizedBox(height: 12),
          _buildFileRow('Title & Search Report', det['titleSearchReport']),
          _buildFileRow('Sat Bata', det['satBara']),
          _buildFileRow('Non - Agriculture', det['nonAgriculture']),
          _buildFileRow('Zone Certificate', det['zoneCertificate']),
          _buildFileRow('Physical Survey', det['physicalSurvey']),
          _buildFileRow('Development Agreement', det['developmentAgreement']),
          _buildFileRow('Partnership Deed', det['partnershipDeed']),
          _buildFileRow('Commencement Cert', det['commencementCertificate']),
          _buildFileRow('Completion Cert', det['completionCertificate']),
          _buildFileRow('Project Report', det['projectReport']),
        ],
      ]),
      const SizedBox(height: 12),
      // 🚀 NAYA: Others Expandable Section
      if (det['otherAttachments'] is List && (det['otherAttachments'] as List).isNotEmpty) ...[
        _buildSection('Others', Icons.folder_open_rounded, [
          ...(det['otherAttachments'] as List).map((att) {
            if (att is Map) {
              final String attTitle = (att['title'] ?? 'Custom File').toString();
              final String attUrl = (att['url'] ?? att['file'] ?? '').toString();
              if (attUrl.isNotEmpty) {
                return _buildFileRow(attTitle, attUrl);
              }
            }
            return const SizedBox.shrink();
          }),
        ]),
        const SizedBox(height: 12),
      ],
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
      if (isAdmin && !widget.isPublicView) ...[
        const SizedBox(height: 12),
        _buildEditHistorySection(p),
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
                onPressed: () => context.go('/customer-form'),
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
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Row(children: [Icon(icon, color: const Color(0xFFFF6B22), size: 20), const SizedBox(width: 12), Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), const Spacer(), Icon(isExp ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.grey)])),
        ),
        if (isExp) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children)),
      ]),
    );
  }

  String _formatPrice(String? priceStr) {
    if (priceStr == null || priceStr.trim().isEmpty) return 'On Request';
    if (priceStr.contains('-')) {
      final parts = priceStr.split('-');
      if (parts.length == 2) {
        final start = _formatSinglePrice(parts[0].trim());
        final end = _formatSinglePrice(parts[1].trim());
        return '$start - $end';
      }
    }
    return _formatSinglePrice(priceStr.trim());
  }

  String _formatSinglePrice(String valStr) {
    valStr = valStr.replaceAll('₹', '').trim();
    double? val = double.tryParse(valStr);
    if (val == null) return valStr;

    if (val >= 10000000) {
      String res = (val / 10000000).toStringAsFixed(2);
      if (res.endsWith('.00')) {
        res = res.substring(0, res.length - 3);
      } else if (res.endsWith('0')) {
        res = res.substring(0, res.length - 1);
      }
      return '₹ $res Cr';
    } else if (val >= 100000) {
      String res = (val / 100000).toStringAsFixed(2);
      if (res.endsWith('.00')) {
        res = res.substring(0, res.length - 3);
      } else if (res.endsWith('0')) {
        res = res.substring(0, res.length - 1);
      }
      return '₹ $res L';
    } else if (val >= 1000) {
      String res = (val / 1000).toStringAsFixed(2);
      if (res.endsWith('.00')) {
        res = res.substring(0, res.length - 3);
      } else if (res.endsWith('0')) {
        res = res.substring(0, res.length - 1);
      }
      return '₹ $res K';
    } else {
      String res = val.toString();
      if (res.endsWith('.0')) res = res.substring(0, res.length - 2);
      return '₹ $res';
    }
  }

  String _formatConfiguration(dynamic rawConfig, String propertyType, String subType) {
    if (rawConfig == null) {
      if (propertyType.toLowerCase() == 'shop' || subType.toLowerCase() == 'shop') return 'Shops';
      return 'N/A';
    }

    List<String> list = [];
    if (rawConfig is List) {
      list = List<String>.from(rawConfig.map((e) => e.toString().trim()).where((s) => s.isNotEmpty));
    } else if (rawConfig is String && rawConfig.trim().isNotEmpty) {
      list = rawConfig.split(RegExp(r'[,&]')).map((e) => e.trim()).where((s) => s.isNotEmpty).toList();
    }

    if (list.isEmpty) {
      if (propertyType.toLowerCase() == 'shop' || subType.toLowerCase() == 'shop') return 'Shops';
      return 'N/A';
    }

    final List<String> bhkNumbers = [];
    final List<String> otherItems = [];

    for (var item in list) {
      final String clean = item.trim();
      final RegExp numReg = RegExp(r'^(\d+(?:\.\d+)?)\s*(?:BHK)?$', caseSensitive: false);
      final match = numReg.firstMatch(clean);
      if (match != null) {
        bhkNumbers.add(match.group(1)!);
      } else if (clean.toUpperCase().endsWith('BHK')) {
        final numPart = clean.substring(0, clean.length - 3).trim();
        if (numPart.isNotEmpty) bhkNumbers.add(numPart);
      } else {
        otherItems.add(clean);
      }
    }

    final bool isShop = propertyType.toLowerCase() == 'shop' || 
        subType.toLowerCase() == 'shop' || 
        otherItems.any((i) => i.toLowerCase().contains('shop'));

    if (bhkNumbers.isNotEmpty) {
      String nums = bhkNumbers.join(', ');
      if (isShop) {
        return '$nums BHK / Shops';
      } else if (otherItems.isNotEmpty) {
        return '$nums BHK / ${otherItems.join(', ')}';
      } else {
        return '$nums BHK';
      }
    }

    if (isShop && otherItems.isEmpty) return 'Shops';
    return list.join(' / ');
  }

  Widget _buildGridBoxes(List<Map<String, String>> cards) {
    if (cards.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.85,
        ),
        itemCount: cards.length,
        itemBuilder: (context, index) {
          final c = cards[index];
          final String label = c['label'] ?? '';
          final String value = c['value'] ?? 'N/A';

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.grey.shade200,
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBasicInfoHighlightCards(ProjectModel p, Map<String, dynamic> det) {
    final bool isLand = p.propertyType == 'Land';

    // 1. Starting Price / Plot Cost
    final minC = isLand 
        ? (det['plotCostLand'] ?? det['minCostLand'] ?? det['minCost']) 
        : (det['minCost'] ?? det['minCostLand']);
    final maxC = isLand 
        ? null 
        : (det['maxCost'] ?? det['maxCostLand']);

    String priceVal = 'On Request';
    if (minC != null && minC.toString().trim().isNotEmpty) {
      final String minStr = _formatPrice(minC.toString().trim());
      if (isLand) {
        priceVal = minStr;
      } else {
        if (maxC != null && maxC.toString().trim().isNotEmpty) {
          final String maxStr = _formatPrice(maxC.toString().trim());
          final String cleanMax = maxStr.replaceAll('₹', '').trim();
          if (minStr != maxStr && cleanMax.isNotEmpty && cleanMax != 'N/A') {
            priceVal = '$minStr - $cleanMax';
          } else {
            priceVal = minStr;
          }
        } else {
          priceVal = minStr;
        }
      }
    } else if (det['startingPrice'] != null && det['startingPrice'].toString().trim().isNotEmpty) {
      priceVal = _formatPrice(det['startingPrice'].toString());
    }

    // 2. Configuration or SubType (for Land)
    String configVal = 'N/A';
    if (isLand) {
      configVal = (det['subType'] ?? '').toString().trim();
      if (configVal.isEmpty || configVal == 'null') configVal = 'Land';
    } else {
      configVal = _formatConfiguration(
        det['configuration'],
        p.propertyType,
        (det['subType'] ?? '').toString(),
      );
    }

    // 3. Total Area in Guntha (for Land) or Total Units Left (for non-Land)
    String card3Val = 'N/A';
    String card3Label = isLand ? 'Total Area' : 'Total Units Left';
    if (isLand) {
      final guntha = (det['totalAreaGuntha'] ?? '').toString().trim();
      card3Val = guntha.isNotEmpty && guntha != 'null' ? '$guntha Guntha' : 'N/A';
    } else {
      final rawLeft = (det['totalUnitsLeft'] ?? '').toString().trim();
      final rawTotal = (det['totalUnits'] ?? '').toString().trim();
      if (rawLeft.isNotEmpty && rawLeft != 'null' && rawLeft != 'N/A') {
        card3Val = '$rawLeft Units';
      } else if (rawTotal.isNotEmpty && rawTotal != 'null' && rawTotal != 'N/A') {
        card3Val = '$rawTotal Units';
      }
    }

    // 4. Zone (for Land) or Possession (for non-Land)
    String card4Val = 'N/A';
    String card4Label = isLand ? 'Zone' : 'Possession';
    if (isLand) {
      card4Val = (det['zone'] ?? 'N/A').toString().trim();
      if (card4Val.isEmpty || card4Val == 'null') card4Val = 'N/A';
    } else {
      card4Val = _formatDateValue(det['possessionDate']);
      if (card4Val.isEmpty || card4Val == 'null' || card4Val == 'N/A') {
        final status = (det['status'] ?? '').toString().trim();
        final lastUp = _formatDateValue(det['lastUpdatedOn']);
        if (status.isNotEmpty && status != 'N/A') {
          card4Val = status;
        } else if (lastUp.isNotEmpty && lastUp != 'N/A') {
          card4Val = lastUp.split(',').first.trim();
        } else {
          card4Val = 'Ready To Move';
        }
      }
    }

    final cards = [
      {
        'label': 'Starting Price',
        'value': priceVal,
        'isOrange': true,
      },
      {
        'label': card3Label,
        'value': card3Val,
        'isOrange': false,
      },
      {
        'label': isLand ? 'Property Sub Type' : 'Configuration',
        'value': configVal,
        'isOrange': false,
      },
      {
        'label': card4Label,
        'value': card4Val,
        'isOrange': false,
      },
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.85,
        ),
        itemCount: cards.length,
        itemBuilder: (context, index) {
          final c = cards[index];
          final bool isOrange = c['isOrange'] == true;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isOrange ? const Color(0xFFFFF5EE) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isOrange ? const Color(0xFFFFE2D4) : Colors.grey.shade200,
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  c['label'] as String,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isOrange ? const Color(0xFFFF6B22) : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    c['value'] as String,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: isOrange ? const Color(0xFFFF6B22) : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatDateValue(dynamic value) {
    if (value == null) return '';
    if (value is DateTime) {
      return DateFormat('dd MMM yyyy').format(value);
    }
    if (value is Timestamp) {
      return DateFormat('dd MMM yyyy').format(value.toDate());
    }
    final String valStr = value.toString().trim();
    if (valStr.contains('Timestamp(') && valStr.contains('seconds=')) {
      final match = RegExp(r'seconds=(\d+)').firstMatch(valStr);
      if (match != null) {
        final seconds = int.tryParse(match.group(1) ?? '');
        if (seconds != null) {
          final dt = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
          return DateFormat('dd MMM yyyy').format(dt);
        }
      }
    }
    return valStr;
  }

  Widget _buildDetailGrid(List<Map<String, dynamic>> rawItems) {
    final List<Map<String, String>> processed = [];
    final List<Map<String, String>> fullWidthItems = [];

    for (var item in rawItems) {
      final label = (item['label'] ?? '').toString();
      final value = item['value'];
      if (label.isEmpty) continue;

      String valStr = 'N/A';
      if (value != null) {
        if (value is bool) {
          valStr = value ? 'Yes' : 'No';
        } else if (value is DateTime || value is Timestamp) {
          valStr = _formatDateValue(value);
        } else if (value.toString().trim().isNotEmpty) {
          valStr = _formatDateValue(value);
        }
      }

      if (label.toLowerCase().contains('full address') || label.toLowerCase().contains('last updated')) {
        fullWidthItems.add({'label': label, 'value': valStr});
      } else {
        processed.add({'label': label, 'value': valStr});
      }
    }

    if (processed.isEmpty && fullWidthItems.isEmpty) return const SizedBox.shrink();

    final List<List<Map<String, String>>> rows = [];
    for (int i = 0; i < processed.length; i += 2) {
      if (i + 1 < processed.length) {
        rows.add([processed[i], processed[i + 1]]);
      } else {
        rows.add([processed[i]]);
      }
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // 1. Standard 2-column rows (Center-aligned)
          ...rows.asMap().entries.map((entry) {
            final int rowIndex = entry.key;
            final List<Map<String, String>> pair = entry.value;

            final left = pair[0];
            final right = pair.length > 1 ? pair[1] : null;

            return Column(
              children: [
                if (rowIndex > 0)
                  Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                left['label']!,
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade500),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                left['value']!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (right != null)
                        Container(width: 1, color: Colors.grey.shade200),
                      if (right != null)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  right['label']!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade500),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  right['value']!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        const Expanded(child: SizedBox.shrink()),
                    ],
                  ),
                ),
              ],
            );
          }),

          // 2. Full-width rows (Full Address, Last Updated) - Center-aligned
          ...fullWidthItems.map((item) {
            return Column(
              children: [
                Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          item['label']!,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade500),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item['value']!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _detailRow(String label, dynamic value) {
    String val = 'N/A';
    if (value != null) {
      if (value is bool) val = value ? 'Yes' : 'No';
      else if (value is int) val = value.toString();
      else if (value.toString().trim().isNotEmpty) val = value.toString();
    }
    if (val == 'N/A' || val.isEmpty) return const SizedBox.shrink();
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
  Widget _headerQuickActions(Map<String, dynamic> d, String? coverImg) {
    List<String> getList(String key) => (d[key] is Iterable) ? List<String>.from(d[key]) : [];

    final highlights = getList('highlightsImages');
    final outdoors = getList('outdoorsImages');
    final generalImages = getList('images');
    final videoUrl = d['projectVideo']?.toString();
    final brochureUrl = d['brochurePdf']?.toString() ?? d['brochure']?.toString();

    final String? highlightThumb = highlights.isNotEmpty ? highlights.first : (generalImages.isNotEmpty ? generalImages.first : coverImg);
    final String? outdoorThumb = outdoors.isNotEmpty ? outdoors.first : (generalImages.length > 1 ? generalImages[1] : coverImg);
    final String? videoThumb = coverImg ?? (generalImages.isNotEmpty ? generalImages.first : null);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // 1. Brochure Tile (Now First!)
          _mediaQuickTile(
            label: 'Brochure',
            tileBgColor: const Color(0xFF0F1B3B),
            centerIcon: Icons.menu_book_rounded,
            onTap: () {
              if (brochureUrl != null && brochureUrl.isNotEmpty) {
                _openFile(brochureUrl);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Brochure PDF not available.')));
              }
            },
          ),
          // 2. Highlights Tile
          _mediaQuickTile(
            label: 'Highlights',
            bgImageUrl: highlightThumb,
            onTap: () {
              final targetList = highlights.isNotEmpty ? highlights : generalImages;
              if (targetList.isNotEmpty) {
                _showFullscreenImageViewer(context, targetList, 0);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No Highlight photos uploaded yet.')));
              }
            },
          ),
          // 3. Outdoors Tile
          _mediaQuickTile(
            label: 'Outdoors',
            bgImageUrl: outdoorThumb,
            onTap: () {
              final targetList = outdoors.isNotEmpty ? outdoors : generalImages;
              if (targetList.isNotEmpty) {
                _showFullscreenImageViewer(context, targetList, 0);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No Outdoor photos uploaded yet.')));
              }
            },
          ),
          // 4. Videos Tile (Strictly YouTube only)
          _mediaQuickTile(
            label: 'Videos',
            bgImageUrl: videoThumb,
            centerIcon: Icons.play_circle_fill_rounded,
            onTap: () {
              if (videoUrl != null && videoUrl.isNotEmpty && (videoUrl.contains('youtube.com') || videoUrl.contains('youtu.be'))) {
                _showYouTubePlayerDialog(context, videoUrl);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No project video available.')));
              }
            },
          ),
        ],
      ),
    );
  }

  void _showYouTubePlayerDialog(BuildContext context, String videoUrl) {
    String? videoId;
    try {
      final uri = Uri.parse(videoUrl);
      if (uri.host.contains('youtube.com')) {
        videoId = uri.queryParameters['v'];
        if (videoId == null && uri.pathSegments.isNotEmpty) {
          videoId = uri.pathSegments.last;
        }
      } else if (uri.host.contains('youtu.be')) {
        videoId = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
      }
    } catch (_) {}

    if (videoId == null || videoId.isEmpty) {
      _openFile(videoUrl);
      return;
    }

    if (kIsWeb) {
      try {
        final origin = Uri.base.origin;
        // ignore: undefined_prefixed_name
        ui_web.platformViewRegistry.registerViewFactory(
          'youtube-iframe-$videoId',
          (int viewId) {
            final web.HTMLIFrameElement iframe = web.document.createElement('iframe') as web.HTMLIFrameElement;
            iframe.src = 'https://www.youtube.com/embed/$videoId?autoplay=1&origin=$origin';
            iframe.style.border = 'none';
            iframe.style.width = '100%';
            iframe.style.height = '100%';
            iframe.allow = 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture';
            return iframe;
          },
        );
      } catch (_) {}
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: EdgeInsets.zero,
        content: Container(
          width: 560,
          height: 375,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: kIsWeb
                          ? HtmlElementView(viewType: 'youtube-iframe-$videoId')
                          : Center(
                              child: ElevatedButton.icon(
                                onPressed: () => _openFile(videoUrl),
                                icon: const Icon(Icons.play_arrow),
                                label: const Text('Play YouTube Video'),
                              ),
                            ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: CircleAvatar(
                        backgroundColor: Colors.black54,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 18),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: Colors.grey.shade900,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'If playback is restricted by YouTube:',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    TextButton.icon(
                      onPressed: () => _openFile(videoUrl),
                      icon: const Icon(Icons.open_in_new, size: 16, color: Color(0xFFFF6B22)),
                      label: const Text('Open on YouTube', style: TextStyle(color: Color(0xFFFF6B22), fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mediaQuickTile({
    required String label,
    String? bgImageUrl,
    IconData? centerIcon,
    Color? tileBgColor,
    required VoidCallback onTap,
  }) {
    final bool hasImage = bgImageUrl != null && bgImageUrl.startsWith('http');

    return Container(
      margin: const EdgeInsets.only(right: 10),
      width: 92,
      height: 68,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            // 1. Crisp Background Image or Solid Tile Color
            Positioned.fill(
              child: hasImage
                  ? Image.network(
                      bgImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1E293B)),
                    )
                  : Container(color: tileBgColor ?? const Color(0xFF0F1B3B)),
            ),

            // 2. Subtle Glass Dark Tint Overlay (Leaves Image Sharp & Visible)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.4),
                    width: 1.2,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.15),
                      Colors.black.withValues(alpha: 0.55),
                    ],
                  ),
                ),
              ),
            ),

            // 3. Subtle Icon & Soft Text
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(14),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        centerIcon ?? Icons.photo_library_outlined,
                        color: Colors.white.withValues(alpha: 0.9),
                        size: 18,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        label,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, Color> _getSubTypeColors(String subType) {
    final st = subType.trim().toLowerCase();
    
    if (st == 'new' || st == 'new launch') {
      return {
        'bg': const Color(0xFFE6F4EA), // Emerald Green
        'text': const Color(0xFF137333),
        'border': const Color(0xFFCEEAD6),
      };
    } else if (st == 'uc' || st == 'under construction') {
      return {
        'bg': const Color(0xFFFEF7E0), // Amber / Gold
        'text': const Color(0xFFB06000),
        'border': const Color(0xFFFDE293),
      };
    } else if (st == 'resale') {
      return {
        'bg': const Color(0xFFF3E8FF), // Purple / Lavender
        'text': const Color(0xFF6B21A8),
        'border': const Color(0xFFE9D5FF),
      };
    } else if (st == 'rent') {
      return {
        'bg': const Color(0xFFE8F0FE), // Soft Blue
        'text': const Color(0xFF1A73E8),
        'border': const Color(0xFFAECBFA),
      };
    } else if (st == 'rtm' || st == 'ready to move') {
      return {
        'bg': const Color(0xFFE0F2FE), // Teal / Sky Blue
        'text': const Color(0xFF0369A1),
        'border': const Color(0xFFBAE6FD),
      };
    } else if (st == 'na' || st == 'non-agricultural') {
      return {
        'bg': const Color(0xFFECFDF5), // Mint Green
        'text': const Color(0xFF047857),
        'border': const Color(0xFFA7F3D0),
      };
    } else if (st == 'non - na' || st == 'non na' || st == 'agricultural') {
      return {
        'bg': const Color(0xFFFFF1F2), // Rose Pink
        'text': const Color(0xFFBE123C),
        'border': const Color(0xFFFECDD3),
      };
    }

    return {
      'bg': const Color(0xFFF1F5F9), // Slate Grey
      'text': const Color(0xFF334155),
      'border': const Color(0xFFCBD5E1),
    };
  }

  Widget _projectHeaderSection(ProjectModel p, Map<String, dynamic> d, Map<String, dynamic> det) {
    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    final projectVM = Provider.of<ProjectViewModel>(context, listen: false);
    final List<String> favUids = (p.rawData['favUids'] is Iterable) 
        ? List<String>.from(p.rawData['favUids']) 
        : ((det['favUids'] is Iterable) 
            ? List<String>.from(det['favUids']) 
            : []);
    final bool isLiked = authVM.userUid.isNotEmpty && favUids.contains(authVM.userUid);

    final String locationText = p.displayLocation;
    final String mapLink = (det['googleLocationLink'] ?? det['locationLink'] ?? d['googleLocationLink'] ?? d['locationLink'] ?? '').toString().trim();

    final String company = (det['projectCompany'] ?? d['projectCompany'] ?? '').toString().trim();
    final String subType = (det['subType'] ?? d['subType'] ?? p.propertyType).toString().trim();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Sleek Gradient Building Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFF1EA), Color(0xFFFFE5D9)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFD4C2), width: 1),
            ),
            child: const Icon(Icons.domain_rounded, color: Color(0xFFFF6B22), size: 26),
          ),
          const SizedBox(width: 14),

          // 2. Center Content Stretched
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Title + Heart Button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          p.projectName,
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Heart Circular Interactive Button
                    InkWell(
                      onTap: () {
                        if (authVM.userUid.isNotEmpty) {
                          projectVM.toggleProjectFavorite(p.id, authVM.userUid, favUids);
                        }
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: isLiked ? Colors.red.shade50 : const Color(0xFFF8FAFC),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isLiked ? Colors.red.shade200 : const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: isLiked ? Colors.red : const Color(0xFF64748B),
                            size: 20,
                          ),
                        ),
                      ),
                    ),

                    // Hot Icon Button (Admin & Super Admin only)
                    if (authVM.appRole == AppRole.admin || authVM.appRole == AppRole.superAdmin) ...[
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () {
                          final bool currentHot = p.isHot == true || p.isHot.toString().toLowerCase() == 'true';
                          projectVM.toggleHotStatus(p.id, !currentHot);
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: (p.isHot == true || p.isHot.toString().toLowerCase() == 'true') ? Colors.orange.shade50 : const Color(0xFFF8FAFC),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: (p.isHot == true || p.isHot.toString().toLowerCase() == 'true') ? Colors.orange.shade200 : const Color(0xFFE2E8F0),
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.local_fire_department_rounded,
                              color: (p.isHot == true || p.isHot.toString().toLowerCase() == 'true') ? Colors.orange : const Color(0xFF64748B),
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                // Company Subtitle ("By Laxmi Associates")
                if (company.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        'By ',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      Expanded(
                        child: Text(
                          company,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xFF334155), fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 6),

                // 🚀 NAYA: Amazon-Style Rating & Separate Circular "Tap to Rate" Button with Edit Icon
                Row(
                  children: [
                    Row(
                      children: List.generate(5, (i) {
                        final double rating = p.avgRating;
                        IconData icon = Icons.star_border_rounded;
                        if (i < rating.floor()) {
                          icon = Icons.star_rounded;
                        } else if (i < rating) {
                          icon = Icons.star_half_rounded;
                        }
                        return Icon(icon, color: Colors.amber.shade600, size: 16);
                      }),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${p.avgRating > 0 ? p.avgRating.toStringAsFixed(1) : 'No Rating'} (${p.ratingCount})',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                    const SizedBox(width: 12),
                    StreamBuilder<DocumentSnapshot>(
                      stream: authVM.userUid.isNotEmpty
                          ? FirebaseFirestore.instance.collection('projects').doc(p.id).collection('ratings').doc(authVM.userUid).snapshots()
                          : const Stream.empty(),
                      builder: (context, snapshot) {
                        final bool hasRated = snapshot.hasData && snapshot.data!.exists;
                        return InkWell(
                          onTap: () => _showRatingDialog(context, p),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade300, width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  hasRated ? 'Rated' : 'Tap to Rate',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                                ),
                                const SizedBox(width: 4),
                                Icon(hasRated ? Icons.edit : Icons.star_outline_rounded, size: 12, color: Colors.grey.shade700),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Bottom Row: Location Pill Button on Left, SubType Badge on Right
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: () {
                        if (mapLink.isNotEmpty) {
                          _openFile(mapLink);
                        } else if (locationText != 'Location N/A') {
                          final String queryUrl = 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent("${p.projectName}, $locationText")}';
                          _openFile(queryUrl);
                        }
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.blue.shade200, width: 1.2),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_on_rounded, size: 14, color: Colors.blue.shade700),
                            const SizedBox(width: 4),
                            Text(
                              locationText,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),

                    // Property Sub Type Pill Badge (Right Aligned!)
                    if (subType.isNotEmpty) ...[
                      () {
                        final colors = _getSubTypeColors(subType);
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: colors['bg'],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: colors['border']!, width: 1.2),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: colors['text'],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                subType,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: colors['text'],
                                ),
                              ),
                            ],
                          ),
                        );
                      }(),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🚀 BLUE MARK: Share Button at the right side of bottom bar
  Widget _bottomActions(Map<String, dynamic> det) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), 
    decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]), 
    child: Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () => _handleGetDetailsWhatsApp(context),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade50, elevation: 0),
            child: const Text('Get Details', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: ElevatedButton(onPressed: () => _makeCall(widget.project.contactNumber), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B22), elevation: 0), child: const Text('Call Now', style: TextStyle(color: Colors.white)))),
        const SizedBox(width: 12),
        Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            color: Colors.blue.shade600,
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.white, size: 20),
            onPressed: () => _handleShare(context),
          ),
        ),
      ],
    ),
  );

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

  Widget _buildEditHistorySection(ProjectModel project) {
    final List<dynamic> history = (project.rawData['editHistory'] is Iterable)
        ? List<dynamic>.from(project.rawData['editHistory'])
        : [];

    return _buildSection(
      'Edit History (${history.length})',
      Icons.history_rounded,
      history.isEmpty
          ? [const Text('No edit history recorded yet.', style: TextStyle(color: Colors.grey, fontSize: 13))]
          : history.map((entry) {
              final map = entry is Map ? Map<String, dynamic>.from(entry) : <String, dynamic>{};
              final String editorName = map['editorName'] ?? 'Unknown';
              final String role = map['role'] ?? 'User';
              final String action = map['action'] ?? 'Updated';
              final dynamic ts = map['timestamp'];
              String timeStr = 'Recently';
              if (ts != null && ts is Timestamp) {
                timeStr = DateFormat('dd/MM/yyyy hh:mm a').format(ts.toDate());
              } else if (ts != null && ts is String) {
                timeStr = ts;
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: action == 'Created' ? Colors.green.shade50 : Colors.blue.shade50,
                      child: Icon(
                        action == 'Created' ? Icons.add_circle_outline : Icons.edit_outlined,
                        size: 14,
                        color: action == 'Created' ? Colors.green : Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$editorName ($role) - $action', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                          const SizedBox(height: 2),
                          Text(timeStr, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
    );
  }

  void _showRatingDialog(BuildContext context, ProjectModel p) {
    int selectedRating = 5;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Rate ${p.projectName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Tap stars to give your rating:', style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < selectedRating ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: Colors.amber.shade600,
                      size: 36,
                    ),
                    onPressed: () {
                      setDialogState(() {
                        selectedRating = index + 1;
                      });
                    },
                  );
                }),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final authVM = Provider.of<AuthViewModel>(context, listen: false);
                final projectVM = Provider.of<ProjectViewModel>(context, listen: false);
                if (authVM.userUid.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please login to submit a rating.')));
                  return;
                }
                Navigator.of(ctx).pop();
                try {
                  await projectVM.submitProjectRating(p.id, authVM.userUid, selectedRating);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Thank you for rating! ⭐'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B22),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Submit Rating', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
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
