# Economia anual dos três cenários: 2027–2034

Valores em **R$ bilhões de 2026**. Cada linha é a economia daquele ano;
a última linha é o total acumulado no período.

| Ano | H65/M62 — 100% | H65/M65 — 100% | H65/M65 — 60% |
|---|---:|---:|---:|
| 2027 | 0,000 | 0,000 | 0,065 |
| 2028 | 1,178 | 2,088 | 2,988 |
| 2029 | 5,352 | 8,483 | 10,364 |
| 2030 | 11,134 | 15,847 | 18,623 |
| 2031 | 17,457 | 23,701 | 27,418 |
| 2032 | 23,965 | 32,109 | 36,820 |
| 2033 | 30,981 | 40,905 | 46,624 |
| 2034 | 38,620 | 50,242 | 57,012 |
| **Total 2027–2034** | **128,687** | **173,373** | **199,916** |

Referência comum: regras atuais H60/M55, com idade média efetiva de concessão,
sem restrição adicional de elegibilidade. As três propostas mantêm transição
uniforme de 10 anos, de 2027 a 2036; o recorte termina em 2034 sem antecipar o fim
da transição. O terceiro cenário mantém apenas 60% do fluxo elegível e exclui
permanentemente os demais 40% deste benefício, preservando as coortes anteriores.

Em 2027 não há economia por aumento de idade, dada a defasagem efetiva da regra
atual. O terceiro cenário tem economia nesse ano somente pela exclusão dos 40%.
Os totais são calculados antes do arredondamento das linhas.

O [CSV](economia_anual_2027_2034.csv) contém a comparação anual real e nominal,
ambas em bilhões; as colunas terminadas em `_real_bi` usam reais de 2026, e as
terminadas em `_nominal_bi` usam os preços de cada ano.

Os valores foram recalculados em R a partir das entradas literais do Excel e
conferidos contra o resultado de horizonte completo. Para renderizar o relatório
existente com esse horizonte, sem sobrescrever os CSVs anteriores:

```r
rmarkdown::render("comparacao_tres_cenarios.Rmd",
  params = list(fim = 2034, exportar_csv = FALSE),
  output_file = "comparacao_2027_2034.html")
```
