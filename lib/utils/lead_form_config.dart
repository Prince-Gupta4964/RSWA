class LeadFormStrings {
  // --- FIELD LABELS ---
  static const String labelCompany = "Select Company";
  static const String labelSubCompany = "Sub Company";
  static const String labelName = "Name (Insights)";
  static const String labelSurname = "Surname (Insights)";
  static const String labelProfession = "Profession";
  static const String labelContact1 = "Contact 1 (Numerology)";
  static const String labelContact2 = "Contact 2";
  static const String labelNearestStation = "Nearest Station";
  static const String labelAddress = "Address";

  static const String labelLeadType = "Lead Type";
  static const String labelLeadStatus = "Lead Status";
  static const String labelLeadSource = "Lead Source";
  static const String labelReferralName = "Referral Name (Ref from CP)";

  static const String labelEmail = "Email";
  static const String labelGender = "Gender";
  static const String labelNowLivingIn = "Now Living In";
  static const String labelPropertyType = "Needs Property Type";
  static const String labelWing = "Wing";
  static const String labelFlatNumber = "Flat / Bungalow Number";
  static const String labelLandSqFt = "Land In Sq ft";
  static const String labelBudget = "Budget";
  static const String labelDownPayment = "Down Payment";
  static const String labelRatePerSqFt = "Rate per sq ft";
  static const String labelFinalAmount = "Final Amount";
  static const String labelGSRAmount = "GSR Amount";
  static const String labelDemoDone = "Demo Done";
  static const String labelDemoBy = "Demo By";
  static const String labelDemoType = "Demo Type";
  static const String labelDOB = "Date of Birth (Astro)";
  static const String labelTOB = "Time of Birth";
  static const String labelRemark = "Remark / Story";

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

  // --- DYNAMIC SEQUENCE & STRUCTURE ---
  static const List<Map<String, dynamic>> formStructure = [
    {
      "title": "Basic Info",
      "fields": [
        {"id": "company", "label": labelCompany, "type": "project_dropdown"},
        {"id": "subCompany", "label": labelSubCompany, "type": "project_dropdown"},
        {
          "type": "row",
          "fields": [
            {"id": "name", "label": labelName, "type": "text"},
            {"id": "surname", "label": labelSurname, "type": "autocomplete", "options": commonSurnames},
          ]
        },
        {"id": "profession", "label": labelProfession, "type": "autocomplete", "options": commonProfessions},
        {"id": "contact1", "label": labelContact1, "type": "phone_plus"},
        {"id": "contact2", "label": labelContact2, "type": "phone_hidden"},
        {"id": "nearestStation", "label": labelNearestStation, "type": "autocomplete", "options": commonStations},
        {"id": "address", "label": labelAddress, "type": "multiline"},
      ]
    },
    {
      "title": "Lead Details",
      "fields": [
        {"id": "leadType", "label": labelLeadType, "type": "chips", "options": ["Client", "RP", "CP", "Pro CP", "Investor", "Builder"]},
        {"id": "status", "label": labelLeadStatus, "type": "chips", "dynamicStatus": true},
        {"id": "source", "label": labelLeadSource, "type": "dropdown", "options": ["Referral", "Walk In", "Digital Marketing", "Event", "BNI", "Just Dial", "Housing.com", "Poster Marketing", "Banner Marketing", "Pamphlet Marketing"]},
        {"id": "referralName", "label": labelReferralName, "type": "cp_dropdown", "visibleIf": "source == Referral"},
      ]
    },
    {
      "title": "Other Details",
      "fields": [
        {"id": "email", "label": labelEmail, "type": "text"},
        {"id": "gender", "label": labelGender, "type": "chips", "options": ["Male", "Female", "Others"]},
        {"id": "livingIn", "label": labelNowLivingIn, "type": "text"},
        {"id": "propertyType", "label": labelPropertyType, "type": "chips", "options": ["1RK", "1BHK", "2BHK", "3BHK", "4BHK", "5BHK", "Bungalow", "Land"]},
        {
          "type": "row",
          "fields": [
            {"id": "wing", "label": labelWing, "type": "text"},
            {"id": "flatNumber", "label": labelFlatNumber, "type": "text"},
          ]
        },
        {"id": "landSqFt", "label": labelLandSqFt, "type": "number"},
        {"id": "budget", "label": labelBudget, "type": "text"},
        {"id": "downPayment", "label": labelDownPayment, "type": "text"},
        {"id": "ratePerSqFt", "label": labelRatePerSqFt, "type": "number"},
        {
          "type": "row",
          "fields": [
            {"id": "finalAmount", "label": labelFinalAmount, "type": "number"},
            {"id": "gsrAmount", "label": labelGSRAmount, "type": "number"},
          ]
        },
        {"id": "demoDone", "label": labelDemoDone, "type": "chips", "options": ["Y", "N"]},
        {"id": "demoBy", "label": labelDemoBy, "type": "text"},
        {"id": "demoType", "label": labelDemoType, "type": "text"},
        {"id": "dob", "label": labelDOB, "type": "date"},
        {"id": "tob", "label": labelTOB, "type": "time"},
        {"id": "remark", "label": labelRemark, "type": "multiline"},
      ]
    }
  ];
}
