/// Represents student dorm and room assignment details.
class DormInfo {
  final String foyer;
  final String bloc;
  final String chambre;

  const DormInfo({
    required this.foyer,
    required this.bloc,
    required this.chambre,
  });

  const DormInfo.empty()
      : foyer = 'Non assigné',
        bloc = '-',
        chambre = '-';

  bool get hasAssignment =>
      foyer.isNotEmpty && foyer != '-' && foyer != 'Non assigné';

  String get roomDisplay {
    if (!hasAssignment) return 'Non assigné';
    final b = bloc.isNotEmpty && bloc != '-' ? 'Bloc $bloc • ' : '';
    return '${b}Ch. $chambre';
  }

  Map<String, dynamic> toJson() => {
        'foyer': foyer,
        'bloc': bloc,
        'chambre': chambre,
      };

  factory DormInfo.fromJson(Map<String, dynamic> json) => DormInfo(
        foyer: (json['foyer'] as String?)?.trim() ?? 'Non assigné',
        bloc: (json['bloc'] as String?)?.trim() ?? '-',
        chambre: (json['chambre'] as String?)?.trim() ?? '-',
      );

  DormInfo copyWith({
    String? foyer,
    String? bloc,
    String? chambre,
  }) {
    return DormInfo(
      foyer: foyer ?? this.foyer,
      bloc: bloc ?? this.bloc,
      chambre: chambre ?? this.chambre,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DormInfo &&
          runtimeType == other.runtimeType &&
          foyer == other.foyer &&
          bloc == other.bloc &&
          chambre == other.chambre;

  @override
  int get hashCode => foyer.hashCode ^ bloc.hashCode ^ chambre.hashCode;
}

/// Represents the authenticated student profile and housing information.
class StudentProfile {
  final String fullName;
  final String cin;
  final DormInfo dorm;

  const StudentProfile({
    required this.fullName,
    required this.dorm,
    this.cin = '',
  });

  const StudentProfile.empty()
      : fullName = 'Étudiant',
        cin = '',
        dorm = const DormInfo.empty();

  String get firstName {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    return parts.isNotEmpty ? parts.first : fullName;
  }

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'ET';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'cin': cin,
        'dorm': dorm.toJson(),
      };

  factory StudentProfile.fromJson(Map<String, dynamic> json) => StudentProfile(
        fullName: (json['fullName'] as String?)?.trim() ?? 'Étudiant',
        cin: (json['cin'] as String?)?.trim() ?? '',
        dorm: json['dorm'] != null
            ? DormInfo.fromJson(json['dorm'] as Map<String, dynamic>)
            : const DormInfo.empty(),
      );

  StudentProfile copyWith({
    String? fullName,
    String? cin,
    DormInfo? dorm,
  }) {
    return StudentProfile(
      fullName: fullName ?? this.fullName,
      cin: cin ?? this.cin,
      dorm: dorm ?? this.dorm,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentProfile &&
          runtimeType == other.runtimeType &&
          fullName == other.fullName &&
          cin == other.cin &&
          dorm == other.dorm;

  @override
  int get hashCode => fullName.hashCode ^ cin.hashCode ^ dorm.hashCode;
}
