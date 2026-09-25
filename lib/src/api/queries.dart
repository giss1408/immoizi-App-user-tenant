const _propertyFields =
    'id title city district rooms surfaceM2 price rentalType weeklyPrice category { title } isTestData description mainImageUrl galleryImageUrls hasVideo videoUrl';

/// Public listings only, for visitors who are not signed in.
const publicListingsQuery = '''
query PublicListings(\$search: String, \$rentalType: String) {
  publicDescriptions(first: 20, search: \$search, rentalType: \$rentalType) { $_propertyFields }
}
''';

const tenantQuery = '''
query TenantDashboard(\$search: String, \$rentalType: String) {
  me { username isSeeker isTenant }
  publicDescriptions(first: 20, search: \$search, rentalType: \$rentalType) { $_propertyFields }
  myTenantProperties { $_propertyFields }
  myTenantPayments { amount status dueDate }
  myTenantDocuments { title documentType }
  myTenantMaintenanceRequests { title priority status }
  myPropertyInterestRequests { id property { id title } status isExpired expiresAt createdAt }
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
