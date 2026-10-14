class FinancialDefaults {
  const FinancialDefaults({this.contribution = 100, this.latePenalty = 0});
  final int contribution;
  final int latePenalty;

  void validate() {
    if (contribution < 0 ||
        latePenalty < 0 ||
        contribution > 1000000000000 ||
        latePenalty > 1000000000000) {
      throw const FormatException(
        'Les montants doivent être des entiers positifs ou nuls.',
      );
    }
  }
}
