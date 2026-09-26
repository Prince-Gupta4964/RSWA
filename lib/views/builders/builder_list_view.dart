import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/builder_viewmodel.dart';
import '../../viewmodels/project_viewmodel.dart';
import '../../models/cp_model.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/app_drawer.dart';

class BuilderListView extends StatelessWidget {
  const BuilderListView({super.key});

  @override
  Widget build(BuildContext context) {
    final authVM = Provider.of<AuthViewModel>(context);
    final builderVM = Provider.of<BuilderViewModel>(context);
    final projectVM = Provider.of<ProjectViewModel>(context);

    if (!authVM.canManageUsers) {
      return const Scaffold(
        body: Center(child: Text("Access Denied")),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        StatefulNavigationShell.of(context).goBranch(0);
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Builders', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          elevation: 0,
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.black),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
        ),
      drawer: const AppDrawer(),
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
                  onTap: () {
                    final cpModel = CPModel.fromMap(builder.rawData, builder.id);
                    context.push('/cp-detail/${builder.id}', extra: cpModel);
                  },
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFFFF1EA),
                    child: Text(builder.name.isEmpty ? 'B' : builder.name[0].toUpperCase(), style: const TextStyle(color: Color(0xFFFF6B22))),
                  ),
                  title: Text(builder.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(builder.companyNames.isEmpty ? 'No Company' : builder.companyNames.join(', ')),
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
        onPressed: () => context.push('/add-cp'),
        backgroundColor: const Color(0xFFFBE64E),
        child: const Icon(Icons.add, color: Color(0xFF6B5800)),
      ),
    ));
  }
}
