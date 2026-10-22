# Entendimento dos anexos

## Fontes e estágio de cada ramo

Foram lidos 19 anexos: 13 arquivos de código e seis HTMLs. Os originais de código
estão preservados em `../referencia/codigos`. Este documento descreve o conteúdo
observado; não certifica que os scripts tenham sido executados com sucesso nesta
máquina ou que os dados de origem estejam disponíveis.

| Arquivo ou grupo | Função | Situação observada |
|---|---|---|
| `01_banco_beneficio_cad_rais.R` | Integra Concedidos + CadÚnico + RAIS | Gera 57 colunas e uma linha por NB |
| `02_acrescenta_renda_familiar_cadunico.R` | Acrescenta três campos familiares | Atualiza DuckDB e regrava Parquet; base de 60 colunas |
| `acrescenta_renda_familiar_cadunico.R` | Mesmo acréscimo familiar | Cópia byte a byte do arquivo 02; não executar como outra etapa |
| `03_exploracao_beneficios.Rmd` | Explora esquema, datas, idades e clientela | Consultas agregadas; parte das idades precisa ajuste |
| `04_dicionario_banco_beneficio_cad_rais.Rmd` | Compara definições ao esquema do Parquet | Dicionário preliminar, não layout oficial |
| `05_especies_clientela_renda_tempo.Rmd` | Analisa renda, espécie/clientela e tempo potencial | Usa Parquet como referência, com renda familiar |
| `05.1_especies_clientela_renda_tempo.Rmd` | Amplia 05 com contribuição e cruzamentos | Faz JOIN auxiliar por NB se a coluna ainda não existir |
| `00.2_Concedidos_colunas_faltantes.Rmd` | Diagnostica colunas contributivas | Além dos cabeçalhos, há leitura adicional de cinco registros |
| `00.3_Concedidos_colunas_faltantes_teste.Rmd` | Extrai espécie 41 rural de Concedidos 2026 | Extração integral do recorte, não piloto de 100 linhas |
| `00.4_Concedidos_colunas_faltantes_teste_0.Rmd` | Diagnóstico leve de um CSV de Concedidos 2026 | Primeiras 100 linhas de um arquivo |
| `06_extracao_concedidos_nb_cpf_contribuicao.Rmd` | Extrai contribuição dos CSVs de Concedidos | Banco auxiliar, separado do principal |
| `00_inventario_mantidos.Rmd` | Inventaria 19 CSVs, codificação e layout | Propõe integração por NB; ainda não a conclui |
| `00.1_piloto_mantidos_primeiros_100_jul2026.Rmd` | Valida 100 linhas por CSV de Mantidos | Piloto determinístico, não amostra aleatória |

## Unidade de análise e chaves

- **NB** é a chave final de benefício; **CPF** liga benefícios à pessoa. Uma
  pessoa pode ter diversos NBs. Os identificadores ficam como texto, preservando
  zeros e evitando arredondamento numérico.
- O script 01 elimina NB vazio e escolhe, entre duplicatas, a carga mais recente,
  seguida do despacho mais recente (`01:190–205`).
- O CPF é limpo para dígitos e preenchido à esquerda até 11 posições; sequências
  somente de zeros são excluídas. Isso não valida dígitos verificadores (`01:40–44`).
- CadÚnico seleciona membro com estado cadastral 3 e escolhe a família de
  atualização mais recente por CPF (`01:222–260`).
- RAIS seleciona o vínculo ativo em 31/12 de maior remuneração; se não houver
  ativo, usa o último desligado e a maior remuneração como desempate (`01:282–348`).
- Os cruzamentos finais são LEFT JOIN por CPF. Benefícios sem correspondência
  permanecem, com flag `N` e campos daquela fonte ausentes. A quantidade de NBs
  deve ser preservada (`01:367–395`).

## Renda e definições que não podem ser confundidas

- `vl_rmi` é renda mensal inicial na concessão, não o pagamento corrente.
- `vl_rmi_convertido` tem referências monetárias heterogêneas e não deve ser
  comparado diretamente entre anos; `rmi_em_sm` é a medida indicada pelo roteiro.
- `val_renda_bruta_12_meses_memb` recebe a **faixa** `fx_renda_individual_808`.
  Apesar do nome, não deve ser tratado como renda monetária em reais.
- `vl_renda_media_fam` é renda familiar **per capita** em reais; o campo é lido
  da fonte, não recalculado pelo script. `vl_renda_total_fam` e
  `qt_membro_familia` também são entradas da fonte (`02:33–100`).
- A renda familiar é a fotografia CadÚnico de 2024, podendo conter o benefício
  já recebido. Não corresponde necessariamente à renda na data de concessão.
- Clientela INSS (`1` urbana, `2` rural, `0` não informada observado no HTML) é
  distinta da localização do domicílio no CadÚnico (`cod_local_domici_fam`).
- Município INSS/SUIBE, município IBGE/CadÚnico e UF processadora são conceitos
  diferentes. UF processadora não representa necessariamente residência.

## Contribuição: fonte complementar

O arquivo 06 inspeciona 11 CSVs de Concedidos de 2016–2026, com 54 posições.
Seleciona anos de contribuição na posição 28, CPF na 38 e NB na 39. Faz uma
normalização de NB diferente da versão inicial: mantém somente dígitos.

A staging tem cinco campos: NB, CPF, contribuição, arquivo e ano do arquivo.
A tabela final `tb_contribuicao_nb` guarda **somente três campos**: `nb`, `cpf`
e `qt_anos_contribuicao` (`06:467–499`). Arquivo e ano ajudam a deduplicar, mas
não são persistidos nessa seleção final.

A prioridade de deduplicação é contribuição preenchida, arquivo de ano mais
recente, CPF presente e critérios adicionais de desempate. Portanto, não se
trata simplesmente de selecionar a linha mais recente.

O relatório 05.1 usa a coluna existente ou faz LEFT JOIN por NB com a auxiliar,
verificando duplicatas antes do JOIN (`05.1:80–139`). A tabela analítica temporária
seleciona 16 campos sem NB/CPF (`05.1:151–166`); a contribuição é convertida para
DOUBLE. Zero e ausência têm significados diferentes. Na pensão, é preciso
confirmar se o histórico pertence ao instituidor; ele não deve ser atribuído
automaticamente ao pensionista. RAIS não é a fonte dos anos de contribuição.

## Mantidos e situação do benefício

Mantidos tem 19 CSVs com 51 posições observadas no inventário. O piloto lê as
primeiras 100 linhas de cada um (1.900 registros); essas linhas não são uma
amostra probabilística. As datas DIB/DCB usam DDMMAAAA e incluem sentinelas de
ausência. O esquema reduzido está em `../esquemas/mantidos_piloto.csv`.

A leitura precisa distinguir ativo, cessado, suspenso e situação indeterminada.
Ausência de NB em Mantidos não comprova cessação; DCB ausente não comprova
atividade. A referência analítica de **31/07/2026 não está confirmada como
competência dos arquivos**. A competência da última maciça também não prova a
posição da extração.

O tempo DIB até 31/12/2025 calculado no relatório 05 é **tempo potencial**, não
duração efetiva de recebimento. Só a integração validada com cessação/situação
poderá sustentar uma duração observada.

## O que os HTMLs mostram

| HTML | Evidência usada nesta leitura |
|---|---|
| `dicionario_banco_beneficio_cad_rais.html` | Metadados e dicionário confirmam 60 colunas e seus tipos; também contém prévia de cinco registros |
| `03_exploracao_beneficios.html` | Esquema e agregados por espécie/clientela, datas, idade e prazos |
| `05_especies_clientela_renda_tempo.html` | Resultados agregados de renda e tempo potencial para espécies 21/41/88 |
| `05.1_especies_clientela_renda_tempo.html` | Acrescenta contribuição e interseções CadÚnico/RAIS, com foco em pensão rural |
| `00_inventario_mantidos.html` | Confirma 19 cabeçalhos CP1252, delimitador vírgula e 51 posições; integração ainda desenhada |
| `00.1_piloto_mantidos_primeiros_100_jul2026.html` | Mostra 1.900 primeiras linhas, grupos ativo/cessado/suspenso, validação de DIB/DCB e divergências de duração |

No piloto de Mantidos, as DIBs e DCBs preenchidas foram interpretadas; há um caso
de DCB anterior à DIB e diferenças entre duração informada e calculada. A posição
temporal de julho/2026 aparece como pendente no próprio resultado. Nenhuma dessas
frequências será tomada como distribuição populacional da base sintética.

## Ajustes necessários antes de executar ou adaptar os originais

| Local | Achado concreto | Efeito sobre a adaptação |
|---|---|---|
| `01:416,529` | Remove o DuckDB de saída e apaga checkpoints ao final | Parametrizar destinos exclusivos do BPI |
| `01:330–359` | Particiona RAIS por CPF original e depois normaliza | Deduplicar pela chave normalizada para evitar colisões |
| `01:54–57` | Reusa checkpoint apenas pela existência | Associar checkpoint à configuração e às fontes |
| `01:59–103` | Seleciona primeiro alias de coluna encontrado | Validar layout e aliases por ano |
| `02:128–139` | Atualiza dados e documentação, mas não o dicionário CSV | Reconferir esquema após enriquecimento |
| `03:100–107` | Comentário diz idade completa, mas usa `date_diff('year')` sem ajuste de aniversário | Usar cálculo de idade completa; 05 já contém ajuste |
| `04:285–288` | Usa `arq_db` sem definição no documento | Remover dependência do estado global do RStudio |
| `04:358–368` | Faz `SELECT * LIMIT 10` e print/View | Não renderizar originais sobre dados identificados; publicar apenas agregados |
| `05.1:433–435,658–660` | Cercas de chunks aninhadas ou sobrando | Corrigir estrutura do Rmd na versão adaptada |
| `00.2:456–464` | Lê cinco registros além do diagnóstico de esquema anunciado | Tratar como leitura de dados, não só metadados |
| `00.3` e `06` | Extração habilitada por padrão; 06 tem chunks finais de recriação/exportação | Configurar execução explícita e saídas de teste |

Os originais permanecem sem alteração para rastreabilidade. Os apontamentos acima
não foram corrigidos nesta etapa, pois a solicitação atual é leitura e organização.
