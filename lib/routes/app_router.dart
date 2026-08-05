import 'package:go_router/go_router.dart';
import '../models/lead_model.dart';
import '../models/project_model.dart';
import '../models/cp_model.dart';
import '../views/auth/login_view.dart';
import '../views/dashboard/dashboard_view.dart';
import '../views/admin/admin_console_view.dart';
import '../views/forms/custom_form_view.dart';
import '../views/leads/add_lead_view.dart';
import '../views/leads/lead_detail_view.dart';
import '../views/cp_network/add_cp_view.dart';
import '../views/cp_network/cp_list_view.dart';
import '../views/cp_network/cp_detail_view.dart';
import '../views/projects/add_project_view.dart';
import '../views/projects/project_list_view.dart';
import '../views/projects/project_detail_view.dart';
import '../views/projects/city_selection_view.dart';
import '../views/builders/builder_list_view.dart';
import '../views/builders/add_builder_view.dart';
import '../views/builders/builder_detail_view.dart';
import '../models/builder_model.dart';
import '../widgets/auth_guard.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: LoginView()),
      ),
      // --- MAIN TABS (Smooth No Transition for Bottom Nav) ---
      GoRoute(
        path: '/dashboard',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: AuthGuard(child: DashboardView())),
      ),
      GoRoute(
        path: '/cp-list',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: AuthGuard(child: CPListView())),
      ),
      GoRoute(
        path: '/projects',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: AuthGuard(child: ProjectListView())),
      ),
      GoRoute(
        path: '/admin-console',
        builder: (context, state) => const AuthGuard(child: AdminConsoleView()),
      ),
      GoRoute(
        path: '/builders',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: AuthGuard(child: BuilderListView())),
      ),
      GoRoute(
        path: '/custom-form/:formId',
        builder: (context, state) => AuthGuard(
          child: CustomFormView(formId: state.pathParameters['formId'] ?? ''),
        ),
      ),

      // --- SUB SCREENS (Default Slide Animation) ---
      GoRoute(
        path: '/add-lead',
        builder: (context, state) {
          final lead = state.extra as LeadModel?;
          return AuthGuard(child: AddLeadView(lead: lead));
        },
      ),
      GoRoute(
        path: '/lead-detail',
        builder: (context, state) {
          if (state.extra == null || state.extra is! LeadModel) {
            final emptyLead = LeadModel(
              id: '0',
              name: 'No Data Found (Go Back)',
              contact: '',
              status: '',
              favUids: const [],
              rawData: {},
            );
            return AuthGuard(child: LeadDetailView(lead: emptyLead));
          }
          final lead = state.extra as LeadModel;
          return AuthGuard(child: LeadDetailView(lead: lead));
        },
      ),
      GoRoute(
        path: '/add-cp',
        builder: (context, state) => const AuthGuard(child: AddCPView()),
      ),
      GoRoute(
        path: '/cp-detail',
        builder: (context, state) {
          final cp = state.extra as CPModel;
          return AuthGuard(child: CPDetailView(cp: cp));
        },
      ),
      GoRoute(
        path: '/add-project',
        builder: (context, state) {
          final project = state.extra as ProjectModel?;
          return AuthGuard(child: AddProjectView(project: project));
        },
      ),
      GoRoute(
        path: '/project-detail',
        builder: (context, state) {
          final project = state.extra as ProjectModel;
          return AuthGuard(child: ProjectDetailView(project: project));
        },
      ),
      GoRoute(
        path: '/city-select',
        builder: (context, state) =>
            const AuthGuard(child: CitySelectionView()),
      ),
      GoRoute(
        path: '/add-builder',
        builder: (context, state) {
          final builder = state.extra as BuilderModel?;
          return AuthGuard(child: AddBuilderView(builder: builder));
        },
      ),
      GoRoute(
        path: '/builder-detail',
        builder: (context, state) {
          final builder = state.extra as BuilderModel;
          return AuthGuard(child: BuilderDetailView(builder: builder));
        },
      ),
    ],
  );
}
