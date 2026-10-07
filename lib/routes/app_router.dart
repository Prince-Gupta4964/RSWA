import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // 🚀 NAYA
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // 🚀 NAYA
import '../utils/meta_tag_helper.dart'; // 🚀 NAYA
import '../utils/role_permissions.dart'; // 🚀 NAYA
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/lead_model.dart';
import '../models/project_model.dart';
import '../models/cp_model.dart';
import '../viewmodels/lead_viewmodel.dart';
import '../viewmodels/cp_viewmodel.dart';
import '../viewmodels/project_viewmodel.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../views/auth/login_view.dart';
import '../views/auth/customer_form_view.dart';
import '../views/dashboard/dashboard_view.dart';
import '../views/admin/admin_console_view.dart';
import '../views/forms/custom_form_view.dart';
import '../views/leads/add_lead_view.dart';
import '../views/leads/lead_detail_view.dart';
import '../views/leads/today_task_form_view.dart';
import '../views/leads/task_detail_view.dart';
import '../views/leads/followup_history_view.dart';
import '../views/cp_network/add_cp_view.dart';
import '../views/cp_network/cp_list_view.dart';
import '../views/cp_network/cp_detail_view.dart';
import '../views/projects/add_project_view.dart';
import '../views/projects/project_list_view.dart';
import '../views/projects/project_detail_view.dart';
import '../views/projects/city_selection_view.dart';
import '../views/projects/recycle_bin_view.dart';
import '../views/builders/builder_list_view.dart';
import '../views/builders/add_builder_view.dart';
import '../views/builders/builder_detail_view.dart';
import '../views/profile/my_profile_view.dart';
import '../views/admin/dropdown_manager_view.dart';
import '../models/builder_model.dart';
import '../widgets/auth_guard.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_drawer.dart';
import '../features/map_screen/screens/map_screen.dart';
import '../features/map_screen/screens/task_detail_page.dart';
import '../features/map_screen/screens/assignee_tasks_view.dart';
import '../features/map_screen/models/task.dart';

class AppRouter {
  static final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) {
          final String? referralCode = state.uri.queryParameters['ref'];
          final String? mode = state.uri.queryParameters['mode'];
          return NoTransitionPage(child: LoginView(initialReferralCode: referralCode, mode: mode));
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/customer-form',
        pageBuilder: (context, state) => const NoTransitionPage(child: CustomerFormView()),
      ),

      // --- MAIN SHELL (Main Tabs with persistent Bottom Nav) ---
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShell(navigationShell: navigationShell);
        },
        branches: [
          // Branch 0: Dashboard (Leads)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: AuthGuard(
                    child: Builder(
                      builder: (context) {
                        final authVM = Provider.of<AuthViewModel>(context);
                        if (authVM.appRole == AppRole.viewer) {
                          return const ProjectListView();
                        }
                        return const DashboardView();
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Branch 1: Projects
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/projects',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: AuthGuard(child: ProjectListView())),
              ),
            ],
          ),
          // Branch 2: CP List
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/cp-list',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: AuthGuard(child: CPListView())),
              ),
            ],
          ),
          // Branch 3: Builders
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/builders',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: AuthGuard(child: BuilderListView())),
              ),
            ],
          ),
          // Branch 4: Admin Console
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin-console',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: AuthGuard(child: AdminConsoleView())),
              ),
            ],
          ),
          // Branch 5: Map
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/map',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: AuthGuard(child: MapScreen(title: 'MAP'))),
              ),
            ],
          ),
        ],
      ),

      // --- SUB SCREENS (Outside of Shell to hide Bottom Nav) ---
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/task',
        builder: (context, state) {
          final task = state.extra as Task;
          return AuthGuard(
            child: TaskDetailPage(
              task: task,
              onChanged: () {},
              onDelete: () {},
            ),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/custom-form/:formId',
        builder: (context, state) => AuthGuard(
          child: CustomFormView(formId: state.pathParameters['formId'] ?? ''),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/add-lead',
        builder: (context, state) {
          final lead = state.extra as LeadModel?;
          return AuthGuard(child: AddLeadView(lead: lead));
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/add-lead/:leadId',
        builder: (context, state) {
          final leadId = state.pathParameters['leadId'];
          LeadModel? lead = state.extra as LeadModel?;
          if (lead == null && leadId != null && leadId != 'new') {
             try {
               final leadVM = Provider.of<LeadViewModel>(context, listen: false);
               lead = leadVM.leads.firstWhere((l) => l.id == leadId);
             } catch (_) {}
          }
          return AuthGuard(child: AddLeadView(lead: lead));
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/add-task',
        builder: (context, state) {
          if (state.extra is Map<String, dynamic>) {
            final Map<String, dynamic> extra = state.extra as Map<String, dynamic>;
            final lead = extra['lead'] as LeadModel?;
            final followupData = extra['followupData'] as Map<String, dynamic>?;
            final followupId = extra['followupId'] as String?;
            return AuthGuard(child: TodayTaskFormView(lead: lead, followupData: followupData, followupId: followupId));
          }
          final lead = state.extra as LeadModel?;
          return AuthGuard(child: TodayTaskFormView(lead: lead));
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/task-detail',
        builder: (context, state) {
          final Map<String, dynamic> extra = state.extra as Map<String, dynamic>;
          final lead = extra['lead'] as LeadModel;
          final followupId = extra['followupId'] as String;
          final data = extra['data'] as Map<String, dynamic>;
          return AuthGuard(child: TaskDetailView(lead: lead, followupId: followupId, data: data));
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/followup-history',
        builder: (context, state) {
          final lead = state.extra as LeadModel;
          return AuthGuard(child: FollowUpHistoryView(lead: lead));
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/lead-detail/:leadId',
        builder: (context, state) {
          final leadId = state.pathParameters['leadId'];
          final expand = state.uri.queryParameters['expand'];
          LeadModel? lead = state.extra as LeadModel?;

          if (lead == null && leadId != null) {
            try {
              final leadVM = Provider.of<LeadViewModel>(context, listen: false);
              lead = leadVM.leads.firstWhere((l) => l.id == leadId);
            } catch (_) {}
          }

          if (lead == null) {
            final emptyLead = LeadModel(
              id: leadId ?? '0',
              name: 'No Data Found (Go Back)',
              contact: '',
              status: '',
              favUids: const [],
              rawData: {},
            );
            return AuthGuard(child: LeadDetailView(lead: emptyLead));
          }
          return AuthGuard(child: LeadDetailView(lead: lead, initiallyExpandedSection: expand));
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/add-cp',
        builder: (context, state) {
          final cp = state.extra as CPModel?;
          return AuthGuard(child: AddCPView(cp: cp));
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/cp-detail/:cpId',
        builder: (context, state) {
          final cpId = state.pathParameters['cpId'];
          CPModel? cp = state.extra as CPModel?;

          if (cp == null && cpId != null) {
            try {
              final cpVM = Provider.of<CPViewModel>(context, listen: false);
              cp = cpVM.cps.firstWhere((c) => c.id == cpId);
            } catch (_) {}
          }

          if (cp == null) {
             return const AuthGuard(child: Scaffold(body: Center(child: Text("Partner not found."))));
          }
          return AuthGuard(child: CPDetailView(cp: cp));
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/add-project',
        builder: (context, state) {
          final project = state.extra as ProjectModel?;
          return AuthGuard(child: AddProjectView(project: project));
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/project-detail/:projectId',
        builder: (context, state) {
          final projectId = state.pathParameters['projectId'];
          ProjectModel? project = state.extra as ProjectModel?;

          if (project == null && projectId != null) {
            try {
              final projectVM = Provider.of<ProjectViewModel>(context, listen: false);
              project = projectVM.projects.firstWhere((p) => p.id == projectId);
            } catch (_) {}
          }

          if (project == null) {
             return const AuthGuard(child: Scaffold(body: Center(child: Text("Project not found."))));
          }
          return AuthGuard(child: ProjectDetailView(project: project));
        },
      ),
      GoRoute(
        path: '/share/project/:projectName',
        builder: (context, state) {
          final projectName = state.pathParameters['projectName'] ?? '';
          return PublicProjectLoader(projectName: projectName);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/recycle-bin',
        builder: (context, state) => const AuthGuard(child: RecycleBinView()),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/city-select',
        builder: (context, state) =>
            const AuthGuard(child: CitySelectionView()),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/add-builder',
        builder: (context, state) {
          final cp = state.extra as CPModel?;
          return AuthGuard(child: AddCPView(cp: cp));
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/builder-detail',
        builder: (context, state) {
          final builder = state.extra as BuilderModel;
          final cpModel = CPModel.fromMap(builder.rawData, builder.id);
          return AuthGuard(child: CPDetailView(cp: cpModel));
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/dropdown-manager',
        builder: (context, state) => const AuthGuard(child: DropdownManagerView()),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/profile',
        builder: (context, state) => const AuthGuard(child: MyProfileView()),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/assignee-tasks',
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>?;
          final assigneeName = args?['assigneeName'] as String? ?? 'Tasks';
          final tasks = args?['tasks'] as List<Task>? ?? [];
          return AuthGuard(
            child: AssigneeTasksView(
              assigneeName: assigneeName,
              tasks: tasks,
            ),
          );
        },
      ),
    ],
  );
}

// 🚀 NAYA: Helper widget to load public property data by Name
class PublicProjectLoader extends StatelessWidget {
  final String projectName;
  const PublicProjectLoader({super.key, required this.projectName});

  Future<DocumentSnapshot<Map<String, dynamic>>?> _findProjectDoc(String decodedName) async {
    final sanitizeName = decodedName.trim().replaceAll('/', '-').replaceAll('\\', '-').replaceAll(RegExp(r'\s+'), ' ');
    final directDoc = await FirebaseFirestore.instance.collection('projects').doc(sanitizeName).get();
    if (directDoc.exists) return directDoc;

    final query = await FirebaseFirestore.instance
        .collection('projects')
        .where('projectName', isEqualTo: decodedName)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) return query.docs.first;

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final decodedName = Uri.decodeComponent(projectName);

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
      future: _findProjectDoc(decodedName),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Color(0xFFFF6B22))),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null || !snapshot.data!.exists) {
          return const Scaffold(
            body: Center(
              child: Text(
                "Property link expired or invalid.",
                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
              ),
            ),
          );
        }

        final doc = snapshot.data!;
        final project = ProjectModel.fromMap(doc.data()!, doc.id);

        final details = project.propertyDetails;
        final String loc = (details['googleLocation'] ?? details['areaName'] ?? details['location'] ?? details['address'] ?? project.rawData['googleLocation'] ?? '').toString().trim();
        final String location = loc.isNotEmpty && loc != 'null' ? loc : 'Location N/A';
        List<String> imageUrls = (details['images'] is Iterable) ? List<String>.from(details['images']) : [];
        final String? coverImage = imageUrls.isNotEmpty ? imageUrls.first : null;

        // Dynamically update OpenGraph Meta Tags for chat card previews
        MetaTagHelper.updatePropertyMetaTags(
          title: '${project.projectName} - $location',
          description: 'Location: $location',
          imageUrl: coverImage,
        );

        return ProjectDetailView(project: project, isPublicView: true);
      },
    );
  }
}

class MainShell extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  var _lastNotifId = '';

  @override
  void initState() {
    super.initState();
    _listenToNotifications();
  }

  void _listenToNotifications() {
    FirebaseFirestore.instance
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      final authVM = Provider.of<AuthViewModel>(context, listen: false);
      if (!authVM.allowNotifications) return;
      final myName = authVM.userName.trim().toLowerCase();
      
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>?;
          if (data == null) continue;
          final recipient = (data['recipientName'] ?? '').toString().trim().toLowerCase();
          final notifId = change.doc.id;

          if (recipient == myName && notifId != _lastNotifId) {
            _lastNotifId = notifId;
            final title = data['title']?.toString() ?? 'Notification';
            final body = data['body']?.toString() ?? '';

            // 🚀 NAYA: Trigger System Status Bar & Lock Screen Notification
            if (!kIsWeb) {
              try {
                FlutterLocalNotificationsPlugin().show(
                  notifId.hashCode,
                  title,
                  body,
                  const NotificationDetails(
                    android: AndroidNotificationDetails(
                      'high_importance_channel',
                      'High Importance Notifications',
                      channelDescription: 'This channel is used for important task notifications.',
                      icon: '@mipmap/ic_launcher',
                      importance: Importance.max,
                      priority: Priority.high,
                      playSound: true,
                    ),
                  ),
                );
              } catch (e) {
                debugPrint('Local Notification Trigger Error: $e');
              }
            }

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.notifications_active, color: Color(0xFFFBE64E)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                          Text(body, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                        ],
                      ),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xFF6B5800),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 4),
                action: SnackBarAction(
                  label: 'VIEW',
                  textColor: const Color(0xFFFBE64E),
                  onPressed: () {
                    FirebaseFirestore.instance.collection('notifications').doc(notifId).update({'isRead': true});
                  },
                ),
              ),
            );

            FirebaseFirestore.instance.collection('notifications').doc(notifId).update({'isRead': true});
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authVM = Provider.of<AuthViewModel>(context);
    final String currentLoc = GoRouterState.of(context).uri.toString();
    final bool hideBottomNav = !authVM.isProfileComplete ||
        !authVM.isApproved ||
        currentLoc.contains('complete-profile') ||
        currentLoc.contains('approval-pending');

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final allowed = authVM.permissions.dashboardTabs;
        if (allowed.isNotEmpty) {
           final firstTab = allowed.first;
           int targetIdx = 0;
           if (firstTab == 'projects') targetIdx = 1;
           else if (firstTab == 'cp') targetIdx = 2;
           if (widget.navigationShell.currentIndex != targetIdx) {
              widget.navigationShell.goBranch(targetIdx);
           }
        }
      },
      child: Scaffold(
        body: widget.navigationShell,
        bottomNavigationBar: hideBottomNav
            ? null
            : AppBottomNav(
                navigationShell: widget.navigationShell,
                currentTab: _getTabKey(widget.navigationShell.currentIndex),
                backgroundColor: Colors.white,
                activeIconColor: Colors.black87,
                activeLabelColor: Colors.black87,
                inactiveIconColor: Colors.grey.shade400,
                projectsLabel: 'Projects',
                cpLabel: 'Network',
              ),
      ),
    );
  }

  String _getTabKey(int index) {
    switch (index) {
      case 0: return 'dashboard';
      case 1: return 'projects';
      case 2: return 'cp';
      case 3: return 'builders';
      case 4: return 'admin';
      case 5: return 'map';
      default: return 'dashboard';
    }
  }
}
