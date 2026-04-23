enum PessoaTipoVinculo {
  interno('interno', 'Interno'),
  externo('externo', 'Externo');

  const PessoaTipoVinculo(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static PessoaTipoVinculo fromApi(dynamic value) {
    final normalizado = (value ?? '').toString().trim().toLowerCase();
    for (final tipo in values) {
      if (tipo.apiValue == normalizado) return tipo;
    }
    return PessoaTipoVinculo.interno;
  }
}
