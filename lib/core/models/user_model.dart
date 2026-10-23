// ignore_for_file: constant_identifier_names

enum UserRole {
  ADMIN,
  HR,
  TL,
  EMPLOYEE,
  IT,
  FINANCE,
  HELPDESK;

  static UserRole fromString(String? role) {
    if (role == null) return UserRole.EMPLOYEE;
    final cleanRole = role.trim().toUpperCase();
    switch (cleanRole) {
      case 'ADMIN':
        return UserRole.ADMIN;
      case 'HR':
        return UserRole.HR;
      case 'TL':
      case 'TEAMLEAD':
      case 'TEAM_LEAD':
        return UserRole.TL;
      case 'IT':
        return UserRole.IT;
      case 'FINANCE':
        return UserRole.FINANCE;
      case 'HELPDESK':
        return UserRole.HELPDESK;
      case 'EMPLOYEE':
      default:
        return UserRole.EMPLOYEE;
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
