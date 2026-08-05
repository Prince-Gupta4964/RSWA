import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/project_viewmodel.dart';
import '../../models/project_model.dart';

class CitySelectionView extends StatefulWidget {
  const CitySelectionView({super.key});

  @override
  State<CitySelectionView> createState() => _CitySelectionViewState();
}

class _CitySelectionViewState extends State<CitySelectionView> {
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  // City string ko clean karne ka logic (e.g., "Bolinj, Virar West" -> "Virar")
  String _extractCity(String location) {
    if (location.isEmpty || location == 'N/A') return 'Unknown';
    List<String> parts = location.split(',');
    return parts.last.trim();
  }

  // Dynamic Image Mapper
  String _getCityImage(String city) {
    String c = city.toLowerCase();
    if (c.contains('mumbai')) return 'https://images.unsplash.com/photo-1570168007204-dfb528c6958f?auto=format&fit=crop&q=80&w=200';
    if (c.contains('virar')) return 'https://images.unsplash.com/photo-1567157577867-05ccb1388e66?auto=format&fit=crop&q=80&w=200'; // Placeholder for local feel
    if (c.contains('pune')) return 'https://images.unsplash.com/photo-1552832233-4cae815615f3?auto=format&fit=crop&q=80&w=200';
    if (c.contains('thane')) return 'https://images.unsplash.com/photo-1587222318667-31212ce2828d?auto=format&fit=crop&q=80&w=200';
    if (c.contains('delhi')) return 'https://images.unsplash.com/photo-1587474260580-58955f9e2b17?auto=format&fit=crop&q=80&w=200';
    if (c.contains('bangalore')) return 'https://images.unsplash.com/photo-1596176530529-78163a4f7af2?auto=format&fit=crop&q=80&w=200';

    // Generic Modern City Fallback
    return 'https://images.unsplash.com/photo-1477959858617-67f85cf4f1df?auto=format&fit=crop&q=80&w=200';
  }

  @override
  Widget build(BuildContext context) {
    final projectVM = Provider.of<ProjectViewModel>(context);

    // 1. Extract and Count Cities Dynamically
    Map<String, int> cityCounts = {};
    for (var p in projectVM.projects) {
      String rawLocation = p.propertyDetails['location']?.toString() ?? 'Unknown';
      String city = _extractCity(rawLocation);
      if (city != 'Unknown' && city.isNotEmpty) {
        cityCounts[city] = (cityCounts[city] ?? 0) + 1;
      }
    }

    // 2. Sort Cities by Count (Highest projects first)
    var sortedEntries = cityCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    List<String> allExtractedCities = sortedEntries.map((e) => e.key).toList();

    // 3. Apply Search Filter
    List<String> displayedCities = allExtractedCities
        .where((c) => c.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    // Top 9 cities go to "Popular", rest go to "All Cities" (only if not searching)
    List<String> popularCities = _searchQuery.isEmpty ? displayedCities.take(9).toList() : [];
    List<String> otherCities = _searchQuery.isEmpty ? displayedCities.skip(9).toList() : displayedCities;

    return Scaffold(
      // Screenshot ki tarah Red Header rakhna hai toh Colors.red use karein,
      // yahan app theme ka primary color (Orange) use kiya hai premium look ke liye.
      backgroundColor: const Color(0xFFFF6B22),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text('Which city do you plan to buy in', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: Container(
        margin: const EdgeInsets.only(top: 8),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // --- SEARCH BAR ---
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search City, Locality, Project',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFFF6B22)),
                  ),
                ),
              ),
            ),

            // --- CITY LIST ---
            Expanded(
              child: CustomScrollView(
                slivers: [
                  if (popularCities.isNotEmpty) ...[
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text('Popular Cities', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.85,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        delegate: SliverChildBuilderDelegate(
                              (context, index) {
                            String city = popularCities[index];
                            return GestureDetector(
                              onTap: () => context.pop(city), // Selected city wapas bhejega
                              child: Column(
                                children: [
                                  CircleAvatar(
                                    radius: 35,
                                    backgroundImage: NetworkImage(_getCityImage(city)),
                                    backgroundColor: Colors.grey.shade200,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(city, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
                                ],
                              ),
                            );
                          },
                          childCount: popularCities.length,
                        ),
                      ),
                    ),
                  ],

                  if (otherCities.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                        child: Text(_searchQuery.isEmpty ? 'All Cities' : 'Search Results', style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          String city = otherCities[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                            title: Text(city, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black87)),
                            onTap: () => context.pop(city),
                          );
                        },
                        childCount: otherCities.length,
                      ),
                    ),
                  ],

                  if (displayedCities.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(40.0),
                        child: Center(child: Text('No cities found.', style: TextStyle(color: Colors.grey.shade500))),
                      ),
                    )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}