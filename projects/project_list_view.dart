import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/project_viewmodel.dart';
import '../../models/project_model.dart';

class ProjectListView extends StatelessWidget {
  const ProjectListView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final projectVM = Provider.of<ProjectViewModel>(context);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => context.pop()),
        title: const Text('Projects Inventory', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: projectVM.isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B22)))
          : projectVM.projects.isEmpty
          ? const Center(child: Text("No projects found. Click + to add!"))
          : ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: projectVM.projects.length,
        itemBuilder: (context, index) {
          final project = projectVM.projects[index];

          IconData typeIcon = Icons.home_work_outlined;
          if (project.propertyType == 'Plot') typeIcon = Icons.landscape_outlined;
          if (project.propertyType == 'Bungalow') typeIcon = Icons.gite_outlined;

          return Card(
            color: Colors.white, elevation: 1, margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              // --- NAYA: Card pe click karte hi direct Detail View me redirect karega ---
              onTap: () {
                context.push('/project-detail', extra: project);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: ListTile(
                  leading: CircleAvatar(
                      backgroundColor: const Color(0xFFFF6B22).withOpacity(0.1),
                      child: Icon(typeIcon, color: const Color(0xFFFF6B22))
                  ),
                  title: Text(project.projectName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Type: ${project.propertyType} | RERA: ${project.reraId}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  // Right side me ek arrow icon laga diya taaki click karne ka feel aaye
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 20.0),
        child: FloatingActionButton(onPressed: () => context.push('/add-project'), backgroundColor: const Color(0xFFFF6B22), child: const Icon(Icons.add, color: Colors.white)),
      ),
      bottomNavigationBar: _buildBottomNavBar(context),
    );
  }

  Widget _buildBottomNavBar(BuildContext context) {
    return Container(
      height: 70,
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFFF6B22), width: 1), borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(icon: const Icon(Icons.home_outlined, color: Color(0xFFFF6B22), size: 30), onPressed: () => context.go('/dashboard')),
          Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(padding: const EdgeInsets.all(10), decoration: const BoxDecoration(color: Color(0xFFFF6B22), shape: BoxShape.circle), child: const Icon(Icons.location_city_outlined, color: Colors.white)), const Text('Projects', style: TextStyle(color: Color(0xFFFF6B22), fontSize: 10, fontWeight: FontWeight.bold))]),
          IconButton(icon: const Icon(Icons.person_outline, color: Color(0xFFFF6B22), size: 30), onPressed: () => context.push('/cp-list')),
          IconButton(icon: const Icon(Icons.bar_chart, color: Color(0xFFFF6B22), size: 30), onPressed: () {}),
          IconButton(icon: const Icon(Icons.outlined_flag, color: Color(0xFFFF6B22), size: 30), onPressed: () {}),
        ],
      ),
    );
  }
}