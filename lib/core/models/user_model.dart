// ignore_for_file: constant_identifier_names

enum UserRole {
  ADMIN,
  HR,
  TL,
  EMPLOYEE,
  IT,
  FINANCE,
  HELPDESK,
  UNAUTHORIZED;
//user model

  static UserRole fromString(String? role) {
    if (role == null) return UserRole.UNAUTHORIZED;
    final cleanRole = role.trim().toUpperCase();
    switch (cleanRole) {
      case 'ADMIN':
      case 'SUPERADMIN':
      case 'SUPER_ADMIN':
      case 'SYSTEM_ADMIN':
      case 'SYSTEM ADMIN':
      case 'SYSTEMADMIN':
        return UserRole.ADMIN;
      case 'HR':
      case 'HR_ADMIN':
      case 'HRADMIN':
      case 'HR_MANAGER':
        return UserRole.HR;
      case 'TL':
      case 'TEAMLEAD':
      case 'TEAM_LEAD':
      case 'TEAM LEAD':
        return UserRole.TL;
      case 'IT':
      case 'IT_ADMIN':
      case 'IT ADMIN':
        return UserRole.IT;
      case 'FINANCE':
      case 'FINANCE_ADMIN':
      case 'FINANCE ADMIN':
        return UserRole.FINANCE;
      case 'HELPDESK':
      case 'HELPDESK_ADMIN':
      case 'HELPDESK ADMIN':
        return UserRole.HELPDESK;
      case 'EMPLOYEE':
        return UserRole.EMPLOYEE;
      default:
        return UserRole.UNAUTHORIZED;
    }
  }

  String toFormattedString() {
    switch (this) {
      case UserRole.ADMIN:
        return 'Admin';
      case UserRole.HR:
        return 'HR';
      case UserRole.TL:
        return 'Team Lead';
      case UserRole.IT:
        return 'IT';
      case UserRole.FINANCE:
        return 'Finance';
      case UserRole.HELPDESK:
        return 'Helpdesk';
      case UserRole.EMPLOYEE:
        return 'Employee';
      case UserRole.UNAUTHORIZED:
        return 'Unauthorized';
    }
  }
}

class UserModel {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final UserRole role;
  final String? avatar;
  final String? department;
  final String? designation;
  final String? branch;
  final String? employeeId;
  final String? phone;

  UserModel({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.avatar,
    this.department,
    this.designation,
    this.branch,
    this.employeeId,
    this.phone,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? json['userId']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      firstName: json['firstName']?.toString() ?? json['first_name']?.toString() ?? '',
      lastName: json['lastName']?.toString() ?? json['last_name']?.toString() ?? '',
      role: UserRole.fromString(json['role']?.toString()),
      avatar: json['avatar']?.toString() ?? json['profilePictureUrl']?.toString(),
      department: json['department']?.toString(),
      designation: json['designation']?.toString(),
      branch: json['branch']?.toString(),
      employeeId: json['employeeId']?.toString() ?? json['employee_id']?.toString(),
      phone: json['phone']?.toString() ?? json['phoneNumber']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'role': role.name,
      'avatar': avatar,
      'department': department,
      'designation': designation,
      'branch': branch,
      'employeeId': employeeId,
      'phone': phone,
    };
  }
}
