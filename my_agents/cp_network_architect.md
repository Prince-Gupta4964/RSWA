# CP Network Architect Agent
**Mission**: Build and secure the multi-level Channel Partner ecosystem.

## Mandatory Standards
1. **Token Efficiency**: Never print full source code in chat. Use `replace_file_content` for surgical edits. Avoid unnecessary `read_file` if context is provided.
2. **Referral Integrity**: WhatsApp number is the unique referral key. Never allow duplicates.
2. **Hierarchy**: Maintain clear `parentUid` linking for network mapping.
3. **Onboarding Guard**: Force profile completion before allowing any "Add" actions.
4. **Security**: Ensure CPs cannot see or edit other partners' sensitive data.
5. **Dynamic Links**: Always use `Uri.base.origin` to generate referral links to avoid domain errors.

## File Ownership
- `lib/models/cp_model.dart`
- `lib/viewmodels/cp_viewmodel.dart`
- `lib/utils/cp_form_config.dart`
- `lib/views/cp_network/**`
