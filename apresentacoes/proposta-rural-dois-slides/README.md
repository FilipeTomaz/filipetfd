# Proteção ao idoso rural: proposta em dois slides

[PowerPoint com gráfico editável](Proposta_protecao_rural_2_slides.pptx) ·
[PDF de duas páginas](Proposta_protecao_rural_2_slides.pdf) ·
[Dados do gráfico](trajetorias_despesa.csv)

## Conteúdo

1. **Desenho da proposta:** encerrar, para novos ingressos, a via rural sem
   contribuição individual mensal; preservar contribuições e direitos adquiridos
   de quem contribuiu ao INSS, aplicando a regra urbana aos novos ingressos;
   estabelecer transição de dez anos para a proteção assistencial via BPC,
   condicionada à renda e aos demais requisitos.
2. **Gráfico de despesa:** regra atual H60/M55 versus o **cenário base original
   H65/M62**, conforme a escolha do usuário. Transição de 2027 a 2036,
   mantendo **13 pagamentos anuais e 100% do fluxo elegível** nos dois caminhos.

As justificativas são distinguir seguro previdenciário e assistência,
reconhecer as contribuições e os direitos adquiridos, alinhar as regras
previdenciárias e focalizar a assistência nos idosos de baixa renda.

## O que foi revisado nas premissas

- **“Não contributiva” exige cuidado:** o segurado especial pode contribuir
  sobre a receita da comercialização da produção. Por isso, o slide usa
  “sem contribuição individual mensal”, sem afirmar ausência de custeio.
- **Direito adquirido não se confunde com requisito futuro:** a proposta
  preserva benefícios já concedidos, contribuições e direitos adquiridos;
  novos requerimentos obedeceriam à regra urbana aplicável.
- **Idade urbana e idade do BPC são diferentes:** na referência geral da
  aposentadoria programada urbana, homens aos 65 e mulheres aos 62;
  no BPC ao idoso, 65 anos para ambos. Há regras previdenciárias específicas
  e de transição que devem ser respeitadas.
- **BPC não é acesso automático nem aposentadoria:** exige os critérios
  assistenciais pertinentes, não paga 13º e não gera pensão por morte.
  A passagem da previdência rural para essa via integra o desenho proposto;
  sua implementação exigiria alteração legal.

## Alcance do cálculo: foi mantido o cenário base original

Nenhuma projeção foi refeita ou alterada. A fonte é
`resultados/tres_cenarios_anual.csv`, exclusivamente as 34 linhas
`exercicio == "base_65_62"`. As duas despesas reais foram obtidas dos
pagamentos existentes, multiplicados pelo salário e divididos pelo deflator
da mesma linha; a exibição divide os valores por um bilhão.

| Indicador | R$ bilhões de 2026 |
|---|---:|
| Despesa da regra atual em 2060 | 527,803 |
| Despesa do cenário base em 2060 | 445,034 |
| Diferença anual em 2060 | 82,768 |
| Diferença acumulada de 2027 a 2060 | 2.026,357 |

**O gráfico quantifica apenas a etapa de equiparação das idades. Não mede
o custo completo da proposta descrita no primeiro slide.** O cenário base
mantém 13 pagamentos e 100% de elegibilidade: não quantifica a migração ao
BPC, a retirada do 13º, um filtro de renda ou o fator de 60% do cenário
posterior. O modelo não separa os segurados por histórico contributivo.

As despesas incluem apenas as coortes de referência desde 2027. O estoque
anterior é preservado e fica fora da comparação. Os valores não são o
orçamento consolidado de toda a previdência rural e do BPC. A população,
salário, INPC, incidência e idade média da referência são os do modelo
original. Não há mortalidade, cessação ou migração para outros benefícios.
A diferença acumulada está em reais de 2026, sem desconto financeiro adicional.

As notas do PowerPoint também registram essas distinções. O gráfico contém
somente as duas trajetórias solicitadas, sem os outros cenários históricos.

## Fontes oficiais da revisão

Consultadas em 18/11/2026:

- [INSS — Aposentadoria programada](https://www.gov.br/inss/pt-br/direitos-e-deveres/aposentadorias/aposentadoria-programada)
- [INSS — BPC à pessoa idosa](https://www.gov.br/inss/pt-br/direitos-e-deveres/beneficios-assistenciais/beneficio-assistencial-a-pessoa-idosa-bpc-loas)
- [INSS — Contribuição do segurado especial](https://www.gov.br/inss/pt-br/direitos-e-deveres/inscricao-e-contribuicao/contribuicao-do-segurado-especial)

## Reproduzir

```sh
python apresentacoes/proposta-rural-dois-slides/gerar_apresentacao.py
```

Requer `python-pptx`, `reportlab`, `matplotlib`, `numpy` e a fonte DejaVu Sans.
Não executa R nem sobrescreve as apresentações anteriores ou os resultados.
O PowerPoint contém um gráfico nativo editável, com duas séries de 34 pontos.
Também são gerados PDF, PNG/SVG do gráfico, CSV de conferência e metadados
com o hash SHA-256 da fonte e a identificação do cenário.
