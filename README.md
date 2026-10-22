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
