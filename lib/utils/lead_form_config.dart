class LeadFormStrings {
  // --- SECTION TITLES ---
  static const String sectionBasicInfo = "Basic Info";
  static const String sectionClientDetails = "Client Details";
  static const String sectionOtherDetails = "Other Details";

  // --- FIELD LABELS ---
  static const String labelID = "Lead ID";
  static const String labelDateTime = "Date Time";
  static const String labelCompany = "Select Company";
  static const String labelProject = "Select Project";
  static const String labelName = "Name";
  static const String labelSurname = "Surname";
  static const String labelProfession = "Profession";
  static const String labelWhatsApp = "WhatsApp Number";
  static const String labelContact2 = "Contact 2";
  static const String labelNearestStation = "Nearest Station";
  static const String labelLeadSource = "Lead Source";
  static const String labelReferralName1 = "Referral Name 1";
  static const String labelReferralName2 = "Referral Name 2";
  static const String labelReferralName3 = "Referral Name 3";
  static const String labelLeadStatus = "Lead Status";
  static const String labelSendProjectDetails = "Send Project Details";

  static const String labelGender = "Gender";
  static const String labelEmail = "Email";
  static const String labelAddress = "Full Address";
  static const String labelDemoDone = "Demo Done";
  static const String labelDemoBy = "Demo By";
  static const String labelDemoType = "Demo Type";
  static const String labelNowLivingIn = "Now Living In";
  static const String labelConfiguration = "Configuration";
  static const String labelWing = "Wing";
  static const String labelFlatNumber = "Flat / Bungalow Number";
  static const String labelLandSqFt = "Land In Sq ft";
  static const String labelRatePerSqFt = "Rate per sq ft";
  static const String labelFlatCost = "Flat Cost";
  static const String labelAgreementValue = "Agreement Value";
  static const String labelGSRAmount = "GSR Amount";
  static const String labelTotalAmount = "Total Amount";
  static const String labelBudget = "Budget";
  static const String labelMonthlyIncome = "Monthly Income";
  static const String labelDownPayment = "Down Payment";
  static const String labelCoupon = "Coupon";
  static const String labelCouponCode = "Coupon Code";
  static const String labelFinalAmount = "Final Amount";

  static const String labelMajorProblem = "Major Problem";
  static const String labelMajorRequirements = "Major Requirements";
  static const String labelPreferredLocations = "Preferred Locations";
  static const String labelBookingDate = "Booking Date";
  static const String labelFreeTime = "Free Time";
  static const String labelCameWith = "Came With";
  static const String labelDOB = "Date of Birth";
  static const String labelTOB = "Time of Birth";
  static const String labelReligion = "Religion";
  static const String labelRemark = "Remark / Story";
  static const String labelAdvisor = "Advisor";
  static const String labelCaller = "Caller";
  static const String labelReachedBy = "Reached By (Staff)";
  static const String labelVisitingCard = "Visiting Card";

  // --- AUTOCOMPLETE DATA ---
  static const List<String> commonSurnames = [
    "Patel", "Sharma", "Singh", "Gupta", "Khan", "Rao", "Shah", "Jain", "Desai", "Mistry", "Pawar", "Kulkarni", "Joshi", "Bhatt", "Chavan"
  ];

  static const List<String> commonProfessions = [
    "Business", "Salaried", "Doctor", "Engineer", "Self Employed", "Housewife", "Student", "Retired", "Teacher", "Freelancer", "Consultant"
  ];

  static const List<String> commonStations = [
    "Mumbai Central", "Thane", "Borivali", "Andheri", "Dadar", "Vashi", "Kalyan", "Ghatkopar", "Malad", "Virar"
  ];

  static const List<String> commonReligions = [
    "Hindu", "Muslim", "Christian", "Sikh", "Buddhist", "Jain", "Parsi", "Other"
  ];

  static const List<String> demoTypes = [
    "Presentation", "VR", "Visited", "Sample Flat", "30 Check List", "Gift", "Spin", "Other"
  ];


  // --- DYNAMIC SEQUENCE & STRUCTURE ---
  static const List<Map<String, dynamic>> formStructure = [
    {
      "title": sectionBasicInfo,
      "fields": [
        {"id": "timestamp", "label": labelDateTime, "type": "text", "readOnly": true},
        {
          "type": "row",
          "fields": [
            {"id": "company", "label": labelCompany, "type": "dropdown", "options": ["Insight", "Partner"]},
            {"id": "project", "label": labelProject, "type": "project_dropdown"},
          ]
        },
        {
          "type": "row",
          "fields": [
            {"id": "name", "label": labelName, "type": "text"},
            {"id": "surname", "label": labelSurname, "type": "autocomplete", "options": commonSurnames},
          ]
        },
        {"id": "profession", "label": labelProfession, "type": "autocomplete", "options": commonProfessions},
        {"id": "whatsapp", "label": labelWhatsApp, "type": "phone", "isRequired": true},
        {"id": "contact2", "label": labelContact2, "type": "phone"},
        {"id": "nearestStation", "label": labelNearestStation, "type": "autocomplete", "options": commonStations},
        {"id": "source", "label": labelLeadSource, "type": "dropdown", "options": ["Referral", "Walk In", "Digital Marketing", "Event", "BNI", "Just Dial", "Housing.com", "Poster Marketing", "Banner Marketing", "Pamphlet Marketing"]},
        {"id": "referralName1", "label": labelReferralName1, "type": "cp_dropdown", "visibleIf": "source == Referral"},
        {"id": "referralName2", "label": labelReferralName2, "type": "cp_dropdown", "visibleIf": "source == Referral", "hideIf": "role != super_admin"},
        {"id": "referralName3", "label": labelReferralName3, "type": "cp_dropdown", "visibleIf": "source == Referral", "hideIf": "role != super_admin"},
        {"id": "status", "label": labelLeadStatus, "type": "chips", "dynamicStatus": true},
        {"id": "sendProjectDetails", "label": labelSendProjectDetails, "type": "switch"},
      ]
    },
    {
      "title": sectionClientDetails,
      "fields": [
        {"id": "gender", "label": labelGender, "type": "chips", "options": ["Male", "Female", "Others"]},
        {"id": "email", "label": labelEmail, "type": "text"},
        {"id": "address", "label": labelAddress, "type": "multiline"},
        {"id": "demoDone", "label": labelDemoDone, "type": "switch"},
        {"id": "demoBy", "label": labelDemoBy, "type": "text", "visibleIf": "demoDone == Yes", "readOnly": true},
        {"id": "demoType", "label": labelDemoType, "type": "dropdown", "options": demoTypes, "visibleIf": "demoDone == Yes"},
        {"id": "livingIn", "label": labelNowLivingIn, "type": "text"},
        {"id": "propertyType", "label": labelConfiguration, "type": "chips", "options": ["1RK", "1BHK", "2BHK", "3BHK", "4BHK", "5BHK", "Bungalow", "Land"]},
        {"id": "wing", "label": labelWing, "type": "text", "visibleIf": "propertyType != Bungalow && propertyType != Land"},
        {"id": "flatNumber", "label": labelFlatNumber, "type": "text"},
        {"id": "landSqFt", "label": labelLandSqFt, "type": "number"},
        {"id": "ratePerSqFt", "label": labelRatePerSqFt, "type": "number"},
        {"id": "flatCost", "label": labelFlatCost, "type": "number"},
        {"id": "agreementValue", "label": labelAgreementValue, "type": "number"},
        {"id": "gsrAmount", "label": labelGSRAmount, "type": "number"},
        {"id": "totalAmount", "label": labelTotalAmount, "type": "number"},
        {"id": "budget", "label": labelBudget, "type": "text"},
        {"id": "monthlyIncome", "label": labelMonthlyIncome, "type": "text"},
        {"id": "downPayment", "label": labelDownPayment, "type": "text"},
        {"id": "coupon", "label": labelCoupon, "type": "switch"},
        {"id": "couponCode", "label": labelCouponCode, "type": "text", "visibleIf": "coupon == Yes"},
        {"id": "finalAmount", "label": labelFinalAmount, "type": "number"},
      ]
    },
    {
      "title": sectionOtherDetails,
      "fields": [
        {"id": "majorProblem", "label": labelMajorProblem, "type": "multiline"},
        {"id": "majorRequirements", "label": labelMajorRequirements, "type": "multiline"},
        {"id": "preferredLocations", "label": labelPreferredLocations, "type": "text"},
        {"id": "bookingDate", "label": labelBookingDate, "type": "date"},
        {"id": "freeTime", "label": labelFreeTime, "type": "time"},
        {"id": "cameWith", "label": labelCameWith, "type": "text"},
        {"id": "dob", "label": labelDOB, "type": "date"},
        {"id": "tob", "label": labelTOB, "type": "time"},
        {"id": "religion", "label": labelReligion, "type": "autocomplete", "options": commonReligions},
        {"id": "remark", "label": labelRemark, "type": "multiline"},
        {"id": "advisor", "label": labelAdvisor, "type": "cp_dropdown"},
        {"id": "caller", "label": labelCaller, "type": "text"},
        {"id": "reachedBy", "label": labelReachedBy, "type": "autocomplete", "options": ["Admin 1", "Admin 2", "Sales 1"]},
        {"id": "visitingCard", "label": labelVisitingCard, "type": "image"},
      ]
    }
  ];
}
