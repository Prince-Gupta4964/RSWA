# Reorder Project Form Fields and Sections

The user wants to reorder the fields in the project addition form (`AddProjectView`). The sequence should follow a specific structure for Costing, Amenities, Legal Details, and Admin Details.

## User Review Required

> [!IMPORTANT]
> The requested sequence merges several existing sections and reorders fields. I have mapped the requested items to the existing fields in `project_form_config.dart`.
> Some fields in `Legal Details` now have visibility constraints (e.g., only visible for 'Project' type) based on the "P/PBL/PFSBL" codes provided.
> I have added a new field `priorityListing` in the `Admin Details` section.

## Proposed Changes

### [Component] Project Form Configuration

#### [MODIFY] [project_form_config.dart](file:///Users/prince/AndroidStudioProjects/rswa/lib/utils/project_form_config.dart)
- Rename and merge `Flat/Shop Details`, `Bungalow Details`, and `Land Details` into a new `Costing` section.
- Reorder fields within `Costing` as requested.
- Update `Amenities` section to include fields from the `Brochures` section.
- Reorder `Legal Details` fields and add `visibleIf` constraints according to the provided codes (P, PBL, PB, etc.).
- Reorder `Admin Details` fields and add `Priority in Listing`.

## Verification Plan

### Automated Tests
- N/A (UI configuration change)

### Manual Verification
- Open the "New Project" form in the app.
- Verify the sequence of sections: Basic Info, Location & Address, Costing, Amenities, Legal Details, Admin Details.
- Select different `Property Type` values (Project, Flat, Land, etc.) and verify that the visibility of fields in `Costing` and `Legal Details` changes correctly.
- Verify that the `Admin Details` section contains the new `Priority in Listing` field.
