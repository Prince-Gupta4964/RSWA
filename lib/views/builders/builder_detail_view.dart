import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/builder_model.dart';
import '../../viewmodels/project_viewmodel.dart';
import '../../viewmodels/builder_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';

class BuilderDetailView extends StatelessWidget {
  final BuilderModel builder;
  const BuilderDetailView({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    final projectVM = Provider.of<ProjectViewModel>(context);
    final linkedProjects = projectVM.projects.where((p) => p.builderIds.contains(builder.id)).toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go('/builders');
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text(builder.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => context.go('/builders')),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Color(0xFFFF6B22)),
              onPressed: () => context.push('/add-builder', extra: builder),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
                ),
                child: Column(
                  children: [
                    _infoSection('Builder Name', builder.name),
                    const Divider(height: 24),
                    _infoSection('Company', builder.companyName),
                    const Divider(height: 24),
                    _infoSection('Contact', builder.contact),
                    const Divider(height: 24),
                    _infoSection('Email', builder.email),
                    const Divider(height: 24),
                    _infoSection('Address', builder.address),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Associated Projects', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  ElevatedButton.icon(
                    onPressed: () => _showLinkProjectDialog(context, builder, projectVM),
                    icon: const Icon(Icons.add_link, size: 18, color: Colors.white),
                    label: const Text('Link', style: TextStyle(color: Colors.white, fontSize: 12)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B22), elevation: 0),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (linkedProjects.isEmpty)
                const Text('No projects linked to this builder.', style: TextStyle(color: Colors.grey))
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: linkedProjects.length,
                  itemBuilder: (context, index) {
                    final project = linkedProjects[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFFFF1EA),
                          child: Icon(Icons.business_rounded, color: Color(0xFFFF6B22), size: 18),
                        ),
                        title: Text(project.projectName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        subtitle: Text(project.propertyType, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                        onTap: () => context.push('/project-detail', extra: project),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoSection(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value.isEmpty ? 'N/A' : value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _showLinkProjectDialog(BuildContext context, BuilderModel builder, ProjectViewModel projectVM) {
    final availableProjects = projectVM.projects.where((p) => !p.builderIds.contains(builder.id)).toList();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Link Project'),
          content: availableProjects.isEmpty
              ? const Text('All projects are already linked or none found.')
              : SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: availableProjects.length,
                    itemBuilder: (context, index) {
                      final project = availableProjects[index];
                      return ListTile(
                        title: Text(project.projectName),
                        onTap: () async {
                          final builderVM = Provider.of<BuilderViewModel>(context, listen: false);
                          final authVM = Provider.of<AuthViewModel>(context, listen: false);
                          
                          await builderVM.linkProject(builder.id, project.id);
                          // Also update project side
                          await projectVM.addOrUpdateProject(
                            id: project.id,
                            projectName: project.projectName,
                            reraId: project.reraId,
                            legality: project.legality,
                            propertyType: project.propertyType,
                            contactPerson: project.contactPerson,
                            contactNumber: project.contactNumber,
                            propertyDetails: project.propertyDetails,
                            builderIds: {...project.builderIds, builder.id}.toList(),
                            actorUid: authVM.userUid,
                            actorEmail: authVM.userEmail,
                            actorName: authVM.userName,
                            actorRole: authVM.roleLabel,
                          );
                          if (context.mounted) Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
        );
      },
    );
  }
}
