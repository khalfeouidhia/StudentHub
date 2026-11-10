/// Represents student wallet balances and monthly transaction metrics.
class WalletKpis {
  final int soldeRepas;
  final int totalAchatMois;
  final double depensesMois;
  final String currency;

  const WalletKpis({
    required this.soldeRepas,
    required this.totalAchatMois,
    required this.depensesMois,
    this.currency = 'DT',
  });

  const WalletKpis.empty()
      : soldeRepas = 0,
        totalAchatMois = 0,
        depensesMois = 0.0,
        currency = 'DT';

  bool get hasBalance => soldeRepas > 0;
  bool get isLowBalance => soldeRepas <= 3;

  String get formattedDepenses =>
      '${depensesMois.toStringAsFixed(3)} $currency';

  Map<String, dynamic> toJson() => {
        'soldeRepas': soldeRepas,
        'totalAchatMois': totalAchatMois,
        'depensesMois': depensesMois,
        'currency': currency,
      };

  factory WalletKpis.fromJson(Map<String, dynamic> json) => WalletKpis(
        soldeRepas: (json['soldeRepas'] as num?)?.toInt() ?? 0,
        totalAchatMois: (json['totalAchatMois'] as num?)?.toInt() ?? 0,
        depensesMois: (json['depensesMois'] as num?)?.toDouble() ?? 0.0,
        currency: (json['currency'] as String?) ?? 'DT',
      );

  WalletKpis copyWith({
    int? soldeRepas,
    int? totalAchatMois,
    double? depensesMois,
    String? currency,
  }) {
    return WalletKpis(
      soldeRepas: soldeRepas ?? this.soldeRepas,
      totalAchatMois: totalAchatMois ?? this.totalAchatMois,
      depensesMois: depensesMois ?? this.depensesMois,
      currency: currency ?? this.currency,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WalletKpis &&
          runtimeType == other.runtimeType &&
          soldeRepas == other.soldeRepas &&
          totalAchatMois == other.totalAchatMois &&
          depensesMois == other.depensesMois &&
          currency == other.currency;

  @override
  int get hashCode =>
      soldeRepas.hashCode ^
      totalAchatMois.hashCode ^
      depensesMois.hashCode ^
      currency.hashCode;
}
