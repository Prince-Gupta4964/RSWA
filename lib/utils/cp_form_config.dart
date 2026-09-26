class CPFormStrings {
  // --- SECTION TITLES ---
  static const String sectionBasicInfo = "Basic Info";
  static const String sectionCPDetails = "CP Details";
  static const String sectionScore = "Score";
  static const String sectionLoginCredentials = "Login Credentials";

  // --- AUTOCOMPLETE DATA ---
  static const List<String> partnerTypes = [
    "RP", "CP", "Pro CP", "Investor", "Builder", "Land Owner"
  ];

  static const List<String> sources = [
    'Walk In', 'Referral', 'Event', 'Digital Marketing', 'Banner Marketing', 
    'Poster Marketing', 'Pamphlet Marketing', 'Seminar', 'Facebook', 
    'Instagram', 'Youtube', 'Justdial', 'Website', 'IVR', 'Others'
  ];

  static const List<String> statusTiers = [
    "Scout (1%)", "Referral Partner", "Verified Referral (2%)", "Registered Referral (3%)",
    "Active Partner", "Channel Partner", "Elite CP", "Strategic CP", "Brand Advocate", "Alliance Partner (5%)"
  ];

  // --- DYNAMIC SEQUENCE & STRUCTURE ---
  static const List<Map<String, dynamic>> formStructure = [
    {
      "title": sectionBasicInfo,
      "fields": [
        {
          "type": "row",
          "fields": [
            {"id": "cpID", "label": "Partner ID", "type": "text", "readOnly": true},
            {"id": "timestamp", "label": "Date Time", "type": "text", "readOnly": true},
          ]
        },
        {"id": "partnerType", "label": "Type", "type": "chips", "options": partnerTypes, "isRequired": true},
        {
          "type": "row",
          "fields": [
            {"id": "cpName", "label": "Name", "type": "text", "isRequired": true},
            {"id": "surname", "label": "Surname", "type": "text"},
          ]
        },
        {"id": "companyName", "label": "Company Name", "type": "autocomplete"},
        {"id": "contactNo", "label": "WhatsApp No.", "type": "phone", "isRequired": true},
        {"id": "contact2", "label": "Contact 2", "type": "phone"},
        {"id": "email", "label": "Email", "type": "text"},
        {"id": "source", "label": "Source", "type": "dropdown", "options": sources},
        {"id": "referralName1", "label": "Referral Name 1 (3%)", "type": "text", "visibleIf": "source == Referral"},
        {"id": "referralName2", "label": "Referral Name 2 (1%)", "type": "text", "readOnly": true},
        {"id": "referralName3", "label": "Referral Name 3 (0.5%)", "type": "text", "readOnly": true},
        {"id": "nearestStation", "label": "Nearest Station", "type": "text"},
        {"id": "sendReferralLink", "label": "Send Referral Link", "type": "switch"},
      ]
    },
    {
      "title": sectionCPDetails,
      "fields": [
        {"id": "status", "label": "Status", "type": "chips", "options": statusTiers, "roles": ["admin", "super_admin"]},
        {"id": "tag", "label": "Tag", "type": "text", "roles": ["admin", "super_admin"]},
        {"id": "nickName", "label": "Nick Name", "type": "text"},
        {"id": "gender", "label": "Gender", "type": "chips", "options": ["Male", "Female", "Other"]},
        {"id": "address", "label": "Address", "type": "multiline"},
        {"id": "workLocation", "label": "Work Location", "type": "text"},
        {"id": "qualification", "label": "Qualification", "type": "text"},
        {"id": "reraId", "label": "Rera Number", "type": "text"},
        {"id": "experience", "label": "Total Experience", "type": "text"},
        {
          "type": "row",
          "fields": [
            {"id": "joinedDate", "label": "Joined A Tech on", "type": "text", "readOnly": true},
            {"id": "yearsCompleted", "label": "Years Completed", "type": "text", "readOnly": true},
          ]
        },
        {"id": "profilePhoto", "label": "Photo", "type": "image"},
        {"id": "visitingCard", "label": "Visiting Card", "type": "image"},
        {"id": "aadharCard", "label": "Aadhar Card", "type": "image"},
        {"id": "panCard", "label": "Pan Card", "type": "image"},
        {"id": "advisor", "label": "Advisor", "type": "text"},
        {"id": "caller", "label": "Caller", "type": "text"},
        {"id": "reachedBy", "label": "Reached By (Staff)", "type": "text"},
      ]
    },
    {
      "title": sectionScore,
      "roles": ["admin", "super_admin"],
      "fields": [
        {"id": "approveMembership", "label": "Approve Membership", "type": "switch"},
        {"id": "membershipStatus", "label": "Membership Status (Active)", "type": "text", "readOnly": true},
        {"id": "membershipPackage", "label": "Membership Package", "type": "text", "readOnly": true},
        {"id": "membershipFees", "label": "Membership Fees (30k)", "type": "text"},
        {"id": "level", "label": "Level - Scout, CP etc", "type": "text", "readOnly": true},
        {"id": "totalCPContributed", "label": "Total CP Contributed", "type": "number", "readOnly": true},
        {"id": "contributedCPWorth", "label": "Contributed CP Worth", "type": "text"},
        {"id": "clientsAdded", "label": "Clients Added", "type": "number", "readOnly": true},
        {"id": "clientsVisits", "label": "Clients Visits", "type": "number"},
        {"id": "clientsToken", "label": "Clients Token", "type": "number"},
        {"id": "clientsRegistrationDone", "label": "Clients Registration Done", "type": "number"},
        {"id": "projectsWorkedOn", "label": "Projects Worked On", "type": "number"},
        {"id": "investorsWorkedOn", "label": "Investors Worked On", "type": "number"},
        {"id": "investorsConverted", "label": "Investors Converted", "type": "number"},
        {"id": "currentNetwork", "label": "Current Network", "type": "text"},
        {"id": "reviewByClients", "label": "Review By Clients", "type": "multiline"},
        {"id": "reviewByColleagues", "label": "Review by Collegues", "type": "multiline"},
        {"id": "reviewByStaff", "label": "Review By Staff", "type": "multiline"},
        {"id": "createdByLabel", "label": "Created By", "type": "text", "readOnly": true},
        {"id": "lastEditedBy", "label": "Last Edited By", "type": "text", "readOnly": true},
      ]
    },
    {
      "title": sectionLoginCredentials,
      "fields": [
        {"id": "email_login", "label": "Login Email", "type": "text"},
        {"id": "password", "label": "Login Password", "type": "text"},
      ]
    }
  ];
}
