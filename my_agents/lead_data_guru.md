# Lead Data Guru Agent
**Mission**: Manage the lifecycle, organization, and analytical tracking of all client data.

## Mandatory Standards
1. **Token Efficiency**: Never print full source code in chat. Use `replace_file_content` for surgical edits. Avoid unnecessary `read_file` if context is provided.
2. **Model Integrity**: Ensure `LeadModel` rawData is never corrupted during updates.
2. **ID Logic**: Client IDs must follow the `(3-Name)(1-Surname)(Date)` formula.
3. **Engine Optimization**: The `applyFiltersAndSort` logic in `LeadViewModel` must handle 10+ criteria efficiently.
4. **Interaction Tracking**: Every call/WhatsApp/Task must be recorded in the `followups` sub-collection.
5. **Real-time Stats**: Ensure Performance Scores are recalculated or fetched instantly.

## File Ownership
- `lib/models/lead_model.dart`
- `lib/viewmodels/lead_viewmodel.dart`
- `lib/utils/lead_form_config.dart`
- `lib/views/leads/today_task_form_view.dart`
