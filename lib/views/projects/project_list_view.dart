import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/project_viewmodel.dart';
import '../../models/project_model.dart';
import '../../widgets/app_bottom_nav.dart';

class ProjectListView extends StatefulWidget {
  const ProjectListView({super.key});

  @override
  State<ProjectListView> createState() => _ProjectListViewState();
}

class _ProjectListViewState extends State<ProjectListView> with TickerProviderStateMixin {
  // --- FILTER STATES ---
  String _selectedTab = 'All Projects';
  String? _selectedConditionFilter;
  String? _selectedTypeFilter;
  String _searchQuery = '';
  String? _selectedCity;

  // --- Expanded Search Popup State ---
  String _searchCategory = 'Residential';
  bool _isDetectingLocation = false;

  final Map<String, List<String>> _activeFilters = {};

  static const List<String> _categoryTabs = ['All Projects', 'My projects', 'Hot projects'];

  // --- THEME COLORS ---
  final Color _primaryLight = Colors.yellow.shade300;
  final Color _primaryMid = Colors.yellow.shade400;
  final Color _primaryDark = Colors.amber.shade800;

  // --- LOCAL STATE FOR RATINGS & LIKES ---
  final Map<String, bool> _likedProjects = {};
  final Map<String, int> _projectRatings = {};
  final Set<String> _selectedProjectIds = <String>{};

  bool get _isSelectionMode => _selectedProjectIds.isNotEmpty;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categoryTabs.length, vsync: this);

    _tabController.addListener(() {
      if (_selectedTab != _categoryTabs[_tabController.index]) {
        setState(() {
          _selectedTab = _categoryTabs[_tabController.index];
          _selectedProjectIds.clear();
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _toggleProjectSelection(String projectId) {
    setState(() {
      if (_selectedProjectIds.contains(projectId)) {
        _selectedProjectIds.remove(projectId);
      } else {
        _selectedProjectIds.add(projectId);
      }
    });
  }

  void _clearSelection() {
    if (_selectedProjectIds.isEmpty) return;
    setState(() => _selectedProjectIds.clear());
  }

  void _selectAllFiltered(List<ProjectModel> filteredProjects) {
    setState(() {
      final filteredIds = filteredProjects.map((project) => project.id).toSet();
      if (_selectedProjectIds.length == filteredIds.length &&
          _selectedProjectIds.containsAll(filteredIds)) {
        _selectedProjectIds.clear();
      } else {
        _selectedProjectIds
          ..clear()
          ..addAll(filteredIds);
      }
    });
  }

  Future<void> _deleteSelectedProjects(ProjectViewModel projectVM) async {
    if (_selectedProjectIds.isEmpty) return;

    final count = _selectedProjectIds.length;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $count project${count > 1 ? 's' : ''}?'),
        content: const Text('Selected projects and their inventory will be deleted permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B22)),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    try {
      await projectVM.deleteMultipleProjects(_selectedProjectIds.toList());
      if (!mounted) return;
      _clearSelection();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$count project${count > 1 ? 's' : ''} deleted successfully.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  String _formatKeyName(String key) {
    if (key == 'legality') return 'Legality Status';
    if (key == 'bhk') return 'Configuration (BHK)';
    if (key == 'fsi') return 'FSI Approved';
    if (key == 'naStatus') return 'NA Status';
    if (key == 'satbara') return '7/12 (Satbara)';
    if (key == 'titleClear') return 'Title Clear';

    String formatted = key.replaceAllMapped(RegExp(r'[A-Z]'), (match) => ' ${match.group(0)}').trim();
    if (formatted.isEmpty) return key;
    return formatted[0].toUpperCase() + formatted.substring(1);
  }

  String _getDynamicListTitle() {
    String condition = _selectedConditionFilter ?? '';
    String type = _selectedTab == 'All' ? 'Projects' : '$_selectedTab Projects';
    String city = _selectedCity != null ? 'in $_selectedCity' : '';

    List<String> parts = [];
    if (condition.isNotEmpty) parts.add(condition);
    parts.add(type);
    if (city.isNotEmpty) parts.add(city);

    return parts.join(' ').trim();
  }

  Future<void> _detectCurrentCity(StateSetter setModalState) async {
    setModalState(() => _isDetectingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw 'Please enable Location Services in your browser/device.';

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw 'Location permission denied.';
      }
      if (permission == LocationPermission.deniedForever) throw 'Location permission permanently denied.';

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      String city = '';

      if (kIsWeb) {
        final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=10&addressdetails=1',
        );

        final response = await http.get(url, headers: {'User-Agent': 'RSWA-App-Web-Client'});

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['address'] != null) {
            city = data['address']['city'] ?? data['address']['town'] ?? data['address']['state_district'] ?? '';
          }
        } else {
          throw 'Failed to get location from Web API.';
        }
      } else {
        List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          city = place.locality ?? place.subAdministrativeArea ?? '';
        }
      }

      if (city.isNotEmpty) {
        setState(() {
          _selectedCity = city;
          _selectedTab = 'All Projects';
          _tabController.index = 0;
        });
        if (context.mounted) Navigator.pop(context);
      } else {
        throw 'Could not determine city name from coordinates.';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    } finally {
      setModalState(() => _isDetectingLocation = false);
    }
  }

  void _showSearchPopup() {
    String tempQuery = _searchQuery;
    String tempCategory = _searchCategory;
    String? tempType = _selectedTypeFilter;
    String? tempCity = _selectedCity;
    String? tempCondition = _selectedConditionFilter;

    TextEditingController tempSearchCtrl = TextEditingController(text: tempQuery);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 16,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                  ),
                  const SizedBox(height: 24),

                  const Text('Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 12),
                  Row(
                    children: ['Residential', 'Commercial', 'Plot'].map((cat) {
                      bool isSelected = tempCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: _buildPopupChip(cat, isSelected, () => setModalState(() => tempCategory = cat)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  const Text('Property Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['Flat', 'Bungalow', 'Shop', 'Office', 'Plot'].map((type) {
                        bool isSelected = tempType == type;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: _buildPopupChip(type, isSelected, () => setModalState(() => tempType = isSelected ? null : type)),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text('Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final city = await context.push<String>('/city-select');
                      if (city != null) setModalState(() => tempCity = city);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          Icon(Icons.location_on_outlined, color: _primaryDark, size: 20),
                          const SizedBox(width: 12),
                          Text(tempCity ?? 'Select City', style: TextStyle(color: tempCity != null ? Colors.black87 : Colors.grey)),
                          const Spacer(),
                          if (tempCity != null) IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () => setModalState(() => tempCity = null)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  InkWell(
                    onTap: _isDetectingLocation ? null : () => _detectCurrentCity(setModalState),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          Icon(Icons.my_location, color: Colors.blue.shade600, size: 16),
                          const SizedBox(width: 8),
                          Text(_isDetectingLocation ? 'Detecting...' : 'Use current location', style: TextStyle(color: Colors.blue.shade600, fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text('Search', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: tempSearchCtrl,
                    onChanged: (val) => tempQuery = val,
                    decoration: InputDecoration(
                      hintText: 'Project name..',
                      suffixIcon: Icon(Icons.search, color: _primaryDark),
                      border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
                    ),
                  ),
                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _searchQuery = tempQuery;
                          _searchCategory = tempCategory;
                          _selectedTypeFilter = tempType;
                          _selectedCity = tempCity;
                          _selectedConditionFilter = tempCondition;
                          _selectedProjectIds.clear();
                        });
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: _primaryDark, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('EXPLORE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPopupChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _primaryLight.withOpacity(0.3) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? _primaryDark : Colors.grey.shade300),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isSelected ? _primaryDark : Colors.black87)),
      ),
    );
  }

  bool _matchesSearchCategory(String type) {
    if (_searchCategory == 'Residential') {
      return type.toLowerCase() == 'flat' || type.toLowerCase() == 'bungalow';
    } else if (_searchCategory == 'Commercial') {
      return type.toLowerCase() == 'shop' ||
          type.toLowerCase() == 'office' ||
          type.toLowerCase() == 'showroom';
    } else if (_searchCategory == 'Plot') {
      return type.toLowerCase() == 'plot';
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final authVM = Provider.of<AuthViewModel>(context);
    final projectVM = Provider.of<ProjectViewModel>(context);

    List<Widget> activeChips = [];
    _activeFilters.forEach((key, values) {
      for (var val in values) {
        activeChips.add(
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Chip(
              label: Text(
                '${_formatKeyName(key)}: $val',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _primaryDark),
              ),
              backgroundColor: Colors.white,
              side: BorderSide(color: _primaryDark),
              deleteIconColor: _primaryDark,
              onDeleted: () => setState(() => _activeFilters[key]!.remove(val)),
            ),
          ),
        );
      }
    });

    if (_selectedConditionFilter != null) {
      activeChips.insert(
        0,
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: Chip(
            label: Text(
              'Condition: $_selectedConditionFilter',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _primaryDark),
            ),
            backgroundColor: Colors.white,
            side: BorderSide(color: _primaryDark),
            deleteIconColor: _primaryDark,
            onDeleted: () => setState(() => _selectedConditionFilter = null),
          ),
        ),
      );
    }

    if (_searchQuery.isNotEmpty || _searchCategory != 'Residential') {
      activeChips.insert(
        0,
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: Chip(
            label: Text(
              'Search: $_searchCategory${_searchQuery.isNotEmpty ? ' - $_searchQuery' : ''}',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
            ),
            backgroundColor: Colors.blue.shade50,
            side: BorderSide(color: Colors.blue.shade800),
            deleteIconColor: Colors.blue.shade800,
            onDeleted: () => setState(() {
              _searchQuery = '';
              _searchCategory = 'Residential';
            }),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            _isSelectionMode ? Icons.close : Icons.arrow_back,
            color: Colors.black,
          ),
          onPressed: () {
            if (_isSelectionMode) {
              _clearSelection();
            } else {
              context.pop();
            }
          },
        ),
        title: Text(
          _isSelectionMode ? '${_selectedProjectIds.length} selected' : 'Inventory',
          key: const ValueKey('titleText'),
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.select_all_rounded, color: Colors.black87),
              onPressed: () => _selectAllFiltered(projectVM.projects),
              tooltip: 'Select all',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.black87),
              onPressed: () => _deleteSelectedProjects(projectVM),
              tooltip: 'Delete selected',
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.search, color: Colors.black87),
              onPressed: _showSearchPopup,
            ),
            IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.black87),
              onPressed: () {},
            ),
          ],
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            color: Colors.white,
            width: double.infinity,
            child: TabBar(
              controller: _tabController,
              indicatorColor: _primaryDark,
              indicatorWeight: 2.5,
              dividerColor: Colors.transparent,
              labelColor: Colors.black,
              labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              unselectedLabelColor: Colors.grey.shade500,
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              tabs: _categoryTabs.map((tab) => Tab(text: tab)).toList(),
            ),
          ),
          const SizedBox(height: 8),

          if (activeChips.isNotEmpty)
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: activeChips),
              ),
            ),

          if (_selectedCity != null || _selectedConditionFilter != null || _selectedTypeFilter != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: SizedBox(
                width: double.infinity,
                child: Text(
                  _getDynamicListTitle(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.black87),
                ),
              ),
            ),

          Expanded(
            child: projectVM.isLoading
                ? Center(child: CircularProgressIndicator(color: _primaryDark))
                : TabBarView(
              controller: _tabController,
              children: _categoryTabs.map((currentTabName) {
                final displayProjects = projectVM.projects.where((project) {
                  if (currentTabName == 'My projects') {
                    if (project.createdByUid != authVM.userUid) return false;
                  } else if (currentTabName == 'Hot projects') {
                    int rating = _projectRatings[project.id] ?? 0;
                    bool liked = _likedProjects[project.id] ?? false;
                    if (!project.isHot && rating < 4 && !liked) return false;
                  }

                  if (_searchQuery.isNotEmpty) {
                    if (!project.projectName.toLowerCase().contains(_searchQuery.toLowerCase())) return false;
                  }
                  if (!_matchesSearchCategory(project.propertyType)) return false;
                  if (_selectedTypeFilter != null && project.propertyType != _selectedTypeFilter) return false;
                  if (!_matchesSelectedCondition(project)) return false;

                  if (_selectedCity != null) {
                    String rawLoc = project.propertyDetails['location']?.toString() ?? '';
                    String city = rawLoc.split(',').last.trim();
                    if (city.toLowerCase() != _selectedCity!.toLowerCase()) return false;
                  }

                  return true;
                }).toList();

                displayProjects.sort((a, b) {
                  if (a.isHot && !b.isHot) return -1;
                  if (!a.isHot && b.isHot) return 1;

                  int aRating = _projectRatings[a.id] ?? 0;
                  int bRating = _projectRatings[b.id] ?? 0;
                  if (aRating != bRating) return bRating.compareTo(aRating);

                  bool aLiked = _likedProjects[a.id] ?? false;
                  bool bLiked = _likedProjects[b.id] ?? false;
                  if (aLiked && !bLiked) return -1;
                  if (!aLiked && bLiked) return 1;

                  return 0;
                });

                if (displayProjects.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_open_rounded, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('No $currentTabName found', style: TextStyle(color: Colors.grey.shade500)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: displayProjects.length,
                  itemBuilder: (context, index) {
                    final project = displayProjects[index];
                    return _buildProjectCard(project);
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
      floatingActionButton:
      _isSelectionMode || !authVM.permissions.canAddProjects
          ? null
          : Padding(
        padding: const EdgeInsets.only(bottom: 20.0),
        child: FloatingActionButton(
          onPressed: () => context.push('/add-project'),
          backgroundColor: const Color(0xFFFDE047),
          child: const Icon(Icons.add, color: Colors.black87),
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        currentTab: 'projects',
        backgroundColor: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
        activeGradientColors: [_primaryLight, _primaryMid],
        activeIconColor: Colors.black87,
        activeLabelColor: _primaryDark,
        inactiveIconColor: Colors.grey.shade600,
        projectsLabel: 'Projects',
        cpLabel: 'Network',
      ),
    );
  }

  Widget _buildProjectCard(ProjectModel project) {
    final details = project.propertyDetails;
    List<String> imageUrls = details['images'] != null ? List<String>.from(details['images']) : [];
    final location = details['location']?.toString() ?? 'Location N/A';
    final price = details['startingPrice']?.toString() ?? 'On Request';
    final condition = details['condition']?.toString() ?? 'New';
    bool isLiked = _likedProjects[project.id] ?? false;
    int currentRating = _projectRatings[project.id] ?? 0;

    String bhk = details['bhk']?.toString() ?? '';
    String area = details['carpetArea']?.toString() ?? details['totalArea']?.toString() ?? details['plotArea']?.toString() ?? '';
    String subTitle = '${bhk.isNotEmpty && bhk != 'N/A' ? '$bhk ' : ''}${project.propertyType}${area.isNotEmpty && area != 'N/A' && area != ' Sq.ft' ? ' - $area' : ''}';

    IconData typeIcon = Icons.apartment_outlined;
    if (project.propertyType == 'Plot') typeIcon = Icons.landscape_outlined;
    else if (project.propertyType == 'Bungalow') typeIcon = Icons.gite_outlined;
    else if (project.propertyType == 'Shop') typeIcon = Icons.storefront_outlined;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (_isSelectionMode) _toggleProjectSelection(project.id);
            else context.push('/project-detail', extra: project);
          },
          onLongPress: () => _toggleProjectSelection(project.id),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    // 🚀 NAYA: Image Height Badha Di (140) taaki badi dikhe
                    Container(
                      width: 110,
                      height: 140,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        image: imageUrls.isNotEmpty ? DecorationImage(image: NetworkImage(imageUrls.first), fit: BoxFit.cover) : null,
                      ),
                      child: imageUrls.isEmpty ? Center(child: Icon(typeIcon, color: Colors.grey.shade400, size: 40)) : null,
                    ),
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                        child: Row(
                          children: [
                            const Icon(Icons.photo_library_outlined, color: Colors.white, size: 10),
                            const SizedBox(width: 4),
                            Text('${imageUrls.length}+', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: const BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
                        ),
                        child: const Text('Updated today', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 9)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🚀 NAYA: Project Name Top Par Aa Gaya
                      Text(project.projectName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.black87)),
                      const SizedBox(height: 4),

                      Row(
                        children: [
                          Expanded(
                            child: Text(price, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black87)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Text(condition, style: TextStyle(fontSize: 10, color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => setState(() => _likedProjects[project.id] = !isLiked),
                            child: Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: isLiked ? Colors.red : Colors.grey.shade400, size: 24),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // 🚀 NAYA: Rating Flat/Bungalow (Property Type) Ke Saamne
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(project.propertyType, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500)),
                          const SizedBox(width: 12),
                          Row(
                            children: List.generate(5, (starIndex) {
                              return GestureDetector(
                                onTap: () => setState(() => _projectRatings[project.id] = (currentRating == starIndex + 1) ? 0 : starIndex + 1),
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 2),
                                  child: Icon(
                                    starIndex < currentRating ? Icons.star_rounded : Icons.star_outline_rounded,
                                    color: Colors.amber.shade600,
                                    size: 16,
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      Row(
                        children: [
                          Icon(Icons.location_on, size: 14, color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(location, style: TextStyle(color: Colors.grey.shade500, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(child: _mockupButton('Get Quote', () {})),
                          const SizedBox(width: 10),
                          Expanded(child: _mockupButton('Get Brochure', () => context.push('/project-detail', extra: project))),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _mockupButton(String label, VoidCallback onTap) {
    return SizedBox(
      height: 32,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFFF6B22), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: EdgeInsets.zero,
        ),
        child: Text(label, style: const TextStyle(color: Color(0xFFFF6B22), fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }

  bool _matchesSelectedCondition(ProjectModel project) {
    if (_selectedConditionFilter == null || _selectedConditionFilter!.isEmpty) return true;
    final condition = project.propertyDetails['condition']?.toString().trim().toLowerCase() ?? 'new';
    return condition == _selectedConditionFilter!.trim().toLowerCase();
  }
}