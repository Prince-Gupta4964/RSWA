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
import 'whatsapp_status_viewer.dart';

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
  String? _selectedSubTypeFilter;
  String? _selectedConfigurationFilter;
  String _searchQuery = '';
  String? _selectedCity;
  bool _isSearching = false; // 🚀 NAYA
  int? _lastSearchTriggerCount; // 🚀 NAYA
  int? _lastProjectFilterTriggerCount; // 🚀 NAYA
  final FocusNode _searchFocusNode = FocusNode(); // 🚀 NAYA

  // --- Expanded Search Popup State ---
  String _searchCategory = 'All';
  final List<Map<String, dynamic>> _categories = [
    {'label': 'All', 'icon': Icons.grid_view_rounded, 'value': 'All'},
    {'label': 'Flats', 'icon': Icons.apartment_rounded, 'value': 'Apartment'},
    {'label': 'Shops', 'icon': Icons.storefront_outlined, 'value': 'Shop'},
    {'label': 'Bungalow', 'icon': Icons.gite_outlined, 'value': 'Bungalow'},
    {'label': 'Land', 'icon': Icons.landscape_outlined, 'value': 'Land'},
  ];
  bool _isDetectingLocation = false;

  final Map<String, List<String>> _activeFilters = {};

  // --- THEME COLORS ---
  final Color _primaryLight = Colors.yellow.shade300;
  final Color _primaryMid = Colors.yellow.shade400;
  final Color _primaryDark = Colors.amber.shade800;

  bool get _isSelectionMode => _selectedProjectIds.isNotEmpty;

  List<String> _getCategoryTabs(AuthViewModel authVM) {
    if (authVM.appRole == AppRole.viewer) {
      return ['All Projects', 'Hot Projects', 'Fav Projects'];
    }
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
    _tabController.addListener(_onTabChanged);

    // 🚀 NAYA: Auto-close search when focus is lost
    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus && _isSearching && _searchQuery.isEmpty) {
        setState(() {
          _isSearching = false;
        });
      }
    });
  }

  bool get _hasActiveFilters =>
      _searchCategory != 'All' ||
      _searchQuery.isNotEmpty ||
      _selectedCity != null ||
      _selectedConditionFilter != null ||
      _selectedTypeFilter != null ||
      _selectedSubTypeFilter != null ||
      _selectedConfigurationFilter != null;

  void _clearAllFilters() {
    setState(() {
      _searchCategory = 'All';
      _selectedConditionFilter = null;
      _selectedTypeFilter = null;
      _selectedSubTypeFilter = null;
      _selectedConfigurationFilter = null;
      _searchQuery = '';
      _selectedCity = null;
    });
  }

  void _onTabChanged() {
    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    final currentTabs = _getCategoryTabs(authVM);
    if (_tabController.index < currentTabs.length) {
      if (_selectedTab != currentTabs[_tabController.index]) {
        setState(() {
          _selectedTab = currentTabs[_tabController.index];
          _selectedProjectIds.clear();
          // Auto-clear all filters when tab changes
          _searchCategory = 'All';
          _selectedConditionFilter = null;
          _selectedTypeFilter = null;
          _selectedSubTypeFilter = null;
          _selectedConfigurationFilter = null;
          _searchQuery = '';
          _selectedCity = null;
        });
      }
    }
  }

  void _syncTabController(List<String> tabs) {
    if (_tabController.length != tabs.length) {
      final oldIndex = _tabController.index;
      _tabController.dispose();
      final newIndex = oldIndex < tabs.length ? oldIndex : 0;
      _tabController = TabController(length: tabs.length, vsync: this, initialIndex: newIndex);
      _tabController.addListener(_onTabChanged);
    }
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
    String tempCategory = _searchCategory;
    String? tempType = _selectedTypeFilter;
    String? tempSubType = _selectedSubTypeFilter;
    String? tempConfig = _selectedConfigurationFilter;
    String? tempCity = _selectedCity;
    String? tempCondition = _selectedConditionFilter;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            List<String> subTypes = [];
            if (tempType == 'Land') {
              subTypes = ['NA', 'Non - NA'];
            } else if (tempType != null) {
              subTypes = ['New', 'UC', 'Resale', 'Rent', 'RTM'];
            }

            bool showConfig = tempType != null && tempType != 'Land' && tempType != 'Shop';
            List<String> configs = ['1 BHK', '2 BHK', '3 BHK', '4 BHK', 'Penthouse', 'Studio'];

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
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                    ),
                    const SizedBox(height: 24),

                    // Property Type
                    const Text('Property Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ['Flat', 'Bungalow', 'Shop', 'Land'].map((type) {
                          bool isSelected = tempType == type;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: _buildPopupChip(type, isSelected, () => setModalState(() {
                              tempType = isSelected ? null : type;
                              tempSubType = null;
                              tempConfig = null;
                            })),
                          );
                        }).toList(),
                      ),
                    ),

                    // Property Sub Type (Cascading)
                    if (subTypes.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Text('Property Sub Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: subTypes.map((sub) {
                            bool isSelected = tempSubType == sub;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: _buildPopupChip(sub, isSelected, () => setModalState(() => tempSubType = isSelected ? null : sub)),
                            );
                          }).toList(),
                        ),
                      ),
                    ],

                    // Configuration (Cascading)
                    if (showConfig) ...[
                      const SizedBox(height: 20),
                      const Text('Configuration (BHK)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: configs.map((cfg) {
                            bool isSelected = tempConfig == cfg;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: _buildPopupChip(cfg, isSelected, () => setModalState(() => tempConfig = isSelected ? null : cfg)),
                            );
                          }).toList(),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),
                    const Text('Location / City', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    Autocomplete<String>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        final projectVM = Provider.of<ProjectViewModel>(context, listen: false);
                        final Set<String> allCities = {};
                        for (var p in projectVM.projects) {
                          final loc = p.displayLocation;
                          if (loc != 'Location N/A') {
                            final city = loc.split(',').last.trim();
                            if (city.isNotEmpty) allCities.add(city);
                          }
                        }
                        if (textEditingValue.text.isEmpty) {
                          return allCities.toList();
                        }
                        return allCities.where((city) => city.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                      },
                      onSelected: (String selection) {
                        setModalState(() => tempCity = selection);
                      },
                      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                        if (tempCity != null && controller.text.isEmpty) {
                          controller.text = tempCity!;
                        }
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            hintText: 'Search city or location...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: tempCity != null
                                ? IconButton(
                                    icon: const Icon(Icons.close, size: 16),
                                    onPressed: () {
                                      controller.clear();
                                      setModalState(() => tempCity = null);
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          onChanged: (val) {
                            if (val.trim().isEmpty) {
                              setModalState(() => tempCity = null);
                            }
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    (() {
                      final projectVM = Provider.of<ProjectViewModel>(context, listen: false);
                      final Map<String, int> cityCounts = {};
                      final Map<String, String?> cityImages = {};

                      for (var p in projectVM.projects) {
                        final loc = p.displayLocation;
                        if (loc != 'Location N/A') {
                          final city = loc.split(',').last.trim();
                          if (city.isNotEmpty) {
                            cityCounts[city] = (cityCounts[city] ?? 0) + 1;
                            if (!cityImages.containsKey(city)) {
                              final details = p.propertyDetails;
                              final rawImgs = details['images'] is Iterable ? List<String>.from(details['images']) : [];
                              final cover = p.coverImage ?? details['coverImage']?.toString();
                              final img = (cover != null && cover.isNotEmpty) ? cover : (rawImgs.isNotEmpty ? rawImgs.first : null);
                              cityImages[city] = img;
                            }
                          }
                        }
                      }
                      final sortedCities = cityCounts.keys.toList()
                        ..sort((a, b) => cityCounts[b]!.compareTo(cityCounts[a]!));

                      return SizedBox(
                        height: 84,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 12.0),
                              child: _buildCityCard(
                                label: 'All Cities',
                                image: null,
                                icon: Icons.grid_view_rounded,
                                isSelected: tempCity == null,
                                onTap: () => setModalState(() => tempCity = null),
                              ),
                            ),
                            ...sortedCities.map((city) {
                              bool isSelected = tempCity == city;
                              int count = cityCounts[city] ?? 0;
                              String? img = cityImages[city];
                              return Padding(
                                padding: const EdgeInsets.only(right: 12.0),
                                child: _buildCityCard(
                                  label: '$city ($count)',
                                  image: img,
                                  icon: Icons.location_city_rounded,
                                  isSelected: isSelected,
                                  onTap: () => setModalState(() => tempCity = city),
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    })(),
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
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _searchCategory = tempCategory;
                            _selectedTypeFilter = tempType;
                            _selectedSubTypeFilter = tempSubType;
                            _selectedConfigurationFilter = tempConfig;
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

  Widget _buildCityCard({
    required String label,
    String? image,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? _primaryDark : Colors.grey.shade300,
                width: isSelected ? 2.5 : 1.5,
              ),
              image: image != null && image.isNotEmpty && image.startsWith('http')
                  ? DecorationImage(image: NetworkImage(image), fit: BoxFit.cover)
                  : null,
              color: Colors.grey.shade100,
            ),
            child: image == null || !image.startsWith('http')
                ? Icon(icon, color: isSelected ? _primaryDark : Colors.grey.shade600, size: 22)
                : null,
          ),
          const SizedBox(height: 5),
          SizedBox(
            width: 70,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? _primaryDark : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _matchesSearchCategory(String type) {
    if (_searchCategory == 'All' || _searchCategory.isEmpty) return true;
    final t = type.toLowerCase();
    final cat = _searchCategory.toLowerCase();
    if (t == 'project') return true;
    if (cat == 'apartment' || cat == 'flat') {
      return t == 'flat' || t == 'apartment' || t == 'residential' || t == 'flats';
    } else if (cat == 'shop') {
      return t == 'shop' || t == 'commercial' || t == 'office' || t == 'showroom' || t == 'shops';
    } else if (cat == 'bungalow') {
      return t == 'bungalow' || t == 'villa';
    } else if (cat == 'land' || cat == 'plot') {
      return t == 'land' || t == 'plot';
    }
    return t.contains(cat);
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

    if (_lastProjectFilterTriggerCount == null) {
      _lastProjectFilterTriggerCount = configVM.projectFilterTriggerCount;
    } else if (configVM.projectFilterTriggerCount > _lastProjectFilterTriggerCount!) {
      _lastProjectFilterTriggerCount = configVM.projectFilterTriggerCount;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showSearchPopup();
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

    if (_searchQuery.isNotEmpty) {
      activeChips.insert(
        0,
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: Chip(
            label: Text(
              'Search: $_searchQuery',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
            ),
            backgroundColor: Colors.blue.shade50,
            side: BorderSide(color: Colors.blue.shade800),
            deleteIconColor: Colors.blue.shade800,
            onDeleted: () => setState(() {
              _searchQuery = '';
            }),
          ),
        ),
      );
    }

    final tabs = _getCategoryTabs(authVM);
    _syncTabController(tabs);

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
                if (_hasActiveFilters)
                  IconButton(
                    icon: const Icon(Icons.filter_alt_off_rounded, color: Color(0xFFFF6B22)),
                    onPressed: _clearAllFilters,
                    tooltip: 'Clear Filters',
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
                    } else if (value == 'refresh') {
                      projectVM.fetchProjects();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Projects refreshed!'), backgroundColor: Colors.green, duration: Duration(seconds: 1)),
                      );
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
                      value: 'refresh',
                      child: Row(
                        children: [
                          Icon(Icons.refresh_rounded, color: Colors.black54),
                          SizedBox(width: 12),
                          Text('Refresh'),
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
            Expanded(
              child: projectVM.isLoading
                  ? Center(child: CircularProgressIndicator(color: _primaryDark))
                  : TabBarView(
                      controller: _tabController,
                      children: tabs.map((currentTabName) {
                        final displayProjects = projectVM.projects.where((project) {
                          if (project.isDeleted) return false;

                          final bool isApprovedBool = project.isApproved ||
                              project.rawData['approvalStatus']?.toString().toLowerCase() == 'approved' ||
                              project.rawData['isApproved'] == 'Yes' ||
                              project.rawData['isApproved'] == true ||
                              project.propertyDetails['isApproved'] == 'Yes' ||
                              project.propertyDetails['isApproved'] == true;

                          final String myUid = authVM.userUid.trim().toLowerCase();
                          final String myEmail = authVM.userEmail.trim().toLowerCase();
                          final String myName = authVM.userName.trim().toLowerCase();

                          final String cUid = (project.createdByUid ?? '').trim().toLowerCase();
                          final cb = project.rawData['createdBy'];
                          final String cbUid = (cb is Map ? cb['uid'] ?? '' : '').toString().trim().toLowerCase();
                          final String cbEmail = (cb is Map ? cb['email'] ?? '' : '').toString().trim().toLowerCase();
                          final String cbName = (cb is Map ? cb['name'] ?? '' : '').toString().trim().toLowerCase();

                          final ub = project.rawData['updatedBy'];
                          final String ubUid = (ub is Map ? ub['uid'] ?? '' : '').toString().trim().toLowerCase();

                          bool isMine = (cUid.isNotEmpty && (cUid == myUid || myUid.contains(cUid))) ||
                              (cbUid.isNotEmpty && (cbUid == myUid || myUid.contains(cbUid))) ||
                              (cbEmail.isNotEmpty && myEmail.isNotEmpty && (cbEmail == myEmail || myEmail.contains(cbEmail))) ||
                              (cbName.isNotEmpty && myName.isNotEmpty && (cbName == myName || myName.contains(cbName))) ||
                              (ubUid.isNotEmpty && (ubUid == myUid || myUid.contains(ubUid)) && authVM.appRole == AppRole.cp);

                          final List<String> favUids = (project.rawData['favUids'] is Iterable) 
                              ? List<String>.from(project.rawData['favUids']) 
                              : ((project.propertyDetails['favUids'] is Iterable) 
                                  ? List<String>.from(project.propertyDetails['favUids']) 
                                  : []);
                          final bool isLiked = authVM.userUid.isNotEmpty && favUids.contains(authVM.userUid);

                          if (currentTabName == 'All Projects') {
                            // 🚀 NAYA: Show approved projects TO EVERYONE, plus user's OWN submitted projects (even if pending) to the user!
                            if (!isApprovedBool && !isMine) return false;
                          } else if (currentTabName == 'Pending') {
                            if (isApprovedBool) return false;
                          } else if (currentTabName == 'My Projects') {
                            if (!isMine) return false;
                          } else if (currentTabName == 'Hot Projects') {
                            int rating = _projectRatings[project.id] ?? 0;
                            if (project.priorityNumber == 999 && rating < 4 && !isLiked) return false;
                            if (!isApprovedBool) return false;
                          } else if (currentTabName == 'Fav Projects') {
                            if (!isLiked) return false;
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
                            if (_selectedSubTypeFilter != null) {
                              final sub = (project.propertyDetails['subType'] ?? project.propertyDetails['condition'] ?? project.rawData['subType'] ?? '').toString().toLowerCase();
                              if (sub != _selectedSubTypeFilter!.toLowerCase()) return false;
                            }
                            if (_selectedConfigurationFilter != null) {
                              final config = (project.propertyDetails['configuration'] ?? project.rawData['configuration'] ?? '').toString().toLowerCase();
                              if (!config.contains(_selectedConfigurationFilter!.toLowerCase())) return false;
                            }
                            if (!_matchesSelectedCondition(project)) return false;

                            if (_selectedCity != null) {
                              final projLoc = project.displayLocation.toLowerCase();
                              final targetCity = _selectedCity!.toLowerCase();
                              bool matches = projLoc.contains(targetCity);
                              final parts = targetCity.split(RegExp(r'[\s\-]'));
                              for (var part in parts) {
                                if (part.trim().length > 2 && projLoc.contains(part.trim())) {
                                  matches = true;
                                  break;
                                }
                              }
                              if (!matches) return false;
                            }
                          }

                          return true;
                        }).toList();

                        displayProjects.sort((a, b) {
                          // 1. Prioritized / Hot projects at the top (1, 2, 3... 30)
                          final pA = a.priorityNumber;
                          final pB = b.priorityNumber;
                          if (pA != pB) return pA.compareTo(pB);

                          // 2. Newest projects first (recently added)
                          final t1 = a.rawData['timestamp'];
                          final t2 = b.rawData['timestamp'];
                          if (t1 != null && t2 != null && t1 is Timestamp && t2 is Timestamp) {
                            int timeCompare = t2.compareTo(t1); // Descending (newest first)
                            if (timeCompare != 0) return timeCompare;
                          }

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
                          itemCount: displayProjects.length + 1,
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  _buildCategoryCarousel(),
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
                                ],
                              );
                            }
                            final project = displayProjects[index - 1];
                            return _buildProjectCard(project, index - 1, displayProjects);
                          },
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
        floatingActionButton: (_isSelectionMode || !authVM.canAddProjects || authVM.appRole == AppRole.viewer)
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

  Widget _buildCategoryCarousel() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _categories.map((cat) {
            final isSelected = _searchCategory == cat['value'] || (_searchCategory == 'All' && cat['value'] == 'All');
            return GestureDetector(
              onTap: () {
                setState(() {
                  _searchCategory = cat['value'];
                });
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 52,
                      width: 52,
                      decoration: BoxDecoration(
                        color: isSelected ? _primaryDark : Colors.grey.shade100,
                        shape: BoxShape.circle,
                        boxShadow: isSelected
                            ? [BoxShadow(color: _primaryDark.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 3))]
                            : null,
                        border: Border.all(
                          color: isSelected ? _primaryDark : Colors.grey.shade300,
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        cat['icon'],
                        color: isSelected ? Colors.white : Colors.black87,
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      cat['label'],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected ? _primaryDark : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _openStatusViewer(List<ProjectModel> displayProjects, int initialIndex) {
    if (initialIndex < 0 || initialIndex >= displayProjects.length) return;
    final project = displayProjects[initialIndex];
    final details = project.propertyDetails;
    final displayImage = (project.coverImage ?? details['coverImage'])?.toString().trim();
    final imageUrls = details['imageUrls'] is Iterable ? List<String>.from(details['imageUrls']) : [];
    final location = project.displayLocation;

    final List<String> allImages = [];
    if (displayImage != null) allImages.add(displayImage);
    for (var img in imageUrls) {
      if (img.isNotEmpty && !allImages.contains(img)) allImages.add(img);
    }
    final rawImgs = details['images'] is Iterable ? List<String>.from(details['images']) : [];
    for (var img in rawImgs) {
      if (img.isNotEmpty && !allImages.contains(img)) allImages.add(img);
    }
    final highImgs = details['highlightsImages'] is Iterable ? List<String>.from(details['highlightsImages']) : [];
    for (var img in highImgs) {
      if (img.isNotEmpty && !allImages.contains(img)) allImages.add(img);
    }
    final outImgs = details['outdoorsImages'] is Iterable ? List<String>.from(details['outdoorsImages']) : [];
    for (var img in outImgs) {
      if (img.isNotEmpty && !allImages.contains(img)) allImages.add(img);
    }

    if (allImages.isNotEmpty) {
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => WhatsAppStatusViewer(
            imageUrls: allImages,
            projectName: project.projectName,
            location: location,
            projectId: project.id,
            projects: displayProjects,
            initialIndex: initialIndex,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, 1.0);
            const end = Offset.zero;
            const curve = Curves.easeInOut;
            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            var offsetAnimation = animation.drive(tween);
            return SlideTransition(position: offsetAnimation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 350),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No images available for status view.')));
    }
  }

  Widget _buildProjectCard(ProjectModel project, int index, List<ProjectModel> displayProjects) {
    final projectVM = Provider.of<ProjectViewModel>(context, listen: false);
    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    final bool isAdmin = authVM.appRole == AppRole.admin || authVM.appRole == AppRole.superAdmin;
    final bool showStatusControls = isAdmin && !project.isApproved;
    final details = project.propertyDetails;
    List<String> imageUrls = (details['images'] is Iterable) ? List<String>.from(details['images']) : [];

    final String? coverImg = (project.coverImage ?? details['coverImage'])?.toString().trim();
    final String? displayImage = (coverImg != null && coverImg.isNotEmpty && coverImg.startsWith('http'))
        ? coverImg
        : (imageUrls.isNotEmpty ? imageUrls.first : null);

    final location = project.displayLocation;

    final minC = project.propertyType == 'Land' 
        ? (details['minCostLand'] ?? details['minCost']) 
        : (details['minCost'] ?? details['minCostLand']);
    final maxC = project.propertyType == 'Land' 
        ? (details['maxCostLand'] ?? details['maxCost']) 
        : (details['maxCost'] ?? details['maxCostLand']);

    String formattedPrice = 'On Request';
    if (minC != null && minC.toString().trim().isNotEmpty) {
      final String minStr = _formatSinglePrice(minC.toString().trim());
      if (maxC != null && maxC.toString().trim().isNotEmpty) {
        final String maxStr = _formatSinglePrice(maxC.toString().trim());
        if (minStr != maxStr && maxStr.isNotEmpty && maxStr != 'N/A') {
          formattedPrice = '$minStr - $maxStr';
        } else {
          formattedPrice = minStr;
        }
      } else {
        formattedPrice = minStr;
      }
    } else if (details['startingPrice'] != null && details['startingPrice'].toString().trim().isNotEmpty) {
      formattedPrice = _formatPrice(details['startingPrice'].toString());
    }

    final String subTypeTag = (details['subType'] ?? details['condition'] ?? '').toString().trim();
    final String displayTag = subTypeTag.isNotEmpty ? subTypeTag : 'New';
    
    final List<String> favUids = (project.rawData['favUids'] is Iterable) 
        ? List<String>.from(project.rawData['favUids']) 
        : ((details['favUids'] is Iterable) 
            ? List<String>.from(details['favUids']) 
            : []);
    final bool isLiked = authVM.userUid.isNotEmpty && favUids.contains(authVM.userUid);

    final String currentApproval = (project.rawData['approvalStatus']?.toString() ?? (project.isApproved ? 'Approved' : 'Pending')).trim();

    IconData typeIcon = Icons.apartment_outlined;
    if (project.propertyType == 'Plot') typeIcon = Icons.landscape_outlined;
    else if (project.propertyType == 'Bungalow') typeIcon = Icons.gite_outlined;
    else if (project.propertyType == 'Shop') typeIcon = Icons.storefront_outlined;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200, width: 0.8),
          bottom: BorderSide(color: Colors.grey.shade200, width: 0.8),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (_isSelectionMode) _toggleProjectSelection(project.id);
            else context.push('/project-detail/${project.id}', extra: project);
          },
          onLongPress: () => _toggleProjectSelection(project.id),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 115,
                  child: GestureDetector(
                    onTap: () {
                      if (_isSelectionMode) {
                        _toggleProjectSelection(project.id);
                        return;
                      }
                      _openStatusViewer(displayProjects, index);
                    },
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.zero,
                            border: _selectedProjectIds.contains(project.id) ? Border.all(color: _primaryDark, width: 3) : null,
                            image: displayImage != null ? DecorationImage(image: NetworkImage(displayImage), fit: BoxFit.cover) : null,
                          ),
                          child: displayImage == null ? Center(child: Icon(typeIcon, color: Colors.grey.shade400, size: 40)) : null,
                        ),
                        if (_selectedProjectIds.contains(project.id))
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(color: _primaryDark, shape: BoxShape.circle),
                              child: const Icon(Icons.check, color: Colors.white, size: 16),
                            ),
                          ),
                        Positioned(
                          bottom: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.play_circle_filled_rounded, color: Colors.white, size: 10),
                                const SizedBox(width: 3),
                                Text('Status', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 3, 8, 3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Line 1: Project Name + Green Tag + Fav Heart
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                project.projectName,
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.black87),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              constraints: const BoxConstraints(minWidth: 54),
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.green.shade200, width: 1.2),
                              ),
                              child: Text(
                                displayTag,
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 11, color: Colors.green.shade700, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () {
                                if (authVM.userUid.isNotEmpty) {
                                  projectVM.toggleProjectFavorite(project.id, authVM.userUid, favUids);
                                }
                              },
                              child: Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: isLiked ? Colors.red : Colors.grey.shade400, size: 22),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),

                        // Line 2: Price Only
                        Text(
                          formattedPrice == 'On Request' ? formattedPrice : '₹ $formattedPrice',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black87),
                        ),
                        const SizedBox(height: 2),

                        // Line 3: Property Type | 4.5 ⭐⭐⭐⭐⭐ (2)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(project.propertyType, style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 8),
                            Text('|', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                            const SizedBox(width: 8),
                            Text(
                              project.avgRating > 0 ? project.avgRating.toStringAsFixed(1) : '0.0',
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                            const SizedBox(width: 4),
                            Row(
                              children: List.generate(5, (starIndex) {
                                final double rating = project.avgRating;
                                final bool isFilled = starIndex < (rating > 0 ? rating : 5);
                                return Padding(
                                  padding: const EdgeInsets.only(right: 1),
                                  child: Icon(
                                    isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                                    color: Colors.amber,
                                    size: 15,
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '(${project.ratingCount})',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),

                        // Line 4: Location Pin + Text
                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFFFF6B22)),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(location, style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),

                        // Line 5: Buttons Row
                        if (showStatusControls)
                          Row(
                            children: [
                              Expanded(
                                child: _statusActionButton(
                                  label: 'Approved',
                                  color: Colors.green.shade700,
                                  isCurrentStatus: project.isApproved || currentApproval.toLowerCase() == 'approved',
                                  onTap: () => _updateStatus(context, projectVM, authVM, project.id, 'Approved'),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: _statusActionButton(
                                  label: 'Reject',
                                  color: Colors.red.shade700,
                                  isCurrentStatus: currentApproval.toLowerCase() == 'reject' || currentApproval.toLowerCase() == 'rejected',
                                  onTap: () => _updateStatus(context, projectVM, authVM, project.id, 'Reject'),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: _statusActionButton(
                                  label: 'Process',
                                  color: Colors.blue.shade700,
                                  isCurrentStatus: currentApproval.toLowerCase() == 'process',
                                  onTap: () => _updateStatus(context, projectVM, authVM, project.id, 'Process'),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: _statusActionButton(
                                  label: 'Hold',
                                  color: Colors.amber.shade800,
                                  isCurrentStatus: currentApproval.toLowerCase() == 'hold',
                                  onTap: () => _updateStatus(context, projectVM, authVM, project.id, 'Hold'),
                                ),
                              ),
                            ],
                          )
                        else
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _handleGetQuote(context, project),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: Colors.grey.shade400),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                  ),
                                  child: const Text('Get Details', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.black87)),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _handleGetBrochure(context, project),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: Colors.grey.shade400),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                  ),
                                  child: const Text('Get Brochure', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.black87)),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                height: 36,
                                width: 36,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade400),
                                ),
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.share_outlined, color: Colors.black87, size: 18),
                                  onPressed: () => _handleShareProject(context, project),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
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
    final details = project.propertyDetails;
    final String propertyName = project.projectName;
    final String companyName = (details['projectCompany'] ?? project.rawData['projectCompany'] ?? '').toString().trim();
    final String loc = (details['location'] ?? details['googleLocation'] ?? details['areaName'] ?? details['address'] ?? project.rawData['location'] ?? '').toString().trim();
    final String location = loc.isNotEmpty && loc != 'null' ? loc : 'Location N/A';

    final String message = "Property Name: $propertyName\n"
        "Company Name: ${companyName.isNotEmpty ? companyName : 'N/A'}\n"
        "Location: $location\n\n"
        "I want more details about this project";

    final String phone = '8793693314';
    final Uri whatsappUri = Uri.parse('https://wa.me/91$phone?text=${Uri.encodeComponent(message)}');
    
    launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
  }

  bool _matchesSelectedCondition(ProjectModel project) {
    if (_selectedConditionFilter == null || _selectedConditionFilter!.isEmpty) return true;
    final condition = project.propertyDetails['condition']?.toString().trim().toLowerCase() ?? 'new';
    return condition == _selectedConditionFilter!.trim().toLowerCase();
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
}
