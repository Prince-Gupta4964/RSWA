import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/builder_viewmodel.dart';
import '../../viewmodels/project_viewmodel.dart';
import '../../widgets/app_bottom_nav.dart';

class BuilderListView extends StatelessWidget {
  const BuilderListView({super.key});

  @override
  Widget build(BuildContext context) {
    final builderVM = Provider.of<BuilderViewModel>(context);
    final projectVM = Provider.of<ProjectViewModel>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Builders', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      body: builderVM.isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B22)))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: builderVM.builders.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final builder = builderVM.builders[index];
                final projectCount = projectVM.projects.where((p) => p.builderIds.contains(builder.id)).length;

                return ListTile(
                  onTap: () => context.push('/builder-detail', extra: builder),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFFFF1EA),
                    child: Text(builder.name.isEmpty ? 'B' : builder.name[0].toUpperCase(), style: const TextStyle(color: Color(0xFFFF6B22))),
                  ),
                  title: Text(builder.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(builder.companyName),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('$projectCount Projects', style: const TextStyle(fontSize: 10)),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/add-builder'),
        backgroundColor: const Color(0xFFFF6B22),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: const AppBottomNav(
        currentTab: 'builders',
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
}
