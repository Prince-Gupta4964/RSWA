# Code Changes Reference

## File 1: `lib/viewmodels/project_viewmodel.dart`

**Added Methods**:
```dart
// --- DELETE PROJECT FUNCTION ---
Future<void> deleteProject(String projectId) async {
  try {
    // Delete all inventory items in subcollection
    final inventoryDocs = await _db.collection('projects').doc(projectId).collection('inventory').get();
    for (var doc in inventoryDocs.docs) {
      await doc.reference.delete();
    }
    // Delete the project
    await _db.collection('projects').doc(projectId).delete();
  } catch (e) {
    print("Error deleting project: $e");
    rethrow;
  }
}

// --- DELETE MULTIPLE PROJECTS ---
Future<void> deleteMultipleProjects(List<String> projectIds) async {
  try {
    for (String projectId in projectIds) {
      await deleteProject(projectId);
    }
  } catch (e) {
    print("Error deleting multiple projects: $e");
    rethrow;
  }
}
```

---

## File 2: `lib/views/projects/project_detail_view.dart`

**Updated AppBar** (Added Edit Icon):
```dart
appBar: AppBar(
  backgroundColor: Colors.white, elevation: 0,
  leading: IconButton(...),
  title: Text(...),
  centerTitle: true,
  actions: [
    IconButton(
      icon: const Icon(Icons.edit_outlined, color: Color(0xFFFF6B22), size: 22),
      onPressed: () => context.push('/add-project', extra: widget.project),
      tooltip: 'Edit Project',
    ),
  ],
),
```

---

## File 3: `lib/views/projects/project_list_view.dart`

**State Variables Added**:
```dart
// --- MULTI-SELECT STATE ---
bool _isMultiSelectMode = false;
final Set<String> _selectedProjectIds = {};
```

**Delete Confirmation Dialog**:
```dart
Future<void> _showDeleteConfirmation(BuildContext context, int count) async {
  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Projects'),
      content: Text('Are you sure you want to delete $count project(s)?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            // Delete logic here...
          },
          child: const Text('Delete', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
}
```

**Updated AppBar** (With multi-select controls):
- Shows "X Selected" and close button when in multi-select mode
- Shows "Select All" (✓) and Delete (🗑️) icons
- Switches between search and multi-select UI seamlessly

**List Item Changes**:
- Long press → Enables multi-select mode and selects item
- Tap while in multi-select → Toggles selection
- Shows checkmark circle for selected items
- Highlights selected items with orange background

---

## File 4: `lib/views/projects/add_project_view.dart`

**Updated Constructor**:
```dart
class AddProjectView extends StatefulWidget {
  final ProjectModel? project; // For editing existing project
  const AddProjectView({Key? key, this.project}) : super(key: key);
}
```

**Added Pre-population Method**:
```dart
void _prePopulateEditData() {
  if (widget.project != null) {
    final project = widget.project!;
    final details = project.propertyDetails;
    
    // Fill all form fields with existing data
    _nameCtrl.text = project.projectName;
    _locationCtrl.text = details['location']?.toString() ?? '';
    // ... (more field assignments)
  }
}
```

**Updated AppBar Title**:
```dart
title: Text(
  widget.project != null ? 'Edit Property' : 'Add Property',
  style: const TextStyle(...)
),
```

**Updated Save Logic**:
```dart
await Provider.of<ProjectViewModel>(context, listen: false).addOrUpdateProject(
  id: widget.project?.id, // Pass project ID if editing
  // ... other parameters
);

String message = widget.project != null 
  ? 'Property Updated Successfully!' 
  : 'Property Added Successfully!';
```

---

## File 5: `lib/routes/app_router.dart`

**Updated Route**:
```dart
GoRoute(
  path: '/add-project',
  builder: (context, state) {
    final project = state.extra as ProjectModel?;
    return AddProjectView(project: project);
  },
),
```

---

## Summary of Key Features

| Feature | Implementation | Location |
|---------|-----------------|----------|
| Edit Icon | AppBar action button | project_detail_view.dart |
| Form Pre-fill | _prePopulateEditData() | add_project_view.dart |
| Long Press Select | onLongPress callback | project_list_view.dart |
| Multi-select UI | _isMultiSelectMode state | project_list_view.dart |
| Select All | Toggle all filtered projects | project_list_view.dart |
| Delete Batch | deleteMultipleProjects() | project_viewmodel.dart |
| Confirmation | AlertDialog | project_list_view.dart |
| Routing | Extra parameter handling | app_router.dart |

---

## User Interactions

### Editing:
```
Project Detail View → Click Edit Icon → Add Project View (Pre-filled) → Update → Success
```

### Deleting:
```
Projects List → Long Press Project → Multi-select Mode → Select Projects → 
Click Delete Icon → Confirm → Projects Deleted → Success Notification
```

### Select All:
```
Multi-select Mode → Click Check Icon → All Projects Selected → 
Click Delete → Confirm → All Deleted
```

