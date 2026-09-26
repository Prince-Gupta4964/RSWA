# RSWA Comprehensive Project Structure

This document provides a highly detailed, file-by-file breakdown of the RSWA application. The project strictly follows the **MVVM (Model-ViewModel-View)** architecture pattern to ensure clean separation of concerns, scalability, and maintainability.

---

## 🏗️ Root Configuration & Entry Point
- **`lib/main.dart`**: The primary entry point of the Flutter application. It initializes Firebase, sets up global State Management (`MultiProvider` with all ViewModels), and defines the root `MaterialApp` using GoRouter.
- **`lib/firebase_options.dart`**: Auto-generated configuration file containing Firebase API keys and credentials for Android, iOS, and Web platforms.

---

## 🧭 Routing Layer
- **`lib/routes/app_router.dart`**: Centralized navigation configuration using `go_router`. It defines all the paths (`/login`, `/dashboard`, `/cp-list`, etc.), manages the `StatefulShellRoute` for the persistent bottom navigation bar, and applies the `AuthGuard` to protect authenticated routes.

---

## 🧠 State Management (ViewModels)
*Located in `lib/viewmodels/`* - These classes contain the business logic, communicate with the `services` layer, and hold the reactive state that the UI listens to.
- **`app_configuration_viewmodel.dart`**: Manages dynamic app settings, form dropdown options, lead statuses, and custom form structures loaded from Firestore.
- **`auth_viewmodel.dart`**: Core security module. Handles Google Sign-In, Email/Password auth, session persistence, role-based access control (RBAC), and user metadata.
- **`builder_viewmodel.dart`**: Manages the list of real estate builders/developers.
- **`cp_viewmodel.dart`**: Manages Channel Partners (CPs). Handles CP creation, updates, the multi-level referral chain logic (R1 $\rightarrow$ R2 $\rightarrow$ R3), and CP approvals.
- **`lead_viewmodel.dart`**: Manages Client/Lead data. Handles creating leads, tracking the Lead Lifecycle (Visit $\rightarrow$ Possession), filtering, sorting, and logging follow-up histories.
- **`project_viewmodel.dart`**: Manages Real Estate Projects and inventory details.
- **`property_viewmodel.dart`**: Legacy/Helper viewmodel for generic properties (if applicable).
- **`recycle_bin_viewmodel.dart`**: Manages the `recyclebin` Firestore collection. Allows for viewing soft-deleted items, restoring them to their original collections, or permanently deleting them in bulk.
- **`user_management_viewmodel.dart`**: Admin-only viewmodel used to create, manage, and assign roles to internal staff users.

---

## 🏛️ Data Structures (Models)
*Located in `lib/models/`* - Pure Dart classes representing database documents. They include `fromMap` factory methods to parse Firestore data safely.
- **`app_configuration_models.dart`**: Data classes for dynamic form fields and dashboard tab definitions.
- **`app_user_model.dart`**: Represents an internal staff member or admin.
- **`builder_model.dart`**: Represents a Developer/Builder company.
- **`cp_model.dart`**: Represents a Channel Partner, including tracking variables for the multi-level referral network.
- **`lead_model.dart`**: Represents a client, containing status, journey stages, and full property requirements.
- **`notification_model.dart`**: Represents an in-app system notification.
- **`project_model.dart`**: Represents a property project, containing inventory, location, and approval statuses.
- **`property_model.dart`**: General property representation.

---

## 🔌 Backend Communication (Services)
*Located in `lib/services/`* - These singletons handle direct communication with outside APIs, local storage, or Firebase.
- **`auth_service.dart`**: Lower-level Firebase Authentication wrapper.
- **`contact_picker_service.dart`**: Orchestrates native contact picking. Routes to the correct platform implementation.
  - **`contact_picker_mobile.dart`**: Android/iOS specific contact picker.
  - **`contact_picker_web.dart`**: Web specific contact picker fallback.
  - **`contact_picker_stub.dart`**: Interface definition to satisfy the Dart compiler across platforms.
- **`firebase_storage_service.dart`**: Handles uploading images and documents (like KYC/Visiting cards) to Firebase Storage and returning the download URLs.
- **`firestore_service.dart`**: Generic helper functions for querying Firestore.
- **`helper_service.dart`**: General utility methods for the service layer.
- **`storage_helper.dart`**: Wrapper around `shared_preferences` for saving local user sessions (keeping users logged in after app restart).
- **`whatsapp_service.dart`**: Connects to the external Deropo WhatsApp API to send automated journey notifications to leads. Includes the "Smart Fallback" logic for CORS circumvention on web.

---

## 🛠️ Configuration & Utilities (Utils)
*Located in `lib/utils/`*
- **`app_colors.dart`**: Centralized color palette (Primary: Yellow, Secondary: Olive, Accent: Orange).
- **`app_styles.dart`**: Reusable text styles, input decorations, and component shapes.
- **`constants.dart`**: Global string constants, API keys (if not in env), and system-wide variables.
- **`cp_form_config.dart`**: JSON-like structure defining the layout, fields, roles, and validation logic for the "Add Partner" form.
- **`lead_form_config.dart`**: JSON-like structure defining the "Add Lead" form layout and behavior.
- **`project_form_config.dart`**: JSON-like structure defining the "Add Project" form layout and conditional gatekeepers.
- **`record_access.dart`**: Logic rules determining which roles can read/write specific records.
- **`role_permissions.dart`**: The Core RBAC (Role-Based Access Control) engine. Defines permissions for `SuperAdmin`, `Admin`, `CP`, `OfficeStaff`, etc.

---

## 🎨 User Interface (Views)
*Located in `lib/views/`* - The actual screens users interact with, separated by domains.

### `/admin`
- **`admin_console_view.dart`**: Master dashboard for Admins to view all users, manage roles, and monitor system health.
- **`dropdown_manager_view.dart`**: UI allowing Admins to dynamically add/remove options from global form dropdowns.

### `/auth`
- **`login_view.dart`**: The main login gate. Handles Email/Password and Google Sign-in. Includes session sync tracking and referral link interception (`?ref=...`).
- **`signup_view.dart`**: Traditional registration screen (if enabled).

### `/builders`
- **`add_builder_view.dart`**: Form to onboard a new Developer/Builder.
- **`builder_detail_view.dart`**: Shows details of a specific builder.
- **`builder_list_view.dart`**: List of all registered builders.

### `/cp_network`
- **`add_cp_view.dart`**: The dynamic Channel Partner form. Includes the "Gatekeeper" logic (hiding form until type is selected) and the automated Multi-Level Referral chain calculations.
- **`complete_profile_view.dart`**: Onboarding screen for new CPs to finish setting up their details.
- **`contact_picker_sheet.dart`**: Custom UI overlay for picking numbers from the device phonebook.
- **`cp_detail_view.dart`**: Partner profile screen. Displays the Visual Referral Upline tree, Downline partners, KYC documents, and Admin Scorecard.
- **`cp_list_view.dart`**: Directory of all Channel Partners with role-based filtering (My Partners vs All Partners).

### `/dashboard`
- **`dashboard_view.dart`**: The default post-login screen. It dynamically renders the correct view based on the user's role.
- **`admin_dashboard.dart` / `staff_dashboard.dart` / `user_dashboard.dart`**: Sub-views rendered inside the main dashboard based on permissions.

### `/forms`
- **`custom_form_view.dart`**: A flexible engine capable of rendering entirely custom forms defined by JSON in the admin settings.

### `/leads`
- **`add_lead_view.dart`**: The dynamic Client/Lead entry form.
- **`followup_history_view.dart`**: A full log of every interaction, status change, and remark for a specific lead.
- **`lead_detail_view.dart`**: Detailed client profile. Includes the Interactive Journey Progress Stepper (Visit to Possession), Follow-up Timeline, and WhatsApp/Call quick actions.
- **`lead_list_view.dart`**: Rendered within the dashboard. Contains robust searching, filtering, and tab-based categorization of leads.
- **`task_detail_view.dart`**: Detailed view of a specific follow-up task.
- **`today_task_form_view.dart`**: Quick-entry modal/form for adding a new follow-up interaction or setting a future task.

### `/profile`
- **`my_profile_view.dart`**: The logged-in user's personal scorecard, settings, and profile details.

### `/projects`
- **`add_project_view.dart`**: Dynamic form for adding a new Real Estate Project.
- **`city_selection_view.dart`**: Modal for filtering the global project database by city.
- **`project_detail_view.dart`**: Complete project overview including inventory availability, pricing, amenities, and image carousels.
- **`project_list_view.dart`**: The primary inventory explorer with category tabs (Residential, Commercial, Plot) and advanced search.
- **`recycle_bin_view.dart`**: A recovery interface for soft-deleted projects and partners. Supports multi-selection, bulk restoration, and permanent deletion.

### `/shared_widgets`
- **`approval_pending_view.dart`**: Block screen shown to newly registered CPs until an admin approves them.
- **`custom_button.dart` / `custom_textfield.dart`**: Standardized UI elements for generic forms.

---

## 🗺️ Standalone Features
### `lib/features/map_screen/`
A heavy, standalone feature for field agents and visual location tracking.
- **`screens/map_screen.dart`**: Google Maps integration showing leads, projects, or tasks geographically.
- **`screens/assignee_tasks_view.dart`**: List of geographical tasks assigned to a specific staff member.
- **`screens/task_detail_page.dart`**: Details of a map-based task.
- **`models/task.dart` & `floating_sheet_type.dart`**: Data representations for map pins and bottom sheets.

---

## 🧩 Global Reusable Widgets
*Located in `lib/widgets/`*
- **`app_bottom_nav.dart`**: The persistent bottom navigation bar (Leads, Projects, CP, Map). Fast, animated, and state-preserving.
- **`app_drawer.dart`**: The slide-out side menu. Features a highly detailed, clickable Profile Header showing User Name, Status, Package, and Role.
- **`auth_guard.dart`**: Wraps every view in the router. Automatically redirects unauthenticated users back to the `/login` screen.
- **`google_auth_button/`**: Handles the UI and platform-specific implementations of the "Continue with Google" button (Federated Auth for Web, Standard SDK for Mobile).
- **`leads/follow_up_history_tile.dart`**: The specific UI card used to render a single interaction event inside the Lead Detail timeline.
