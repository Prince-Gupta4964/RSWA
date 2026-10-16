import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../../../services/home_screen_shortcut.dart';
import '../../models/task.dart';
import '../../services/task_share_print_service.dart';
import '../../viewmodels/map_screen_viewmodel.dart';
import '../dialogs/task_options_dialog.dart';
import '../dialogs/task_zoom_dialog.dart';

class MapScreenToolbarMenu {
  static Future<void> show({
    required BuildContext context,
    required MapScreenViewModel viewModel,
    required TabController tabController,
    required String screenTitle,
    required List<Task> currentTabTasks,
    required void Function(String message) onShowMessage,
  }) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 168),
          child: ListView(
            children: [
              ListTile(
                leading: const Icon(Icons.sort),
                title: const Text('Sort by'),
                subtitle: Text(viewModel.sortBy),
                onTap: () => Navigator.pop(ctx, 'sort'),
              ),
              ListTile(
                leading: const Icon(Icons.group_work_outlined),
                title: const Text('Group by'),
                subtitle: Text(viewModel.groupBy),
                onTap: () => Navigator.pop(ctx, 'group'),
              ),
              ListTile(
                leading: const Icon(Icons.view_quilt_outlined),
                title: const Text('View type'),
                subtitle: Text(viewModel.viewType),
                onTap: () => Navigator.pop(ctx, 'view'),
              ),
              ListTile(
                leading: const Icon(Icons.zoom_in),
                title: const Text('Adjust zoom'),
                subtitle: Text('${(viewModel.zoom * 100).round()}%'),
                onTap: () => Navigator.pop(ctx, 'zoom'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.add_to_home_screen),
                title: const Text('Add shortcut to home screen'),
                onTap: () => Navigator.pop(ctx, 'shortcut'),
              ),
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('Share list'),
                onTap: () => Navigator.pop(ctx, 'share'),
              ),
              ListTile(
                leading: const Icon(Icons.print_outlined),
                title: const Text('Print list'),
                onTap: () => Navigator.pop(ctx, 'print'),
              ),
            ],
          ),
        ),
      ),
    );

    if (!context.mounted || action == null) return;

    switch (action) {
      case 'sort':
        await chooseTaskOptionDialog(
          context: context,
          title: 'Sort by',
          options: const ['Priority', 'Title', 'Due date', 'Status'],
          selected: viewModel.sortBy,
          onSelected: viewModel.setSortBy,
        );
        break;
      case 'group':
        await chooseTaskOptionDialog(
          context: context,
          title: 'Group by',
          options: const ['Assignee', 'Priority', 'Work type', 'Status'],
          selected: viewModel.groupBy,
          onSelected: (value) {
            viewModel.setGroupBy(value);
            tabController.animateTo(6);
          },
        );
        break;
      case 'view':
        await chooseTaskOptionDialog(
          context: context,
          title: 'View type',
          options: const ['Grid', 'List', 'Detailed list', 'Calendar'],
          selected: viewModel.viewType,
          onSelected: viewModel.setViewType,
        );
        break;
      case 'zoom':
        await showTaskZoomDialog(
          context,
          currentZoom: viewModel.zoom,
          onZoomChanged: viewModel.setZoom,
        );
        break;
      case 'shortcut':
        final added = await installHomeScreenShortcut();
        if (context.mounted) {
          onShowMessage(
            added
                ? 'Home screen shortcut added.'
                : kIsWeb
                ? 'Use the browser menu and choose "Add to Home screen" or "Install app".'
                : 'This platform does not allow the app to add a home screen shortcut automatically.',
          );
        }
        break;
      case 'share':
        final service = TaskSharePrintService();
        await service.shareTasks(screenTitle, currentTabTasks);
        break;
      case 'print':
        final service = TaskSharePrintService();
        await service.printTasks(screenTitle, currentTabTasks);
        break;
    }
  }
}
