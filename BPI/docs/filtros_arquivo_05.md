# Novo chunk do arquivo 05: filiação e renda familiar

A versão de trabalho está em `../05_especies_clientela_renda_tempo.Rmd`.
O arquivo recebido em `../referencia/codigos/05_especies_clientela_renda_tempo.Rmd`
continua preservado. A seção **3.1**, chunk `classificacao_tipo_renda_familia`,
acrescenta os filtros e classificações solicitados. As demais tabelas do relatório
mantêm o universo original de espécies 21, 41 e 88.

## Qual variável distingue segurado especial?

O roteiro 00.3 extrai `filiacao_codigo` e `filiacao_nome` das posições 13 e 14 de
Concedidos. **Filiação não consta das 61 colunas integradas.** O chunk utiliza:

1. `filiacao_nome`/`filiacao_codigo`, se já estiverem na base; ou
2. CSV/Parquet auxiliar com NB único e esses campos, ligado pela chave de benefício.

O [modelo de cabeçalho](../esquemas/filiacao_aux_modelo.csv) não tem registros.
Preencha a auxiliar local com a filiação recuperada dos Concedidos e informe seu
caminho em `arquivo_filiacao_aux`. É possível usar só nome ou só código; para
classificar apenas por código, preencha `codigos_especial` com códigos confirmados
na fonte. Não foram inventados códigos numéricos oficiais de segurado especial.

O recorte antigo 00.3 é de aposentadoria rural de 2026. Uma auxiliar produzida
somente com esse recorte não classifica automaticamente as demais espécies/anos.
Os NBs sem correspondência continuam com filiação não informada.

Classificações:

- **Segurado especial:** descrição explicitamente mapeada, sem inferência por clientela.
- **Demais categorias de filiação:** outra descrição de filiação informada.
- **Não informado/não classificado:** ausência ou código sem mapeamento.
- **Não se aplica (BPC):** espécie 88.

O par código/nome presente na base integrada tem prioridade sobre o par da
auxiliar. Não se mistura o nome de uma origem com o código de outra. Quando um
código configurado como especial acompanha outra descrição informada, o registro
fica não classificado até conferir o domínio e ajustar o mapeamento.

Os nomes-padrão são `SEGURADO ESPECIAL` e `SEGURADA ESPECIAL`, editáveis no YAML.
A tabela de domínio mostra os valores encontrados antes dos filtros, sem NB/CPF.
Na pensão, é necessário confirmar a que pessoa se refere a filiação da fonte.

## Classificações familiares

O salário mínimo de referência é **R$ 1.412, de 2024**, ano da fotografia CadÚnico.
Não se substitui esse valor pelo mínimo de outro ano sem alterar explicitamente o
parâmetro. As faixas são para análise, não classificação jurídica de elegibilidade.

| Variável | Interpretação | Faixas padrão |
|---|---|---|
| `vl_renda_media_fam` | Renda familiar per capita em reais | zero; até 1/4 SM; >1/4 até 1/2; >1/2 até 1; >1 até 2; >2 SM |
| `vl_renda_total_fam` | Renda familiar total em reais | zero; até 1 SM; >1 até 2; >2 até 3; >3 até 5; >5 SM |
| `qt_membro_familia` | Quantidade de membros | 1; 2; 3; 4; 5 ou mais |

Ausências têm categoria própria, sem serem convertidas em zero. Rendas negativas,
valores não finitos e tamanhos familiares menores que 1 ou fracionários ficam como
inválidos. Os filtros numéricos ativos excluem esses valores. As médias/medianas
usam valores válidos; as contagens de preenchimento contam valores não nulos.

As contagens são por NB: não equivalem a pessoas ou famílias distintas. Renda
CadÚnico pode incluir o benefício e não corresponde necessariamente à concessão.

## Executar e mudar filtros

Abra `BPI.Rproj`. O relatório usa os pacotes DBI, duckdb, data.table, knitr e
rmarkdown, além do Pandoc fornecido normalmente pelo RStudio:

```r
install.packages(c("DBI", "duckdb", "data.table", "knitr", "rmarkdown"))
rmarkdown::render("05_especies_clientela_renda_tempo.Rmd")
```

Por padrão, lê a base identificada no computador do usuário:
`E:/01_Bases/09_PREVIDENCIA/04_Dados/Saidas/banco_beneficio_cad_rais.parquet`.
A variável `pasta` acompanha esse diretório nas exportações opcionais (desativadas
por padrão). Não há filtros numéricos ativos por padrão. Sem auxiliar, a filiação
fica não classificada; não são atribuídas categorias fictícias à base.

Mantenha o Rmd na pasta `BPI`, junto da pasta `R` que contém `filtros_05.R`.
O arquivo de esquema CSV só é necessário quando a fonte escolhida for CSV.
Para voltar ao exemplo sintético, faça a seleção explícita:

```r
rmarkdown::render("05_especies_clientela_renda_tempo.Rmd", params = list(
  arquivo_base = "dados/sinteticos/bpi_sintetico_61.csv"
))
```

Exemplo com o Parquet real e limites de renda/tamanho, mantendo todos os tipos:

```r
rmarkdown::render("05_especies_clientela_renda_tempo.Rmd", params = list(
  arquivo_base = "E:/caminho/banco_beneficio_cad_rais.parquet",
  renda_pc_max = 353,
  renda_total_max = 1412,
  membros_min = 2,
  membros_max = 4
))
```

Exemplo restrito a segurados especiais rurais, após disponibilizar a filiação:

```r
rmarkdown::render("05_especies_clientela_renda_tempo.Rmd", params = list(
  arquivo_base = "E:/caminho/banco_beneficio_cad_rais.parquet",
  arquivo_filiacao_aux = "E:/caminho/filiacao_por_nb.parquet",
  tipo_segurado = "Segurado especial",
  clientela_codigos = "2",
  renda_pc_max = 706
))
```

Os limites são inclusivos e aceitam `null` no YAML para desativar. Se houver limite
ativo, ausências não passam, salvo `incluir_ausentes_nos_filtros: true`. O relatório
mostra o total antes/depois, resumo por filiação, três distribuições familiares e
o cruzamento das três faixas. Percentuais usam o grupo filtrado como denominador.
Mostram-se até 200 grupos em cada tabela; os objetos completos ficam disponíveis
em `classificacao_05` durante a execução.

O processamento é agregado no DuckDB, com views temporárias em uma conexão de
análise. As fontes não são alteradas. O JOIN recusa NBs duplicados na auxiliar,
inclusive duplicatas após aparar espaços, para preservar a contagem de benefícios.

## Validação

```sh
Rscript testes/testar_filtros_05.R
```

Os testes usam registros sintéticos para limites exatos, percentuais, ausências,
filiação presente/ausente, código explicitamente mapeado, BPC e duplicatas de NB.
A renderização foi validada com o exemplo sintético de 30×61, em CSV e Parquet. Ainda é
necessário recuperar a filiação real para obter os resultados por esse tipo no
Parquet de 61 colunas do usuário.
