const _propertyFields =
    'id title city district rooms surfaceM2 price category { title } isTestData description mainImageUrl galleryImageUrls hasVideo videoUrl';

/// Public listings only, for visitors who are not signed in.
const publicListingsQuery = '''
query PublicListings(\$search: String) {
  publicDescriptions(first: 10, search: \$search) { $_propertyFields }
}
''';

const tenantQuery = r'''
query TenantDashboard($search: String) {
  me { username isSeeker isTenant }
  publicDescriptions(first: 10, search: $search) { id title city district rooms surfaceM2 price category { title } isTestData description mainImageUrl galleryImageUrls hasVideo videoUrl }
  myTenantProperties { id title city district rooms surfaceM2 price category { title } isTestData description mainImageUrl galleryImageUrls hasVideo videoUrl }
  myTenantPayments { amount status dueDate }
  myTenantDocuments { title documentType }
  myTenantMaintenanceRequests { title priority status }
  myPropertyInterestRequests { id property { title } status }
  notifications { id title message isRead property { title } interestRequest { id } }
}
''';

const createMaintenanceMutation = r'''
mutation CreateMaintenance($propertyId: ID!, $title: String!, $description: String!, $priority: String) {
  createMaintenanceRequest(propertyId: $propertyId, title: $title, description: $description, priority: $priority) {
    maintenanceRequest { id title description priority status }
  }
}
''';

const createInterestRequestMutation = r'''
mutation CreateInterestRequest($propertyId: ID!, $profession: String!, $salaryRange: String!, $employer: String, $occupantsCount: Int!, $leaseStartDate: Date!, $message: String) {
  createPropertyInterestRequest(propertyId: $propertyId, profession: $profession, salaryRange: $salaryRange, employer: $employer, occupantsCount: $occupantsCount, leaseStartDate: $leaseStartDate, message: $message) {
    interestRequest { id status }
  }
}
''';
