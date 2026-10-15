class LeadFormStrings {
  // --- SECTION TITLES ---
  static const String sectionBasicInfo = "Basic Info";
  static const String sectionClientDetails = "Client Details";
  static const String sectionOtherDetails = "Other Details";
  static const String sectionPaidDetails = "Paid Details";
  static const String sectionHiddenDetails = "Hidden Details";

  // --- FIELD LABELS ---
  static const String labelID = "Lead ID";
  static const String labelDateTime = "Date Time";
  static const String labelCompany = "Select Company";
  static const String labelProject = "Select Project";
  static const String labelName = "Name";
  static const String labelSurname = "Surname";
  static const String labelProfession = "Profession";
  static const String labelWhatsApp = "Contact 1 (WhatsApp)";
  static const String labelContact2 = "Contact 2";
  static const String labelNearestStation = "Nearest Station";
  static const String labelLeadSource = "Lead Source";
  static const String labelReferralName1 = "Referral Name 1";
  static const String labelReferralName2 = "Referral Name 2 #SuperAdmin";
  static const String labelReferralName3 = "Referral Name 3 #SuperAdmin";
  static const String labelPropertyType = "Property Type";
  static const String labelConfiguration = "Configuration";
  static const String labelLeadStatus = "Lead Status";
  static const String labelIsPrivate = "Make Lead Private";
  static const String labelSendProjectDetails = "Send Project Details";

  static const String labelGender = "Gender";
  static const String labelEmail = "Email";
  static const String labelAddress = "Full Address";
  static const String labelDemoDone = "Demo Done";
  static const String labelDemoBy = "Demo By";
  static const String labelDemoType = "Demo Type";
  static const String labelNowLivingIn = "Now Living In";
  static const String labelAreaName = "Area Name";
  static const String labelWing = "Wing";
  static const String labelFlatNumber = "Flat / Bungalow Number";
  static const String labelAreaSqFt = "Area In Sq ft";
  static const String labelRatePerSqFt = "Rate per sq ft";
  static const String labelFlatCost = "Flat Cost";
  static const String labelAgreementValue = "Agreement Value";
  static const String labelSRGAmount = "SRG Amount (9%)";
  static const String labelTotalPackageAmount = "Total Package Amount";
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
  static const String labelDOB = "Date of Birth (Astro)";
  static const String labelTOB = "Time of Birth";
  static const String labelReligion = "Religion";
  static const String labelRemark = "Remark / Story";
  static const String labelAdvisor = "Advisor";
  static const String labelCaller = "Caller";
  static const String labelReachedBy = "Reached By (Staff)";
  static const String labelVisitingCard = "Visiting Card";

  // Paid Details Labels
  static const String labelAadharCard = "Aadhar Card";
  static const String labelPanCard = "Pan Card";
  static const String labelToken = "Token";
  static const String labelReceiptImage = "Receipt Image";
  static const String labelReceiptDateTime = "Date & Time";
  static const String labelReceiptLeadName = "Lead Name";
  static const String labelNameOnReceipt = "Name on Receipt";
  static const String labelBillingCompany = "Billing Company";
  static const String labelPackageAuto = "Package (Auto)";
  static const String labelReceiptFlatWing = "Flat no. & Wing";
  static const String labelReceiptNo = "Receipt No.";
  static const String labelEMI = "EMI";
  static const String labelStRegGST = "St, Reg., GST";

  // Hidden Details Labels
  static const String labelLeadScore = "Lead Score";
  static const String labelTotalFollowUps = "Total Follow ups";
  static const String labelTotalCalls = "Total Calls";
  static const String labelTotalMsg = "Total Msg";
  static const String labelTotalMeets = "Total Meets";
  static const String labelTotalDays = "Total Days";
  static const String labelReferralScore = "Referral Score for this lead";
  static const String labelAdvisorScore = "Advisor Score for this lead";
  static const String labelCallerScore = "Caller score for this lead";
  static const String labelClosingManagerScore = "Closing Manager Score";
  static const String labelCreatedDateTime = "Created Date Time";
  static const String labelLastEditedDateTime = "Last Edited Date Time";

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

  static const List<String> majorProblemsList = [
    "Load Baring Room", "Big Area", "3 Brothers Joint Family", "Rented Room", "Investment Purpose", "Son Marriage", "Water Issue", "Others"
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
        {
          "id": "source",
          "label": labelLeadSource,
          "type": "dropdown",
          "options": [
            "Referral",
            "Walk In",
            "Digital Marketing",
            "Event",
            "BNI",
            "Just Dial",
            "Housing.com",
            "Poster Marketing",
            "Banner Marketing",
            "Pamphlet Marketing"
          ]
        },
        {"id": "referralName1", "label": labelReferralName1, "type": "cp_dropdown", "visibleIf": "source == Referral"},
        {"id": "referralName2", "label": labelReferralName2, "type": "text", "readOnly": true, "visibleIf": "source == Referral", "hideIf": "role != super_admin"},
        {"id": "referralName3", "label": labelReferralName3, "type": "text", "readOnly": true, "visibleIf": "source == Referral", "hideIf": "role != super_admin"},
        {"id": "propertyType", "label": labelPropertyType, "type": "chips", "options": ["Flat", "Bungalow", "Land", "Others"]},
        {"id": "configuration", "label": labelConfiguration, "type": "chips", "options": ["1BHK", "2BHK", "3BHK", "4BHK", "Others"], "visibleIf": "propertyType == Flat || propertyType == Bungalow"},
        {"id": "status", "label": labelLeadStatus, "type": "chips", "dynamicStatus": true},
        {"id": "isPrivate", "label": labelIsPrivate, "type": "switch", "initialValue": true},
        {"id": "sendProjectDetails", "label": labelSendProjectDetails, "type": "switch", "initialValue": false},
      ]
    },
    {
      "title": sectionClientDetails,
      "fields": [
        {"id": "selectProject", "label": "Select Project", "type": "project_dropdown"},
        {"id": "flatNumber", "label": labelFlatNumber, "type": "text"},
        {"id": "wing", "label": labelWing, "type": "text", "visibleIf": "propertyType != Bungalow && propertyType != Land"},
        {"id": "areaName", "label": labelAreaName, "type": "text"},
        {"id": "landSqFt", "label": labelAreaSqFt, "type": "number"},
        {"id": "downPayment", "label": labelDownPayment, "type": "number"},
        {"id": "flatCost", "label": labelFlatCost, "type": "number"},
        {"id": "ratePerSqFt", "label": labelRatePerSqFt, "type": "number", "readOnly": true},
        {"id": "agreementValue", "label": labelAgreementValue, "type": "number"},
        {"id": "srgAmount", "label": labelSRGAmount, "type": "number", "readOnly": true},
        {"id": "totalPackageAmount", "label": labelTotalPackageAmount, "type": "number", "readOnly": true},
        {"id": "address", "label": labelAddress, "type": "multiline"},
        {"id": "email", "label": labelEmail, "type": "text"},
        {"id": "budget", "label": labelBudget, "type": "number"},
        {"id": "monthlyIncome", "label": labelMonthlyIncome, "type": "number"},
        {"id": "remark", "label": labelRemark, "type": "multiline"},
        {"id": "gender", "label": labelGender, "type": "chips", "options": ["Male", "Female", "Others"]},
      ]
    },
    {
      "title": sectionOtherDetails,
      "fields": [
        {"id": "majorProblem", "label": labelMajorProblem, "type": "autocomplete", "options": majorProblemsList},
        {"id": "majorRequirements", "label": labelMajorRequirements, "type": "multiline"},
        {"id": "preferredLocations", "label": labelPreferredLocations, "type": "text"},
        {"id": "bookingDate", "label": labelBookingDate, "type": "date"},
        {"id": "freeTime", "label": labelFreeTime, "type": "time"},
        {"id": "cameWith", "label": labelCameWith, "type": "text"},
        {"id": "dob", "label": labelDOB, "type": "date"},
        {"id": "tob", "label": labelTOB, "type": "time"},
        {"id": "religion", "label": labelReligion, "type": "autocomplete", "options": commonReligions},
        {"id": "remarkStory", "label": "Remark / Story", "type": "multiline"},
        {"id": "advisor", "label": labelAdvisor, "type": "cp_dropdown"},
        {"id": "caller", "label": labelCaller, "type": "text"},
        {"id": "reachedBy", "label": labelReachedBy, "type": "autocomplete", "options": ["Admin 1", "Admin 2", "Sales 1"]},
        {"id": "visitingCard", "label": labelVisitingCard, "type": "image"},
      ]
    },
    {
      "title": sectionPaidDetails,
      "fields": [
        {"id": "aadharCard", "label": labelAadharCard, "type": "image"},
        {"id": "panCard", "label": labelPanCard, "type": "image"},
        {"id": "token", "label": labelToken, "type": "number"},
        {"id": "receiptImage", "label": labelReceiptImage, "type": "image"},
        {"id": "receiptDateTime", "label": labelReceiptDateTime, "type": "text", "readOnly": true},
        {"id": "receiptLeadName", "label": labelReceiptLeadName, "type": "text"},
        {"id": "nameOnReceipt", "label": labelNameOnReceipt, "type": "text"},
        {"id": "billingCompany", "label": labelBillingCompany, "type": "text"},
        {"id": "packageAuto", "label": labelPackageAuto, "type": "text", "readOnly": true},
        {"id": "receiptFlatWing", "label": labelReceiptFlatWing, "type": "text"},
        {"id": "receiptNo", "label": labelReceiptNo, "type": "text"},
        {"id": "emi", "label": labelEMI, "type": "number"},
        {"id": "coupon", "label": labelCoupon, "type": "switch"},
        {"id": "couponCode", "label": labelCouponCode, "type": "text", "visibleIf": "coupon == Yes"},
        {"id": "stRegGST", "label": labelStRegGST, "type": "text"},
      ]
    },
    {
      "title": sectionHiddenDetails,
      "fields": [
        {"id": "leadScore", "label": labelLeadScore, "type": "text", "readOnly": true},
        {"id": "totalFollowUps", "label": labelTotalFollowUps, "type": "text", "readOnly": true},
        {"id": "totalCalls", "label": labelTotalCalls, "type": "text", "readOnly": true},
        {"id": "totalMsg", "label": labelTotalMsg, "type": "text", "readOnly": true},
        {"id": "totalMeets", "label": labelTotalMeets, "type": "text", "readOnly": true},
        {"id": "totalDays", "label": labelTotalDays, "type": "text", "readOnly": true},
        {"id": "referralScore", "label": labelReferralScore, "type": "text", "readOnly": true},
        {"id": "advisorScore", "label": labelAdvisorScore, "type": "text", "readOnly": true},
        {"id": "callerScore", "label": labelCallerScore, "type": "text", "readOnly": true},
        {"id": "closingManagerScore", "label": labelClosingManagerScore, "type": "text", "readOnly": true},
        {"id": "createdDateTime", "label": labelCreatedDateTime, "type": "text", "readOnly": true},
        {"id": "lastEditedDateTime", "label": labelLastEditedDateTime, "type": "text", "readOnly": true},
      ]
    }
  ];
}
