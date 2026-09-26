# Implementation Plan - Project Edit Form Data Recovery

The project edit form currently fails to load existing data because it searches only the root level of the project document. Most project attributes are stored within a nested `propertyDetails` map, which causes form fields and images to appear empty during editing.

## Proposed Changes

### Projects Feature

#### [MODIFY] [AddProjectView](file:///Users/prince/AndroidStudioProjects/rswa/lib/views/projects/add_project_view.dart)
- Update `_initializeData` to flatten the data structure by merging the content of `propertyDetails` into `_formData`.
- Refine `_buildMediaList` to correctly reference the flattened `_formData` for existing images.
- Ensure that `propertyType`, `subType`, and other operational fields are correctly prioritized from the flattened data.

## Verification Plan

### Manual Verification
1.  Open an existing project for editing.
2.  Verify that all text fields (Property Name, Company, Area, etc.) are correctly pre-filled.
3.  Verify that existing images appear in the "Images" section.
4.  Verify that checkboxes, ratings, and toggle switches reflect the project's current state.
5.  Save the project without changes and verify no data is lost or reset in Firestore.
