/// Represents persisted Resto U session cookies and validity state.
class SessionCookies {
  final String phpSessId;
  final String? cookieSession1;
  final String? rawCookieHeader;
  final DateTime? lastChecked;

  const SessionCookies({
    required this.phpSessId,
    this.cookieSession1,
    this.rawCookieHeader,
    this.lastChecked,
  });

  /// True if PHPSESSID is present and non-empty.
  bool get isValid => phpSessId.trim().isNotEmpty;

  /// Formats cookies into standard HTTP "Cookie" header string.
  /// Example: "PHPSESSID=8u7eg6s5upp; cookiesession1=678B28B459"
  String toCookieHeader() {
    final parts = <String>['PHPSESSID=${phpSessId.trim()}'];
    if (cookieSession1 != null && cookieSession1!.trim().isNotEmpty) {
      parts.add('cookiesession1=${cookieSession1!.trim()}');
    }
    return parts.join('; ');
  }

  Map<String, dynamic> toJson() => {
        'phpSessId': phpSessId,
        if (cookieSession1 != null) 'cookieSession1': cookieSession1,
        if (rawCookieHeader != null) 'rawCookieHeader': rawCookieHeader,
        if (lastChecked != null) 'lastChecked': lastChecked!.toIso8601String(),
      };

  factory SessionCookies.fromJson(Map<String, dynamic> json) => SessionCookies(
        phpSessId: (json['phpSessId'] as String?)?.trim() ?? '',
        cookieSession1: (json['cookieSession1'] as String?)?.trim(),
        rawCookieHeader: json['rawCookieHeader'] as String?,
        lastChecked: json['lastChecked'] != null
            ? DateTime.tryParse(json['lastChecked'] as String)
            : null,
      );

  SessionCookies copyWith({
    String? phpSessId,
    String? cookieSession1,
    String? rawCookieHeader,
    DateTime? lastChecked,
  }) {
    return SessionCookies(
      phpSessId: phpSessId ?? this.phpSessId,
      cookieSession1: cookieSession1 ?? this.cookieSession1,
      rawCookieHeader: rawCookieHeader ?? this.rawCookieHeader,
      lastChecked: lastChecked ?? this.lastChecked,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionCookies &&
          runtimeType == other.runtimeType &&
          phpSessId == other.phpSessId &&
          cookieSession1 == other.cookieSession1;

  @override
  int get hashCode => phpSessId.hashCode ^ cookieSession1.hashCode;
}
