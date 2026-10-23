# Projeção da equiparação da idade rural

`projecoes.Rmd` reproduz as projeções da planilha em R, com parâmetros editáveis
para idades, referência e regras de transição. O arquivo Excel original é preservado.

## Executar

Requer R, Pandoc e os pacotes `xml2`, `knitr` e `rmarkdown`:

```r
install.packages(c("xml2", "knitr", "rmarkdown"))
# Execute na raiz deste repositório:
rmarkdown::render("projecoes.Rmd")
# Exemplo de alteração das idades e da transição:
rmarkdown::render("projecoes.Rmd", params = list(
  idade_proposta_h = 64, idade_proposta_m = 61,
  duracao_uniforme = 12, intervalo_degraus = 3
), output_file = "cenario_alternativo.html")
```

No RStudio, use Knit ou Knit with Parameters. As seis idades médias de cada sexo
(2020–2025) também são editáveis no YAML. `referencia` aceita `media` ou `minima`.
O relatório explica as entradas, fórmulas, limitações e apresenta tabelas e gráfico.
O motor está em `R/projecoes.R` e pode ser usado sem renderizar o relatório.

O leitor XML importa somente células numéricas sem fórmula. Concessões futuras,
incidências, deflator, regras de idade, esperas e economias são recalculados.
Salário, INPC e população são entradas exógenas literais. Alterar a idade vigente
não substitui a população de 60/55 anos por uma nova série demográfica.

## Validação

```sh
Rscript tests/test_projecoes.R
```

Os valores de referência dos testes são resultados salvos no Excel original;
não entram no cálculo de produção. Os testes comparam os cenários originais,
verificam mudanças de idade e transição e a economia nula quando não há aumento.

## Cenário de 60% elegíveis, ambos os sexos aos 65 anos

```r
rmarkdown::render("cenario_60_porcento.Rmd")
```

A referência mantém as regras atuais, sem reduzir o fluxo de elegíveis. A proposta
aplica `proporcao_elegivel = 0.6` às novas coortes desde 2027 e transição uniforme
de 10 anos, até 2036. O relatório separa economia por adiamento de idade entre os
60% e por exclusão dos outros 40%. O fator incide sobre o fluxo projetado pela
incidência histórica, não diretamente sobre toda a população. Os excluídos não
recebem este benefício em nenhum ano do exercício; o estoque anterior é preservado.
`economia_total_*` inclui os dois efeitos. As antigas colunas `economia_real` e
`economia_nominal` continuam medindo apenas o adiamento entre os elegíveis.

A projeção anual executada com os parâmetros padrão deste cenário está em
`resultados/cenario_60_porcento.csv`, com valores monetários em reais.

## Três cenários em um único relatório

```r
rmarkdown::render("comparacao_tres_cenarios.Rmd")
```

Compara, sempre frente às regras atuais sem restrição adicional de elegibilidade:

1. Homens aos 65 e mulheres aos 62 anos, com 100% elegíveis.
2. Homens e mulheres aos 65 anos, com 100% elegíveis.
3. Homens e mulheres aos 65 anos, com 60% elegíveis.

Todos usam transição uniforme de 10 anos, de 2027 a 2036. O relatório traz três
resumos, projeções anuais, comparação gráfica e premissas. As idades finais,
percentual e parâmetros comuns são editáveis no YAML. Usa o mesmo motor
`R/projecoes.R`; mantenha essa pasta e a planilha ao baixar o repositório.
Ao renderizar, salva `resultados/tres_cenarios_anual.csv` (valores monetários em
reais) e `resultados/tres_cenarios_resumo_bilhoes.csv` (valores em R$ bilhões).
Use `exportar_csv = FALSE` para não gravar os CSVs.

## Projeto BPI

O estudo da base identificada de benefícios, CadÚnico e RAIS está organizado
na pasta [BPI](BPI/README.md), com códigos de referência, esquema de 60 colunas
e um exemplo sintético de 30 linhas e 61 colunas, com gerador reprodutível em R.

## Economia anual de 2027 a 2034

O [recorte dos três cenários](resultados/economia_anual_2027_2034.md) apresenta
a economia de cada ano e o total do período, mantendo a transição de 10 anos.
O CSV correspondente inclui valores reais de 2026 e valores nominais, em bilhões.
