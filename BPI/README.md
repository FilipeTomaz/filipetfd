# BPI

Projeto para estudar a base identificada de benefícios integrada ao CadÚnico e à
RAIS e preparar uma base inteiramente sintética com o mesmo formato e relações.
Os anexos estão organizados e já existe um **exemplo sintético com 30 linhas e
61 colunas**, incluindo anos de contribuição.

- [Ver o CSV sintético](dados/sinteticos/bpi_sintetico_61.csv)
- [Ler as instruções e convenções](dados/sinteticos/README.md)
- [Gerador em R](scripts/gerar_base_sintetica.R)
- [Esquema das 61 variáveis](esquemas/banco_beneficio_cad_rais_61.csv)

## O que está sendo feito nos arquivos

O núcleo é `tb_beneficio`: **uma linha por número de benefício (NB)**, com
Concedidos das espécies **21 (pensão por morte), 41 (aposentadoria por idade) e
88 (BPC ao idoso)**. A ligação ao CadÚnico de junho/2024 e à RAIS 2024 é por CPF.
Um CPF pode ter vários benefícios: contagens de NBs não são contagens de pessoas.

O esquema observado no HTML de dicionário tem **60 colunas**: 26 do INSS, 17 do
CadÚnico, 14 da RAIS e três de renda familiar. O complemento de contribuição
acrescenta `qt_anos_contribuicao` por NB quando incorporado à análise, formando
uma visão de 61 colunas. A integração de **Mantidos** é um ramo ainda em estudo
para identificar situação e duração, sem comprovar automaticamente posição em
julho de 2026.

```mermaid
flowchart LR
    C[Concedidos] --> B[Benefícios: NB único]
    P[CadÚnico pessoa e família: jun/2024] -->|CPF| B
    R[RAIS: vínculo principal de 2024] -->|CPF| B
    B --> F[Base com 60 colunas]
    X[Extração de contribuição] -->|NB| A[Análises com anos de contribuição]
    F --> A
    M[Mantidos: inventário e piloto] -. integração futura por NB .-> F
```

## Conteúdo do projeto

| Caminho | Conteúdo |
|---|---|
| [BPI.Rproj](BPI.Rproj) | Projeto RStudio; sem restauração automática da sessão |
| [docs/entendimento.md](docs/entendimento.md) | Fluxo, regras, leitura dos HTMLs e pontos a corrigir antes de executar |
| [docs/plano_base_sintetica.md](docs/plano_base_sintetica.md) | Especificação da próxima etapa |
| [esquemas/banco_beneficio_cad_rais.csv](esquemas/banco_beneficio_cad_rais.csv) | As 60 colunas e tipos observados no HTML de dicionário |
| [esquemas/contribuicao_nb.csv](esquemas/contribuicao_nb.csv) | Layout da tabela final de contribuição, com três colunas |
| [esquemas/contribuicao_staging.csv](esquemas/contribuicao_staging.csv) | Cinco colunas antes da deduplicação |
| [esquemas/mantidos_piloto.csv](esquemas/mantidos_piloto.csv) | Mapeamento das 12 posições usadas no piloto, dentro do CSV de 51 posições |
| [referencia/codigos/](referencia/codigos/) | 13 códigos recebidos, preservados sem modificações |
| [docs/arquivos_recebidos.csv](docs/arquivos_recebidos.csv) | Inventário e hashes SHA-256 dos 19 anexos |
| [docs/relatorios_html.csv](docs/relatorios_html.csv) | Registro de leitura dos seis HTMLs |
| [dados/](dados/) e [saidas/](saidas/) | Pastas locais reservadas para a próxima etapa |

Os HTMLs foram lidos, mas não copiados para o Git: alguns contêm prévias de
registros individuais, inclusive identificador de benefício anterior. O projeto
versiona somente os códigos e os metadados necessários para preparar a simulação.

## Abrir no RStudio

Abra `BPI.Rproj`. A leitura e a organização atuais não exigem instalar pacotes
ou acessar bancos. Os scripts recebidos usam `DBI`, `duckdb`, `data.table`,
`dplyr` e `knitr`; os relatórios também exigem `rmarkdown` e Pandoc.

Os códigos em `referencia/codigos` são **referência de análise**, ainda não um
pipeline executável do BPI. Possuem caminhos locais fixos, operações que recriam
arquivos e trechos de diagnóstico adicionados ao final. Não foram executados;
serão adaptados para as pastas e os dados sintéticos do projeto na próxima etapa.

## Exemplo sintético disponível

Abra `BPI.Rproj` e execute, sem instalar pacotes adicionais:

```r
source("scripts/gerar_base_sintetica.R")
esquema <- read.csv("esquemas/banco_beneficio_cad_rais_61.csv", colClasses="character")
base <- ler_bpi_sintetico("dados/sinteticos/bpi_sintetico_61.csv", esquema)
dim(base)  # 30 × 61
# Para gerar novamente, com tamanho e semente configuráveis:
gerar_exemplo_bpi(n_beneficios=30, semente=20261022)
```

CSV não preserva tipos físicos; a função de leitura usa o esquema para manter
identificadores como texto e converter datas/números. Os domínios ainda não
confirmados usam convenções sintéticas documentadas, incluindo marcadores
`SIM_*`. Não foram usadas linhas das fontes reais.

Para validar o exemplo padrão, execute `Rscript testes/testar_base_sintetica.R`
na pasta BPI. Os testes verificam estrutura, relações, ausência versus zero,
cronologia e reprodutibilidade. O teste do arquivo versionado espera 30 linhas;
ao substituir o exemplo por outro tamanho, ajuste essa expectativa.

## Próximas etapas

Adaptar os relatórios para a base sintética, gerar versões Parquet/DuckDB com os
tipos físicos do esquema e, se necessário, simular as fontes brutas e Mantidos.
O CSV atual testa o formato final e relações; não tem representatividade
populacional.

## Arquivo 05: filiação e classificação familiar

A versão de trabalho [05_especies_clientela_renda_tempo.Rmd](05_especies_clientela_renda_tempo.Rmd)
acrescenta o chunk `classificacao_tipo_renda_familia`, com filtros editáveis de
filiação, renda per capita, renda total e membros da família. Funciona com CSV
sintético ou Parquet integrado. Veja [parâmetros e exemplos](docs/filtros_arquivo_05.md).

Filiação (`filiacao_nome`/`filiacao_codigo`) não está nas 61 colunas atuais;
sem esses campos ou auxiliar por NB, a classificação permanece não informada.
Clientela rural não é usada como substituto de segurado especial.
