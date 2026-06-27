import 'package:go_router/go_router.dart';
import '../models/lead_model.dart';
import '../models/project_model.dart';
import '../models/cp_model.dart'; // <-- NAYA: CP Model ka import add kiya
import '../views/dashboard/dashboard_view.dart';
import '../views/leads/add_lead_view.dart';
import '../views/leads/lead_detail_view.dart';
import '../views/cp_network/add_cp_view.dart';
import '../views/cp_network/cp_list_view.dart';
import '../views/cp_network/cp_detail_view.dart'; // <-- NAYA: CP Detail View ka import add kiya
import '../views/projects/add_project_view.dart';
import '../views/projects/project_list_view.dart';
import '../views/projects/project_detail_view.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/dashboard',
    routes: [
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardView(),
      ),
      GoRoute(
        path: '/add-lead',
        builder: (context, state) {
          final lead = state.extra as LeadModel?;
          return AddLeadView(lead: lead);
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
              rawData: {},
            );
            return LeadDetailView(lead: emptyLead);
          }
          final lead = state.extra as LeadModel;
          return LeadDetailView(lead: lead);
        },
      ),

      // --- CP Network Routes ---
      GoRoute(
        path: '/cp-list',
        builder: (context, state) => const CPListView(),
      ),
      GoRoute(
        path: '/add-cp',
        builder: (context, state) => const AddCPView(),
      ),
      // --- NAYA ROUTE: CP Detail/Profile Page ke liye ---
      GoRoute(
        path: '/cp-detail',
        builder: (context, state) {
          final cp = state.extra as CPModel;
          return CPDetailView(cp: cp);
        },
      ),

      // --- Projects Inventory Routes ---
      GoRoute(
        path: '/projects',
        builder: (context, state) => const ProjectListView(),
      ),
      GoRoute(
        path: '/add-project',
        builder: (context, state) => const AddProjectView(),
      ),
      GoRoute(
        path: '/project-detail',
        builder: (context, state) {
          final project = state.extra as ProjectModel;
          return ProjectDetailView(project: project);
        },
      ),
    ],
  );
}