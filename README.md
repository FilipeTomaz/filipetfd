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
