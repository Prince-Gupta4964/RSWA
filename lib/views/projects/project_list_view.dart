import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../utils/meta_tag_helper.dart'; // 🚀 NAYA
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/project_viewmodel.dart';
import '../../viewmodels/app_configuration_viewmodel.dart';
import '../../models/project_model.dart';
import '../../utils/role_permissions.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/app_drawer.dart';

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
  bool _isSearching = false; // 🚀 NAYA
  int? _lastSearchTriggerCount; // 🚀 NAYA
  final FocusNode _searchFocusNode = FocusNode(); // 🚀 NAYA

  // --- Expanded Search Popup State ---
  String _searchCategory = 'Residential';
  bool _isDetectingLocation = false;

  final Map<String, List<String>> _activeFilters = {};

  // --- THEME COLORS ---
  final Color _primaryLight = Colors.yellow.shade300;
  final Color _primaryMid = Colors.yellow.shade400;
  final Color _primaryDark = Colors.amber.shade800;

  bool get _isSelectionMode => _selectedProjectIds.isNotEmpty;

  List<String> _getCategoryTabs(AuthViewModel authVM) {
    List<String> tabs = ['All Projects', 'My Projects'];
    if (authVM.appRole == AppRole.admin || authVM.appRole == AppRole.superAdmin) {
      tabs.add('Pending');
    }
    tabs.addAll(['Hot Projects', 'Fav Projects']);
    return tabs;
  }

  late TabController _tabController;

  final Map<String, bool> _likedProjects = {};
  final Map<String, int> _projectRatings = {};
  final Set<String> _selectedProjectIds = <String>{};

  @override
  void initState() {
    super.initState();
    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    final tabs = _getCategoryTabs(authVM);
    _tabController = TabController(length: tabs.length, vsync: this);

    _tabController.addListener(() {
      final currentTabs = _getCategoryTabs(authVM);
      if (_selectedTab != currentTabs[_tabController.index]) {
        setState(() {
          _selectedTab = currentTabs[_tabController.index];
          _selectedProjectIds.clear();
        });
      }
    });

    // 🚀 NAYA: Auto-close search when focus is lost
    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus && _isSearching && _searchQuery.isEmpty) {
        setState(() {
          _isSearching = false;
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
        title: Text('Move $count item${count > 1 ? 's' : ''} to Recycle Bin?'),
        content: const Text('Deleted projects can be restored or permanently removed from the Recycle Bin in the sidebar.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B22)),
            child: const Text('Move to Bin', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    try {
      await projectVM.softDeleteMultipleProjects(_selectedProjectIds.toList());
      if (!mounted) return;
      _clearSelection();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$count item${count > 1 ? 's' : ''} moved to Recycle Bin.'),
          backgroundColor: Colors.orange.shade800,
          action: SnackBarAction(label: 'VIEW BIN', textColor: Colors.white, onPressed: () => context.push('/recycle-bin')),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
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
    final t = type.toLowerCase();
    if (t == 'project') return true;
    if (_searchCategory == 'Residential') {
      return t == 'flat' || t == 'bungalow';
    } else if (_searchCategory == 'Commercial') {
      return t == 'shop' ||
          t == 'office' ||
          t == 'showroom';
    } else if (_searchCategory == 'Plot') {
      return t == 'plot' || t == 'land';
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final authVM = Provider.of<AuthViewModel>(context);
    final projectVM = Provider.of<ProjectViewModel>(context);
    final configVM = Provider.of<AppConfigurationViewModel>(context); // 🚀 NAYA

    // 🚀 NAYA: Handle Double-Tap Search Trigger
    if (_lastSearchTriggerCount == null) {
      _lastSearchTriggerCount = configVM.searchTriggerCount;
    } else if (configVM.searchTriggerCount > _lastSearchTriggerCount! && configVM.activeSearchTab == 'projects') {
      _lastSearchTriggerCount = configVM.searchTriggerCount;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _isSearching = true);
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) _searchFocusNode.requestFocus();
          });
        }
      });
    }

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

    final tabs = _getCategoryTabs(authVM);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isSelectionMode) {
          _clearSelection();
        } else if (_isSearching) {
          _searchFocusNode.unfocus();
          setState(() {
            _isSearching = false;
            _searchQuery = '';
          });
        } else {
          StatefulNavigationShell.of(context).goBranch(0);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: _isSelectionMode 
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.black),
                onPressed: _clearSelection,
              )
            : Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu, color: Colors.black),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
          title: _isSearching
              ? TextField(
                  focusNode: _searchFocusNode,
                  autofocus: true,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: const InputDecoration(
                    hintText: 'Search projects...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  style: const TextStyle(color: Colors.black, fontSize: 16),
                )
              : Text(
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
              if (_isSearching)
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black),
                  onPressed: () {
                    setState(() {
                      _isSearching = false;
                      _searchQuery = '';
                    });
                  },
                )
              else ...[
                IconButton(
                  icon: const Icon(Icons.search, color: Colors.black87),
                  onPressed: () => setState(() => _isSearching = true),
                  tooltip: 'Search',
                ),
                IconButton(
                  icon: const Icon(Icons.tune_rounded, color: Colors.black87),
                  onPressed: _showSearchPopup,
                  tooltip: 'Filter',
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.black87),
                  onSelected: (value) {
                    if (value == 'filter') {
                      _showSearchPopup();
                    } else if (value == 'profile') {
                      context.push('/profile');
                    } else if (value == 'select') {
                      setState(() {
                        // Enter selection mode by adding first visible project
                        if (projectVM.projects.isNotEmpty) {
                          _selectedProjectIds.add(projectVM.projects.firstWhere((p) => !p.isDeleted).id);
                        }
                      });
                    }
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'select',
                      child: Row(
                        children: [
                          Icon(Icons.check_box_outlined, color: Colors.black54),
                          SizedBox(width: 12),
                          Text('Select Projects'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'filter',
                      child: Row(
                        children: [
                          Icon(Icons.tune_rounded, color: Colors.black54),
                          SizedBox(width: 12),
                          Text('Filter Projects'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'profile',
                      child: Row(
                        children: [
                          Icon(Icons.account_circle_outlined, color: Colors.black54),
                          SizedBox(width: 12),
                          Text('Profile / Score'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
        drawer: const AppDrawer(),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              color: Colors.white,
              width: double.infinity,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: _primaryDark,
                indicatorWeight: 2.5,
                dividerColor: Colors.transparent,
                labelColor: Colors.black,
                labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                unselectedLabelColor: Colors.grey.shade500,
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                tabs: tabs.map((tab) => Tab(text: tab)).toList(),
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
                      children: tabs.map((currentTabName) {
                        final displayProjects = projectVM.projects.where((project) {
                          final isApproved = project.isApproved;
                          final creatorUid = project.createdByUid;

                          if (currentTabName == 'All Projects') {
                            if (!isApproved) return false;
                          } else if (currentTabName == 'Pending') {
                            if (isApproved) return false;
                          } else if (currentTabName == 'My Projects') {
                            if (creatorUid != authVM.userUid) return false;
                          } else if (currentTabName == 'Hot Projects') {
                            int rating = _projectRatings[project.id] ?? 0;
                            bool liked = _likedProjects[project.id] ?? false;
                            if (!project.isHot && rating < 4 && !liked) return false;
                            if (!isApproved) return false;
                          } else if (currentTabName == 'Fav Projects') {
                            bool liked = _likedProjects[project.id] ?? false;
                            if (!liked) return false;
                          }

                          if (_searchQuery.isNotEmpty) {
                            if (!project.projectName.toLowerCase().contains(_searchQuery.toLowerCase())) return false;
                          }

                          // 🚀 NAYA: "My Projects", "Pending", and "Fav Projects" tabs should ignore category/type/city filters
                          // so users can always find their own work, items needing approval, or favorites.
                          final bool isBypassTab = currentTabName == 'My Projects' || currentTabName == 'Pending' || currentTabName == 'Fav Projects';
                          
                          if (!isBypassTab) {
                            if (!_matchesSearchCategory(project.propertyType)) return false;
                            if (_selectedTypeFilter != null && project.propertyType != _selectedTypeFilter) return false;
                            if (!_matchesSelectedCondition(project)) return false;

                            if (_selectedCity != null) {
                              String rawLoc = project.propertyDetails['location']?.toString() ?? '';
                              String city = rawLoc.split(',').last.trim();
                              if (city.toLowerCase() != _selectedCity!.toLowerCase()) return false;
                            }
                          }

                          return true;
                        }).toList();

                        displayProjects.sort((a, b) {
                          // 1. Hot projects always at the top
                          if (a.isHot && !b.isHot) return -1;
                          if (!a.isHot && b.isHot) return 1;

                          // 2. Newest projects first (recently added)
                          final t1 = a.rawData['timestamp'];
                          final t2 = b.rawData['timestamp'];
                          if (t1 != null && t2 != null && t1 is Timestamp && t2 is Timestamp) {
                            int timeCompare = t2.compareTo(t1); // Descending (newest first)
                            if (timeCompare != 0) return timeCompare;
                          }

                          // 3. Fallback: Rating
                          int aRating = _projectRatings[a.id] ?? 0;
                          int bRating = _projectRatings[b.id] ?? 0;
                          if (aRating != bRating) return bRating.compareTo(aRating);

                          // 4. Fallback: Liked status
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
        floatingActionButton: _isSelectionMode || !authVM.permissions.canAddProjects
            ? null
            : Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: FloatingActionButton(
                  heroTag: 'project_list_fab',
                  onPressed: () => context.push('/add-project'),
                  backgroundColor: const Color(0xFFFDE047),
                  child: const Icon(Icons.add, color: Colors.black87),
                ),
              ),
      ),
    );
  }

  // 🚀 NAYA: Helper function to format price
  String _formatPrice(String? priceStr) {
    if (priceStr == null || priceStr.trim().isEmpty) return 'On Request';
    
    // Check if it's a range (e.g. 400000 - 4500000)
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
    // Remove ₹ if present
    valStr = valStr.replaceAll('₹', '').trim();
    
    double? val = double.tryParse(valStr);
    if (val == null) return valStr; // return original if parsing fails

    if (val >= 10000000) {
      String res = (val / 10000000).toStringAsFixed(2);
      if (res.endsWith('.00')) res = res.substring(0, res.length - 3);
      else if (res.endsWith('0')) res = res.substring(0, res.length - 1);
      return '$res Cr';
    } else if (val >= 100000) {
      String res = (val / 100000).toStringAsFixed(2);
      if (res.endsWith('.00')) res = res.substring(0, res.length - 3);
      else if (res.endsWith('0')) res = res.substring(0, res.length - 1);
      return '$res L';
    } else if (val >= 1000) {
      String res = (val / 1000).toStringAsFixed(2);
      if (res.endsWith('.00')) res = res.substring(0, res.length - 3);
      else if (res.endsWith('0')) res = res.substring(0, res.length - 1);
      return '$res K';
    } else {
      // Remove trailing .0
      String res = val.toString();
      if (res.endsWith('.0')) res = res.substring(0, res.length - 2);
      return res;
    }
  }

  Widget _buildProjectCard(ProjectModel project) {
    final projectVM = Provider.of<ProjectViewModel>(context, listen: false);
    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    final bool isAdmin = authVM.appRole == AppRole.admin || authVM.appRole == AppRole.superAdmin;
    final bool showStatusControls = isAdmin && !project.isApproved;
    final details = project.propertyDetails;
    List<String> imageUrls = (details['images'] is Iterable) ? List<String>.from(details['images']) : [];
    String getDisplayLocation() {
      final loc = (details['googleLocation'] ?? details['areaName'] ?? details['location'] ?? details['address'] ??
                   project.rawData['googleLocation'] ?? project.rawData['areaName'] ?? project.rawData['location'] ?? project.rawData['address'] ?? '')
                  .toString().trim();
      return loc.isNotEmpty && loc != 'null' ? loc : 'Location N/A';
    }
    final location = getDisplayLocation();
    
    String rawPrice = details['startingPrice']?.toString() ?? '';
    if (rawPrice.isEmpty) {
      if (project.propertyType == 'Land') {
        if (details['minCostLand'] != null) {
          rawPrice = '${details['minCostLand']}${details['maxCostLand'] != null ? ' - ${details['maxCostLand']}' : ''}';
        }
      } else {
        if (details['minCost'] != null) {
          rawPrice = '${details['minCost']}${details['maxCost'] != null ? ' - ${details['maxCost']}' : ''}';
        }
      }
    }
    
    String formattedPrice = _formatPrice(rawPrice);

    final condition = details['condition']?.toString() ?? 'New';
    bool isLiked = _likedProjects[project.id] ?? false;
    int currentRating = _projectRatings[project.id] ?? 0;
    final String currentApproval = (project.rawData['approvalStatus']?.toString() ?? (project.isApproved ? 'Approved' : 'Pending')).trim();

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
            else context.push('/project-detail/${project.id}', extra: project);
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
                        border: _selectedProjectIds.contains(project.id) ? Border.all(color: _primaryDark, width: 3) : null,
                        image: imageUrls.isNotEmpty ? DecorationImage(image: NetworkImage(imageUrls.first), fit: BoxFit.cover) : null,
                      ),
                      child: imageUrls.isEmpty ? Center(child: Icon(typeIcon, color: Colors.grey.shade400, size: 40)) : null,
                    ),
                    if (_selectedProjectIds.contains(project.id))
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: _primaryDark, shape: BoxShape.circle),
                          child: const Icon(Icons.check, color: Colors.white, size: 16),
                        ),
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
                            child: Text(formattedPrice == 'On Request' ? formattedPrice : '₹ $formattedPrice', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black87)),
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

                      if (showStatusControls)
                        Row(
                          children: [
                            _statusActionButton(
                              label: 'Approved',
                              color: Colors.green.shade700,
                              isCurrentStatus: project.isApproved || currentApproval.toLowerCase() == 'approved',
                              onTap: () => _updateStatus(context, projectVM, authVM, project.id, 'Approved'),
                            ),
                            const SizedBox(width: 4),
                            _statusActionButton(
                              label: 'Reject',
                              color: Colors.red.shade700,
                              isCurrentStatus: currentApproval.toLowerCase() == 'reject' || currentApproval.toLowerCase() == 'rejected',
                              onTap: () => _updateStatus(context, projectVM, authVM, project.id, 'Reject'),
                            ),
                            const SizedBox(width: 4),
                            _statusActionButton(
                              label: 'Process',
                              color: Colors.blue.shade700,
                              isCurrentStatus: currentApproval.toLowerCase() == 'process',
                              onTap: () => _updateStatus(context, projectVM, authVM, project.id, 'Process'),
                            ),
                            const SizedBox(width: 4),
                            _statusActionButton(
                              label: 'Hold',
                              color: Colors.amber.shade800,
                              isCurrentStatus: currentApproval.toLowerCase() == 'hold',
                              onTap: () => _updateStatus(context, projectVM, authVM, project.id, 'Hold'),
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            _actionButton('Get Quote', () => _handleGetQuote(context, project)),
                            const SizedBox(width: 10),
                            _actionButton('Get Brochure', () => _handleGetBrochure(context, project)),
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

  Widget _statusActionButton({
    required String label,
    required Color color,
    required bool isCurrentStatus,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: SizedBox(
        height: 28,
        child: isCurrentStatus
            ? ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  elevation: 0,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800),
                ),
              )
            : OutlinedButton(
                onPressed: onTap,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: color, width: 1.2),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w800),
                ),
              ),
      ),
    );
  }

  Future<void> _updateStatus(
    BuildContext context,
    ProjectViewModel projectVM,
    AuthViewModel authVM,
    String projectId,
    String status,
  ) async {
    try {
      await projectVM.updateProjectApprovalStatus(
        projectId,
        status,
        actorMetadata: authVM.actorMetadata,
      );
      if (!context.mounted) return;
      final String msg = status == 'Approved'
          ? 'Project Approved! Moved to All Projects.'
          : 'Project marked as $status (Pending).';
      final Color color = status == 'Approved'
          ? Colors.green.shade700
          : (status == 'Reject' ? Colors.red.shade700 : Colors.amber.shade800);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: color,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _actionButton(String label, VoidCallback onTap) {
    return Expanded(
      child: SizedBox(
        height: 32,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFE5B800), width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 2),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: const TextStyle(color: Color(0xFFE5B800), fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return SizedBox(
      width: 32,
      height: 32,
      child: Tooltip(
        message: tooltip,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: color, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: EdgeInsets.zero,
          ),
          child: Icon(icon, color: color, size: 16),
        ),
      ),
    );
  }

  void _handleShareProject(BuildContext context, ProjectModel project) {
    final details = project.propertyDetails;
    final String loc = (details['googleLocation'] ?? details['areaName'] ?? details['location'] ?? details['address'] ?? project.rawData['googleLocation'] ?? '').toString().trim();
    final String location = loc.isNotEmpty && loc != 'null' ? loc : 'Location N/A';
    
    String rawPrice = details['startingPrice']?.toString() ?? '';
    if (rawPrice.isEmpty) {
      if (project.propertyType == 'Land') {
        if (details['minCostLand'] != null) rawPrice = '${details['minCostLand']}${details['maxCostLand'] != null ? ' - ${details['maxCostLand']}' : ''}';
      } else {
        if (details['minCost'] != null) rawPrice = '${details['minCost']}${details['maxCost'] != null ? ' - ${details['maxCost']}' : ''}';
      }
    }
    final String formattedPrice = _formatPrice(rawPrice);
    final String priceText = formattedPrice == 'On Request' ? formattedPrice : '₹ $formattedPrice';

    final String baseUrl = Uri.base.origin;
    final String encodedName = Uri.encodeComponent(project.projectName);
    final String shareLink = "$baseUrl/#/share/project/$encodedName";

    // 🚀 NAYA: Rich Share Message with Property+ at top, Building Name, Location, Price
    final String message = "Property+\n\n"
        "🏢 Building: ${project.projectName}\n"
        "📍 Location: $location\n"
        "💰 Starting Price: $priceText\n\n"
        "🔗 View Property Details & Photos:\n$shareLink";

    List<String> imageUrls = (details['images'] is Iterable) ? List<String>.from(details['images']) : [];
    final String? coverImage = imageUrls.isNotEmpty ? imageUrls.first : null;

    // Dynamically update OpenGraph Meta Tags on Web for chat card previews
    MetaTagHelper.updatePropertyMetaTags(
      title: '${project.projectName} - $location',
      description: 'Location: $location | Price: $priceText',
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

    // Triggers OS native app share picker (WhatsApp, Messages, Instagram, Mail, etc.)
    Share.share(message, subject: 'Property+ | ${project.projectName}');
  }

  Future<void> _handleGetBrochure(BuildContext context, ProjectModel project) async {
    final details = project.propertyDetails;
    final String? brochureUrl = details['brochurePdf']?.toString() ?? details['brochure']?.toString();
    if (brochureUrl != null && brochureUrl.trim().isNotEmpty && brochureUrl.startsWith('http')) {
      final Uri url = Uri.parse(brochureUrl.trim());
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
        return;
      }
    }
    if (context.mounted) {
      context.push('/project-detail/${project.id}', extra: project);
    }
  }

  void _handleGetQuote(BuildContext context, ProjectModel project) {
    context.push('/project-detail/${project.id}', extra: project);
  }

  bool _matchesSelectedCondition(ProjectModel project) {
    if (_selectedConditionFilter == null || _selectedConditionFilter!.isEmpty) return true;
    final condition = project.propertyDetails['condition']?.toString().trim().toLowerCase() ?? 'new';
    return condition == _selectedConditionFilter!.trim().toLowerCase();
  }
}