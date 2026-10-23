class ApiEndpoints {
  // Auth
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String currentUser = '/users/me';

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

  // Leave
  static const String leaveMy = '/leave/my';
  static const String leaveApply = '/leave/apply';
  static const String leavePending = '/leave/pending';
  static const String leaveBalances = '/leave/balances';
  static String approveOrRejectLeave(String id) => '/leave/$id/approve-or-reject';

  // Employee & Management
  static const String employees = '/management/employees';
  static const String hrList = '/management/hr';
  static const String teamLeads = '/management/team-leads';
  static const String users = '/users';

  // Payroll & Salary
  static const String myPayslips = '/payroll/payslip/my';
  static const String mySalary = '/salary/my';
  static const String teamSalary = '/salary/team';
  static const String salaryEmployees = '/salary/employees';
  static const String salaryStructures = '/salary/structures';
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
  static const String itDashboard = '/it/dashboard';
  static const String itAssets = '/it/assets';
  static const String itTickets = '/it/tickets';
  static const String itSoftware = '/it/software';

  // Benefits & Expenses
  static const String myBenefits = '/benefits';
  static const String benefitStats = '/benefits/stats';
  static const String benefitPendingClaims = '/benefits/claims/pending-payment';
  static const String benefitClaimsForPayment = '/benefits/claims/for-payment';
  static const String benefitProcessPayment = '/benefits/process-payment';
  static const String benefitPaymentHistory = '/benefits/payments/history';
  static const String benefitUtilization = '/benefits/utilization';
  static const String myExpenses = '/expenses';

  // Helpdesk
  static const String helpdeskTickets = '/helpdesk/tickets';
  static const String helpdeskChatbot = '/helpdesk/chatbot';
  static const String helpdeskCategories = '/helpdesk/categories';

  // Announcements
  static const String announcements = '/announcements';

  // Projects & Tasks
  static const String myTasks = '/tasks/my';
  static const String myProjects = '/projects/my';
  static const String workUpdates = '/work-updates/my';

  // System & Admin
  static const String systemSettings = '/system-settings';
  static const String auditLog = '/AuditLog';
  static const String reportsDashboardStats = '/reports/dashboard-stats';
}
