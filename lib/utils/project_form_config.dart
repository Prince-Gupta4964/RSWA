class ProjectFormStrings {
  static const String sectionBasicInfo = 'Basic Info';
  static const String sectionLocation = 'Property Details';
  static const String sectionAmenities = 'Amenities';
  static const String sectionLegalDetails = 'Legal Details';
  static const String sectionAdminDetails = 'Admin Details';

  static const List<Map<String, dynamic>> formStructure = [
    {
      'title': sectionBasicInfo,
      'fields': [
        {'id': 'images', 'label': 'Images (Max 10)', 'type': 'media_list'},
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
        {'id': 'propertyName', 'label': 'Property Name', 'type': 'searchable'},
        {'id': 'projectCompany', 'label': 'Project Company', 'type': 'searchable'},
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
        {'id': 'startingPrice', 'label': 'Starting Price', 'type': 'searchable'},
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
        
        // --- Land Specific Details Moved and Expanded ---
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
            {'id': 'totalAreaGuntha', 'label': 'Total Area in Guntha', 'type': 'number', 'visibleIf': 'propertyType == Land'},
            {'id': 'zone', 'label': 'Zone', 'type': 'text', 'visibleIf': 'propertyType == Land'},
          ]
        },
        {
          'type': 'row',
          'fields': [
            {'id': 'minCostLand', 'label': 'Min Cost', 'type': 'number', 'visibleIf': 'propertyType == Land'},
            {'id': 'minPercentageLand', 'label': 'Min Percentage', 'type': 'number', 'visibleIf': 'propertyType == Land'},
          ]
        },
        {
          'type': 'row',
          'fields': [
            {'id': 'maxCostLand', 'label': 'Max Cost', 'type': 'number', 'visibleIf': 'propertyType == Land'},
            {'id': 'maxPercentageLand', 'label': 'Max Percentage', 'type': 'number', 'visibleIf': 'propertyType == Land'},
          ]
        },
        {
          'type': 'row',
          'fields': [
            {'id': 'level5Percentage', 'label': 'Level 5 Percentage', 'type': 'number', 'visibleIf': 'propertyType == Land'},
            {'id': 'roadLength', 'label': 'Road Length', 'type': 'text', 'visibleIf': 'propertyType == Land'},
          ]
        },
        {
          'type': 'row',
          'fields': [
            {
              'id': 'roadDirection', 
              'label': 'Road Direction', 
              'type': 'chips', 
              'options': ['North', 'South', 'East', 'West', 'North-East', 'North-West', 'South-East', 'South-West'],
              'visibleIf': 'propertyType == Land'
            },
            {'id': 'compoundingDone', 'label': 'Compounding Done', 'type': 'chips', 'options': ['Y', 'N'], 'visibleIf': 'propertyType == Land'},
          ]
        },
        {
          'type': 'row',
          'fields': [
            {'id': 'fsi', 'label': 'FSI', 'type': 'text', 'visibleIf': 'propertyType == Land'},
            {'id': 'roadFrontage', 'label': 'Road Frontage', 'type': 'text', 'visibleIf': 'propertyType == Land'},
          ]
        },
        {'id': 'boundaryWall', 'label': 'Boundary Wall', 'type': 'text', 'visibleIf': 'propertyType == Land'},
        {'id': 'roadAccess', 'label': 'Road Access', 'type': 'text', 'visibleIf': 'propertyType == Land'},
        
        // --- Shared Location Fields ---
        {'id': 'flatNo', 'label': 'House/Plot Number (Short)', 'type': 'text'},
        {'id': 'buildingName', 'label': 'Building Name', 'type': 'text', 'visibleIf': 'propertyType != Bungalow && propertyType != Land'},
        {'id': 'areaName', 'label': 'Area Name', 'type': 'text'},
        {'id': 'nearby', 'label': 'Nearby', 'type': 'text'},
        {'id': 'opposite', 'label': 'Opposite', 'type': 'text'},
        {'id': 'road', 'label': 'Road Name', 'type': 'text'},
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
            {'id': 'village', 'label': 'Village', 'type': 'text'},
            {'id': 'pincode', 'label': 'Pincode', 'type': 'number'},
          ]
        },
        {'id': 'googleLocation', 'label': 'Google Location', 'type': 'text'},
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
            {'id': 'isReraApproved', 'label': 'Rera Approved?', 'type': 'switch'},
            {'id': 'reraNumber', 'label': 'Rera Number', 'type': 'text'},
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
      'title': sectionAdminDetails,
      'roles': ['admin', 'super_admin'],
      'fields': [
        {'id': 'isApproved', 'label': 'Approve Project', 'type': 'switch', 'roles': ['admin', 'super_admin']},
        {'id': 'isLegallyVerified', 'label': 'Legally Verified', 'type': 'switch', 'roles': ['admin', 'super_admin']},
        {'id': 'isHot', 'label': 'Priority in Listing', 'type': 'switch'},
        {'id': 'points', 'label': 'Property Points', 'type': 'number'},
        {'id': 'adminRating', 'label': 'Admin Rating', 'type': 'rating'},
        {'id': 'peopleRating', 'label': 'People Rating', 'type': 'rating'},
        {'id': 'alreadyExists', 'label': 'Already Exists', 'type': 'switch'},
        {'id': 'likeButton', 'label': 'Like button', 'type': 'like'},
      ]
    },
  ];
}
