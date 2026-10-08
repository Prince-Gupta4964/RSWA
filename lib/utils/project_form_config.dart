class ProjectFormStrings {
  static const String sectionBasicInfo = 'Basic Info';
  static const String sectionLocation = 'Property Details';
  static const String sectionAmenities = 'Amenities';
  static const String sectionLegalDetails = 'Legal Details';
  static const String sectionOthers = 'Others';
  static const String sectionAdminDetails = 'Admin Details';

  static const List<Map<String, dynamic>> formStructure = [
    {
      'title': sectionBasicInfo,
      'fields': [
        {'id': 'coverImage', 'label': 'Cover Image', 'type': 'file'},
        {'id': 'images', 'label': 'Images Max 10', 'type': 'media_list'},
        {'id': 'highlightsImages', 'label': 'Highlights Max 10', 'type': 'media_list'},
        {'id': 'outdoorsImages', 'label': 'Outdoors Max 10', 'type': 'media_list'},
        {'id': 'projectVideo', 'label': 'Project Video File / Link', 'type': 'file'},
        {
          'id': 'propertyType',
          'label': 'Property Type',
          'type': 'chips',
          'options': ['Project', 'Flat', 'Shop', 'Bungalow', 'Land']
        },
        {
          'id': 'subType',
          'label': 'Property Sub Type',
          'type': 'chips',
          'options': [], // Populated dynamically in UI
          'visibleIf': 'propertyType != '
        },
        {
          'id': 'configuration',
          'label': 'Configuration',
          'type': 'addable_chips',
          'options': ['1 BHK', '2 BHK', '3 BHK', '4 BHK'],
          'visibleIf': 'propertyType != Land && propertyType != Shop'
        },
        {'id': 'propertyName', 'label': 'Property Name', 'type': 'searchable'},
        {'id': 'projectCompany', 'label': 'Project Company', 'type': 'searchable'},
        {'id': 'plotCostLand', 'label': 'Plot Cost', 'type': 'number', 'visibleIf': 'propertyType == Land'},
        {
          'type': 'row',
          'fields': [
            {'id': 'totalAreaGuntha', 'label': 'Plot Size in Guntha', 'type': 'number', 'visibleIf': 'propertyType == Land'},
            {'id': 'zone', 'label': 'Zone', 'type': 'text', 'visibleIf': 'propertyType == Land'},
          ]
        },
        {
          'id': 'builderSelection',
          'label': 'Select Builders',
          'type': 'builder_selector',
          'roles': ['admin', 'super_admin'],
          'visibleIf': 'propertyType != Land'
        },
        {
          'id': 'source',
          'label': 'Source',
          'type': 'dropdown',
          'options': [
            'Walk In', 'Referral', 'Event', 'Digital Marketing', 'Banner Marketing', 
            'Poster Marketing', 'Pamphlet Marketing', 'Seminar', 'Facebook', 
            'Instagram', 'Youtube', 'Justdial', 'Website', 'IVR', 'Others'
          ]
        },
        {'id': 'referral', 'label': 'Referral Name', 'type': 'searchable', 'visibleIf': 'source == Referral'},
        {'id': 'nearestStation', 'label': 'Nearest Station', 'type': 'searchable'},
        {
          'id': 'status',
          'label': 'Status',
          'type': 'chips',
          'options': ['Available', 'Private', 'Premium', 'Reserved', 'Sold']
        },
      ]
    },
    {
      'title': sectionLocation,
      'fields': [
        {'id': 'possessionDate', 'label': 'Possession Date', 'type': 'date', 'visibleIf': 'propertyType != Land'},
        {
          'id': 'wing', 
          'label': 'Wing', 
          'type': 'addable_chips', 
          'options': ['A', 'B', 'C', 'D'],
          'visibleIf': 'propertyType != Land'
        },
        {'id': 'flatNoDetail', 'label': 'Flat / Shop / Bungalow Number', 'type': 'text', 'visibleIf': 'propertyType != Land'},
        {
          'type': 'row',
          'fields': [
            {'id': 'reraArea', 'label': 'Rera Carpet Area in Sq ft', 'type': 'number', 'visibleIf': 'propertyType != Land'},
            {'id': 'usableArea', 'label': 'Usable Carpet Area in Sq ft', 'type': 'number', 'visibleIf': 'propertyType != Land'},
          ]
        },
        {'id': 'bua', 'label': 'BUA in Sq ft', 'type': 'number', 'visibleIf': 'propertyType != Land'},
        {
          'type': 'row',
          'fields': [
            {'id': 'minCost', 'label': 'Min Cost', 'type': 'number', 'visibleIf': 'propertyType != Land'},
            {'id': 'minPercentage', 'label': 'Min Percentage', 'type': 'number', 'visibleIf': 'propertyType != Land'},
          ]
        },
        {
          'type': 'row',
          'fields': [
            {'id': 'maxCost', 'label': 'Max Cost', 'type': 'number', 'visibleIf': 'propertyType != Land'},
            {'id': 'maxPercentage', 'label': 'Max Percentage', 'type': 'number', 'visibleIf': 'propertyType != Land'},
          ]
        },
        {'id': 'sqFtCost', 'label': 'Sq ft cost on Usable Carpet Area', 'type': 'number', 'visibleIf': 'propertyType != Land'},
        {
          'type': 'row',
          'fields': [
            {'id': 'totalUnits', 'label': 'Total Units', 'type': 'number', 'visibleIf': 'propertyType != Land'},
            {'id': 'totalUnitsLeft', 'label': 'Total Units Left', 'type': 'number', 'visibleIf': 'propertyType != Land'},
          ]
        },
        
        // --- Land Specific Details ---
        {
          'type': 'row',
          'fields': [
            {'id': 'surveyNo', 'label': 'Survey No', 'type': 'text', 'visibleIf': 'propertyType == Land'},
            {'id': 'hissaNumber', 'label': 'Hissa Number', 'type': 'text', 'visibleIf': 'propertyType == Land'},
          ]
        },
        {
          'type': 'row',
          'fields': [
            {'id': 'totalAreaGuntha', 'label': 'Plot Size in Guntha', 'type': 'number', 'visibleIf': 'propertyType == Land'},
          ]
        },
        {
          'type': 'row',
          'fields': [
            {'id': 'plotCostLand', 'label': 'Plot Cost', 'type': 'number', 'visibleIf': 'propertyType == Land'},
            {'id': 'sqFtCostLand', 'label': 'Cost per sqft', 'type': 'number', 'visibleIf': 'propertyType == Land'},
          ]
        },
        {
          'type': 'row',
          'fields': [
            {'id': 'roadLength', 'label': 'Road Length', 'type': 'text', 'visibleIf': 'propertyType == Land'},
            {'id': 'zone', 'label': 'Zone', 'type': 'text', 'visibleIf': 'propertyType == Land'},
          ]
        },
        {
          'type': 'row',
          'fields': [
            {
              'id': 'roadDirection', 
              'label': 'Road Direction', 
              'type': 'dropdown', 
              'options': ['North', 'South', 'East', 'West', 'North-East', 'North-West', 'South-East', 'South-West'],
              'visibleIf': 'propertyType == Land'
            },
            {
              'id': 'compoundingDone', 
              'label': 'Compound Done', 
              'type': 'switch',
              'visibleIf': 'propertyType == Land'
            },
          ]
        },
        {
          'type': 'row',
          'fields': [
            {'id': 'fsi', 'label': 'FSI', 'type': 'text', 'visibleIf': 'propertyType == Land'},
            {'id': 'tdr', 'label': 'TDR', 'type': 'text', 'visibleIf': 'propertyType == Land'},
          ]
        },
        {'id': 'roadAccess', 'label': 'Road Access', 'type': 'text', 'visibleIf': 'propertyType == Land'},
        
        // --- Shared Location Fields ---
        {'id': 'flatNo', 'label': 'House/Plot Number (Short)', 'type': 'text'},
        {'id': 'buildingName', 'label': 'Building Name', 'type': 'text', 'visibleIf': 'propertyType != Bungalow && propertyType != Land'},
        {'id': 'areaName', 'label': 'Area Name', 'type': 'text', 'visibleIf': 'propertyType != Land'},
        {'id': 'nearby', 'label': 'Nearby', 'type': 'text', 'visibleIf': 'propertyType != Land'},
        {'id': 'opposite', 'label': 'Opposite', 'type': 'text', 'visibleIf': 'propertyType != Land'},
        {'id': 'road', 'label': 'Road Name', 'type': 'text', 'visibleIf': 'propertyType != Land'},
        {
          'type': 'row',
          'fields': [
            {'id': 'district', 'label': 'District', 'type': 'text'},
            {'id': 'state', 'label': 'State', 'type': 'text'},
          ]
        },
        {
          'type': 'row',
          'fields': [
            {'id': 'village', 'label': 'Village', 'type': 'text', 'visibleIf': 'propertyType != Land'},
            {'id': 'pincode', 'label': 'Pincode', 'type': 'number'},
          ]
        },
        {'id': 'location', 'label': 'Location', 'type': 'text', 'visibleIf': 'propertyType != Land'},
        {'id': 'googleLocationLink', 'label': 'Google Location Link', 'type': 'text'},
        {'id': 'address', 'label': 'Full Address (Auto-generated)', 'type': 'multiline', 'readOnly': true},
        {'id': 'lastUpdatedOn', 'label': 'Last Updated On', 'type': 'text', 'readOnly': true},
      ]
    },
    {
      'title': sectionAmenities,
      'visibleIf': 'propertyType != Land',
      'fields': [
        {
          'id': 'usp',
          'label': 'USP',
          'type': 'addable_chips',
          'options': ['Free 3D Design', 'Tech Enabled Society', 'Rooftop Amenities']
        },
        {
          'id': 'keyAmenities',
          'label': 'Key Amenities',
          'type': 'addable_chips',
          'options': ['Clubhouse', 'Jacuzzi', 'Gym', 'EV Charging', 'Cameras', 'Play Area', 'Garden', 'Others']
        },
        {
          'id': 'nearbyFacilities',
          'label': 'Nearby Facilities',
          'type': 'addable_chips',
          'options': ['Nearest Station', 'Nearest Station Distance', 'School', 'Malls', 'Hospital', 'Garden', 'Others']
        },
        {'id': 'otherAmenities', 'label': 'Other Amenities', 'type': 'multiline'},
        {'id': 'internalAmenities', 'label': 'Internal Amenities', 'type': 'multiline'},
        {
          'title': 'Brochures',
          'type': 'group',
          'fields': [
            {'id': 'brochurePdf', 'label': 'Brochure pdf', 'type': 'file'},
            {'id': 'floorPlanPdf', 'label': 'Floor plan pdf', 'type': 'file'},
            {'id': 'layoutPlanPdf', 'label': 'Layout plan pdf', 'type': 'file'},
          ]
        }
      ]
    },
    {
      'title': sectionLegalDetails,
      'fields': [
        {
          'type': 'row',
          'fields': [
            {'id': 'isReraApproved', 'label': 'Rera Approved?', 'type': 'switch', 'visibleIf': 'propertyType != Land'},
            {'id': 'reraNumber', 'label': 'Rera Number', 'type': 'text', 'visibleIf': 'propertyType != Land'},
          ]
        },
        {'id': 'isTitleClear', 'label': 'Title Clear?', 'type': 'switch'},
        {'id': 'titleSearchReport', 'label': 'Title & Search Report', 'type': 'file'},
        {'id': 'satBara', 'label': 'Sat Bata', 'type': 'file'},
        {'id': 'nonAgriculture', 'label': 'Non - Agriculture', 'type': 'file'},
        {'id': 'zoneCertificate', 'label': 'Zone Certificate', 'type': 'file'},
        {'id': 'physicalSurvey', 'label': 'Physical Survey', 'type': 'file'},
        {'id': 'buildersOwnerName', 'label': 'Builders/Owner Name', 'type': 'text'},
        {'id': 'developmentAgreement', 'label': 'Development Agreement', 'type': 'file'},
        {'id': 'partnershipDeed', 'label': 'Partnership Deed', 'type': 'file'},
        {'id': 'commencementCertificate', 'label': 'Commencement Certificate', 'type': 'file', 'visibleIf': 'propertyType != Land'},
        {'id': 'plinthCertificate', 'label': 'Plinth Certificate', 'type': 'file', 'visibleIf': 'propertyType != Land'},
        {'id': 'completionCertificate', 'label': 'Completion Certificate', 'type': 'file', 'visibleIf': 'propertyType != Land'},
        {'id': 'projectReport', 'label': 'Project Report', 'type': 'file'},
      ]
    },
    {
      'title': sectionOthers,
      'fields': [
        {'id': 'otherAttachments', 'label': 'Custom Attachments & Files', 'type': 'custom_attachment_list'},
      ]
    },
    {
      'title': sectionAdminDetails,
      'roles': ['admin', 'super_admin'],
      'fields': [
        {'id': 'isApproved', 'label': 'Approve Project', 'type': 'switch', 'roles': ['admin', 'super_admin']},
        {'id': 'isLegallyVerified', 'label': 'Legally Verified', 'type': 'switch', 'roles': ['admin', 'super_admin']},
        {'id': 'projectStatus', 'label': 'Status', 'type': 'project_status_selector', 'roles': ['admin', 'super_admin']},
        {'id': 'isHot', 'label': 'Priority in Listing (1 - 30)', 'type': 'dropdown', 'options': ['None', '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', '13', '14', '15', '16', '17', '18', '19', '20', '21', '22', '23', '24', '25', '26', '27', '28', '29', '30'], 'roles': ['admin', 'super_admin']},
        {'id': 'points', 'label': 'Property Points', 'type': 'number'},
        {'id': 'adminRating', 'label': 'Admin Rating', 'type': 'rating'},
        {'id': 'peopleRating', 'label': 'People Rating', 'type': 'rating'},
        {'id': 'likeButton', 'label': 'Like button', 'type': 'like'},
      ]
    },
  ];
}
