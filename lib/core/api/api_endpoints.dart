class ApiEndpoints {
  // Auth
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String currentUser = '/users/me';
  static const String me = currentUser;

  // Attendance
  static const String attendanceToday = '/attendance/today';
  static const String checkIn = '/attendance/check-in';
  static const String checkOut = '/attendance/check-out';
  static const String punchIn = checkIn;
  static const String punchOut = checkOut;
  static const String breakStart = '/attendance/break/start';
  static const String breakEnd = '/attendance/break/end';
  static const String attendanceSummary = '/attendance/summary';
  static const String attendanceTeam = '/attendance/team';
  static const String attendanceRecords = '/attendance';
  static const String attendanceLateArrivals = '/attendance/late-arrivals';
  static const String attendanceCorrections = '/attendance/corrections';
  static const String attendanceCorrectionRequest = '/attendance/correction-request';
  static const String attendanceManualAdjust = '/attendance/manual-adjust';
  static const String attendanceRules = '/attendance/rules';
  static const String attendanceSettings = '/attendance/settings';
  static const String attendanceOfficeLocation = '/attendance/office-location';
  static const String attendanceVerifications = '/attendance/verifications';
  static const String shifts = '/shifts';
  static String shiftDetail(String id) => '/shifts/$id';
  static const String shiftAssignments = '/shifts/assignments';
  static String shiftAssignmentDetail(String id) => '/shifts/assignments/$id';

  // Leave
  static const String leaveAll = '/leave';
  static const String leaveMy = '/leave/my';
  static const String leaveApply = '/leave/apply';
  static const String leavePending = '/leave/pending';
  static const String leaveBalances = '/leave/balances';
  static String approveOrRejectLeave(String id) => '/leave/$id/approve-or-reject';

  // Performance
  static const String performanceReviews = '/performance/reviews';
  static String performanceReviewDetail(String id) => '/performance/reviews/$id';
  static const String performanceKpis = '/performance/kpis';
  static const String performanceKpiConfigs = '/performance/kpi-configs';
  static const String myReviews = '/performance/reviews/my';
  static const String myKpis = '/performance/kpis/my';
  static const String myGoals = '/performance/goals/my';
  static const String goalSelfReview = '/performance/goals/self-review';

  // Employee & Management
  static const String employees = '/management/employees';
  static const String employeesAll = '/employees/all';
  static const String hrList = '/management/hr';
  static const String teamLeads = '/management/team-leads';
  static const String assignRole = '/management/assign-role';
  static String employeeDetail(String id) => '/management/employees/$id';
  static String employeeStatus(String id) => '/management/employees/$id/status';
  static String employeeDelete(String id) => '/management/employees/$id';
  static const String users = '/users';
  static String userDetail(String id) => '/users/$id';
  static String userResetPassword(String id) => '/users/$id/reset-password';
  static String userToggleMfa(String id) => '/users/$id/toggle-mfa';
  static const String departments = '/departments';
  static const String departmentsUploadImage = '/departments/upload-image';
  static const String designations = '/designations';
  static const String teams = '/departments/teams';
  static String teamDetail(String id) => '/departments/teams/$id';
  static String teamAssignEmployees(String id) => '/departments/teams/$id/assign-employees';
  static const String branches = '/branches';
  static const String branchUploadImage = '/branches/upload-image';

  // Payroll & Salary
  static const String payroll = '/payroll';
  static const String salaryStructures = '/payroll/salary-structures';
  static const String payrollReport = '/payroll/report';
  static String payrollStatus(String id) => '/payroll/$id/status';
  static String payslipDetail(String id) => '/payroll/payslip/$id';
  static const String myPayslips = '/payroll/payslip/my';
  static const String mySalary = '/salary/my';
  static const String mySalaryHistory = '/salary/my/history';
  static const String teamSalary = '/salary/team';
  static const String salaryEmployees = '/salary/employees';
  static const String payrollInputs = '/payroll/inputs';
  static const String employeeSalaries = '/salary/employees';
  static const String salaryComponents = '/salary/components';
  static String salaryComponentDelete(String id) => '/salary/components/$id';
  static const String payCycles = '/salary/cycles';
  static String payCycleStatus(String id) => '/salary/cycles/$id/status';
  static const String salaryRevisions = '/salary/revisions';
  static const String payrollReports = '/payroll/reports';
  static const String payrollDashboard = '/payroll/dashboard';
  static const String payrollWorkflow = '/payroll/workflow';
  static const String payrollPrepare = '/payroll/prepare';
  static const String payrollPay = '/payroll/pay';
  static const String financeDashboard = '/finance/dashboard';
  static const String financeApprovals = '/finance/approvals';
  static const String financePayments = '/finance/payments';
  static const String financeLoans = '/finance/loans';
  static const String financeReimbursements = '/finance/reimbursements';
  static const String financeReports = '/finance/reports';
  static const String financeTax = '/finance/tax';

  // IT & Assets
  static const String myAssets = '/assets/my';
  static const String assetRequests = '/assets/requests';
  static const String assetMyRequests = '/assets/my/requests';
  static const String itDashboard = '/it/dashboard';
  static const String itAssets = '/it/assets';
  static const String itTickets = '/it/tickets';
  static const String itSoftware = '/it/software';
  static const String itSoftwareMyAssignments = '/it/software/my-assignments';
  static String assetAcknowledge(String id) => '/assets/assignments/$id/acknowledge';

  // Training & Development
  static const String trainingCourses = '/training/courses';
  static String trainingCourseDetail(String id) => '/training/courses/$id';
  static String trainingCoursePublish(String id) => '/training/courses/$id/publish';
  static const String trainingCategories = '/training/categories';

  // Benefits & Expenses
  static const String myBenefits = '/benefits';
  static const String benefitStats = '/benefits/stats';
  static const String benefitPendingClaims = '/benefits/claims/pending-payment';
  static const String benefitClaimsForPayment = '/benefits/claims/for-payment';
  static const String benefitProcessPayment = '/benefits/process-payment';
  static const String benefitPaymentHistory = '/benefits/payments/history';
  static const String benefitUtilization = '/benefits/utilization';
  static const String benefitInvoicesAll = '/benefits/invoices/all';
  // Expenses
  static const String myExpenses = '/expenses/my';
  static const String expenses = '/expenses';
  static const String expenseAll = '/expenses/all';
  static const String expenseInvoicesAll = '/expenses/invoices/all';
  static const String expenseCategories = '/expenses/categories';
  static const String expensePolicies = '/expenses/policies';
  static const String expenseReportsCategory = '/expenses/reports/category';
  static const String expenseReportsStatus = '/expenses/reports/status';
  static const String expenseReportsEmployee = '/expenses/reports/employee';

  // Helpdesk
  static const String helpdeskTickets = '/helpdesk/tickets';
  static const String helpdeskChatbot = '/helpdesk/chatbot';
  static const String helpdeskCategories = '/helpdesk/categories';

  // Announcements
  static const String announcements = '/announcements';

  // Notifications
  static const String notifications = '/notifications';
  static const String notificationsMarkAllRead = '/notifications/mark-all-read';
  static String notificationRead(String id) => '/notifications/$id/read';

  // Recruitment & Candidates
  static const String candidates = '/recruitment/candidates';
  static String candidateDetail(String id) => '/recruitment/candidates/$id';
  static const String jobs = '/recruitment/jobs';
  static String jobDetail(String id) => '/recruitment/jobs/$id';
  static const String interviews = '/recruitment/interviews';
  static String interviewDetail(String id) => '/recruitment/interviews/$id';

  // Documents
  static const String myDocuments = '/documents/mine';
  static const String documents = '/documents';
  static const String documentsUpload = '/documents/upload';
  static String documentsDownload(String id) => '/documents/download/$id';
  static String documentsDelete(String id) => '/documents/$id';

  // Onboarding
  static const String onboarding = '/onboarding';
  static String onboardingDetail(String id) => '/onboarding/$id';
  static String onboardingComplete(String id) => '/onboarding/$id/complete';
  static String onboardingTask(String taskId) => '/onboarding/tasks/$taskId';

  // Organization & Reporting Hierarchy
  static const String reportingHierarchy = '/org/reporting-hierarchy';
  static const String reportingMap = '/org/reporting-map';

  // Projects & Tasks
  static const String projects = '/projects';
  static String projectDetail(String id) => '/projects/$id';
  static String projectMembers(String id) => '/projects/$id/members';
  static String projectMemberDelete(String projectId, String memberId) => '/projects/$projectId/members/$memberId';
  static String projectTeamLead(String id) => '/projects/$id/team-lead';
  static const String myTasks = '/tasks/my';
  static const String myProjects = '/projects/my';
  static const String workUpdates = '/work-updates';
  static const String workUpdatesMy = '/work-updates/my';
  static const String workUpdatesSubmit = '/work-updates/submit';
  static const String workUpdatesTeamToday = '/work-updates/team/today';
  static const String workUpdatesPending = '/work-updates/pending-review';
  static String workUpdatesReview(String id) => '/work-updates/$id/review';

  // System & Admin
  static const String systemSettings = '/system-settings';
  static const String companyProfile = '/system-settings/company-profile';
  static const String emailSmsConfig = '/system-settings/email-sms-config';
  static const String notificationSettings = '/system-settings/notification-preferences';
  static String notificationSettingDetail(String id) => '/system-settings/notification-preferences/$id';
  static const String auditLog = '/AuditLog';
  static const String reportsAuditLogs = '/reports/audit-logs';
  static const String reportsDashboardStats = '/reports/dashboard-stats';
  static const String reportsAttendanceTrend = '/reports/attendance-trend';
  static const String reportsDepartmentDistribution = '/reports/department-distribution';
  static const String reportsPayrollTrend = '/reports/payroll-trend';
  static const String reportsAdminAnalytics = '/reports/admin-analytics';
  static const String reportsHrAnalytics = '/reports/hr-analytics';
  static const String dashboardAttendanceTrend = '/dashboard/monthly-attendance-trend';
  static const String dashboardDepartmentDistribution = '/dashboard/department-distribution';
  static const String dashboardUpcomingBirthdays = '/dashboard/upcoming-birthdays';
  static const String meetingsUpcoming = '/meetings/upcoming';
  static const String meetings = '/meetings';
}
