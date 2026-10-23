# Agregações DuckDB para o novo chunk do arquivo 05. Não modifica fontes.
configuracao_05 <- function() list(
  salario_minimo=1412, arquivo_filiacao_aux='',
  campo_filiacao_codigo='filiacao_codigo',campo_filiacao_nome='filiacao_nome',
  nomes_especial=c('SEGURADO ESPECIAL','SEGURADA ESPECIAL'),codigos_especial=character(),
  tipo_segurado='Todos',clientela_codigos=character(),
  renda_pc_min=NULL,renda_pc_max=NULL,renda_total_min=NULL,renda_total_max=NULL,
  membros_min=NULL,membros_max=NULL,incluir_ausentes_nos_filtros=FALSE)

filtrar_familias_05 <- function(con,config=list()) {
  p <- utils::modifyList(configuracao_05(),config)
  if (!is.numeric(p$salario_minimo) || length(p$salario_minimo)!=1 ||
      !is.finite(p$salario_minimo) || p$salario_minimo<=0) stop('Salário mínimo inválido.')
  for (campo in c('renda_pc','renda_total','membros')) {
    lo <- p[[paste0(campo,'_min')]];hi <- p[[paste0(campo,'_max')]]
    for (v in list(lo,hi)) if (!is.null(v) && (length(v)!=1 || !is.numeric(v) ||
       !is.finite(v) || v<0 || (campo=='membros' && (v<1 || v!=floor(v)))))
      stop('Limite inválido em ',campo)
    if (!is.null(lo) && !is.null(hi) && lo>hi) stop('Limite mínimo maior que máximo: ',campo)
  }
  tipos <- c('Segurado especial','Demais categorias de filiação',
    'Não informado/não classificado','Não se aplica (BPC)')
  if (length(p$tipo_segurado)!=1 || !p$tipo_segurado %in% c('Todos',tipos))
    stop('tipo_segurado deve ser Todos ou uma categoria exibida no relatório.')
  q <- function(x) as.character(DBI::dbQuoteString(con,x))
  qi <- function(x) as.character(DBI::dbQuoteIdentifier(con,x))
  numero <- function(x) sprintf('%.15g',x)
  cols <- DBI::dbGetQuery(con,'DESCRIBE SELECT * FROM tb_beneficio')$column_name
  exigidas <- c('especie','especie_nome','clientela_codigo','clientela',
    'vl_renda_media_fam','vl_renda_total_fam','qt_membro_familia')
  faltam <- setdiff(exigidas,cols)
  if (length(faltam)) stop('Colunas obrigatórias ausentes: ',paste(faltam,collapse=', '))
  codigo <- if (p$campo_filiacao_codigo %in% cols)
    paste0('NULLIF(TRIM(CAST(b.',qi(p$campo_filiacao_codigo)," AS VARCHAR)), '')") else 'NULL'
  nome <- if (p$campo_filiacao_nome %in% cols)
    paste0('NULLIF(TRIM(CAST(b.',qi(p$campo_filiacao_nome)," AS VARCHAR)), '')") else 'NULL'
  origem <- if (nome!='NULL' || codigo!='NULL') 'Filiação presente na base integrada' else
    'Filiação ausente na base; não se infere a partir de clientela, despacho ou RAIS'
  join <- ''
  if (nzchar(p$arquivo_filiacao_aux)) {
    if (!'nb' %in% cols) stop('JOIN de filiação exige NB na base.')
    caminho <- normalizePath(p$arquivo_filiacao_aux,winslash='/',mustWork=TRUE)
    ext <- tolower(tools::file_ext(caminho))
    fonte <- if (ext=='parquet') sprintf('read_parquet(%s)',q(caminho)) else
      if (ext=='csv') sprintf("read_csv(%s,header=true,all_varchar=true)",q(caminho)) else
        stop('Auxiliar de filiação deve ser CSV ou Parquet.')
    acols <- DBI::dbGetQuery(con,paste('DESCRIBE SELECT * FROM',fonte))$column_name
    if (!all(c('nb',p$campo_filiacao_nome) %in% acols) &&
        !all(c('nb',p$campo_filiacao_codigo) %in% acols))
      stop('Auxiliar exige NB e nome ou código de filiação.')
    # NB permanece texto; valida após trim para impedir multiplicação de linhas.
    DBI::dbExecute(con,paste0('CREATE OR REPLACE TEMP VIEW v05_aux_filiacao AS SELECT ',
      "NULLIF(TRIM(CAST(nb AS VARCHAR)), '') AS nb, ",
      if (p$campo_filiacao_nome %in% acols)
        paste0('CAST(',qi(p$campo_filiacao_nome),' AS VARCHAR)') else 'NULL::VARCHAR',
      ' AS nome, ',if (p$campo_filiacao_codigo %in% acols)
        paste0('CAST(',qi(p$campo_filiacao_codigo),' AS VARCHAR)') else 'NULL::VARCHAR',
      ' AS codigo FROM ',fonte))
    dup <- DBI::dbGetQuery(con,'SELECT EXISTS(SELECT 1 FROM v05_aux_filiacao WHERE nb IS NOT NULL GROUP BY nb HAVING COUNT(*)>1) AS ha')$ha[1]
    if (isTRUE(dup)) stop('Auxiliar possui NB duplicado; JOIN cancelado.')
    # Priorizar o par da base; não misturar seu nome com código de outra origem.
    tem_base <- paste0('(',nome,' IS NOT NULL OR ',codigo,' IS NOT NULL)')
    nome_base <- nome;codigo_base <- codigo
    nome <- paste0('CASE WHEN ',tem_base,' THEN ',nome_base,
      " ELSE NULLIF(TRIM(a.nome), '') END")
    codigo <- paste0('CASE WHEN ',tem_base,' THEN ',codigo_base,
      " ELSE NULLIF(TRIM(a.codigo), '') END")
    join <- ' LEFT JOIN v05_aux_filiacao a ON TRIM(CAST(b.nb AS VARCHAR))=a.nb '
    origem <- paste(origem,'+ auxiliar por NB (unicidade validada)')
  }
  # Estas views projetam somente dimensões e valores necessários; não exibem NB/CPF.
  DBI::dbExecute(con,paste0('CREATE OR REPLACE TEMP VIEW v05_familia_base AS SELECT ',
    'b.especie,b.especie_nome,b.clientela_codigo,b.clientela,',
    'TRY_CAST(b.vl_renda_media_fam AS DOUBLE) AS renda_pc,',
    'TRY_CAST(b.vl_renda_total_fam AS DOUBLE) AS renda_total,',
    'TRY_CAST(b.qt_membro_familia AS DOUBLE) AS membros,',
    codigo,' AS filiacao_codigo,',nome,' AS filiacao_nome ',
    'FROM tb_beneficio b ',join,' WHERE b.especie IN (21,41,88)'))
  normalizar <- function(x) toupper(trimws(iconv(x,from='',to='ASCII//TRANSLIT')))
  nomes <- normalizar(p$nomes_especial)
  nomes <- unique(nomes[!is.na(nomes) & nzchar(nomes)])
  codigos <- unique(trimws(as.character(p$codigos_especial)))
  codigos <- codigos[!is.na(codigos) & nzchar(codigos)]
  cond_nome <- if (length(nomes)) paste0('nome_normalizado IN (',paste(q(nomes),collapse=','),')') else 'FALSE'
  cond_codigo <- if (length(codigos)) paste0('TRIM(filiacao_codigo) IN (',paste(q(codigos),collapse=','),')') else 'FALSE'
  nulos <- c('NA','N/A','NULL','IGNORADO','NAO INFORMADO','NAO INFORMADA',
    'SEM INFORMACAO','NAO CLASSIFICADO','NAO CLASSIFICADA','SEM FILIACAO',
    'NAO IDENTIFICADO','NAO IDENTIFICADA','DESCONHECIDO','DESCONHECIDA','NAO SE APLICA','0','-')
  sm <- p$salario_minimo
  faixa_renda <- function(col,limites,rotulos) {
    paste0('CASE WHEN ',col," IS NULL THEN 'Sem informação' WHEN NOT isfinite(",col,
      ') OR ',col,"<0 THEN 'Inválida' WHEN ",col,"=0 THEN 'Zero' ",
      paste(vapply(seq_along(limites),function(i) paste0('WHEN ',col,'<=',
        numero(limites[i]),' THEN ',q(rotulos[i])),character(1)),collapse=' '),
      ' ELSE ',q(tail(rotulos,1)),' END')
  }
  pc <- faixa_renda('renda_pc',c(sm/4,sm/2,sm,2*sm),
    c('Até 1/4 SM','>1/4 até 1/2 SM','>1/2 até 1 SM','>1 até 2 SM','>2 SM'))
  total <- faixa_renda('renda_total',c(sm,2*sm,3*sm,5*sm),
    c('Até 1 SM','>1 até 2 SM','>2 até 3 SM','>3 até 5 SM','>5 SM'))
  DBI::dbExecute(con,paste0('CREATE OR REPLACE TEMP VIEW v05_familias AS WITH normalizada AS (',
    "SELECT *, UPPER(REGEXP_REPLACE(STRIP_ACCENTS(TRIM(filiacao_nome)), '\\s+', ' ', 'g')) AS nome_normalizado ",
    'FROM v05_familia_base) SELECT especie,especie_nome,clientela_codigo,clientela,',
    'renda_pc,renda_total,membros, CASE WHEN especie=88 THEN ',q(tipos[4]),
    ' WHEN ',cond_codigo,' AND nome_normalizado IS NOT NULL AND nome_normalizado NOT IN (',
    paste(q(c('',nulos)),collapse=','),') AND NOT (',cond_nome,') THEN ',q(tipos[3]),
    ' WHEN ',cond_nome,' OR ',cond_codigo,' THEN ',q(tipos[1]),
    " WHEN nome_normalizado IS NOT NULL AND nome_normalizado<>'' AND nome_normalizado NOT IN (",
    paste(q(nulos),collapse=','),') THEN ',q(tipos[2]),' ELSE ',q(tipos[3]),
    ' END AS tipo_segurado,',pc,' AS faixa_renda_pc,',total,' AS faixa_renda_total,',
    "CASE WHEN membros IS NULL THEN 'Sem informação' ",
    "WHEN NOT isfinite(membros) OR membros<1 OR membros<>FLOOR(membros) THEN 'Inválida' ",
    "WHEN membros>=5 THEN '5 ou mais' ELSE CAST(CAST(membros AS INTEGER) AS VARCHAR) END AS faixa_membros ",
    'FROM normalizada'))
  filtros <- 'TRUE'
  if (p$tipo_segurado!='Todos') filtros <- paste(filtros,'AND tipo_segurado=',q(p$tipo_segurado))
  if (length(p$clientela_codigos)) filtros <- paste0(filtros,' AND CAST(clientela_codigo AS VARCHAR) IN (',
    paste(q(as.character(p$clientela_codigos)),collapse=','),')')
  for (campo in c('renda_pc','renda_total','membros')) {
    lo <- p[[paste0(campo,'_min')]];hi <- p[[paste0(campo,'_max')]]
    if (!is.null(lo) || !is.null(hi)) {
      cond <- paste0('isfinite(',campo,') AND ',campo,if (campo=='membros') '>=1' else '>=0')
      if (campo=='membros') cond <- paste0(cond,' AND membros=FLOOR(membros)')
      if (!is.null(lo)) cond <- paste0(cond,' AND ',campo,'>=',numero(lo))
      if (!is.null(hi)) cond <- paste0(cond,' AND ',campo,'<=',numero(hi))
      if (isTRUE(p$incluir_ausentes_nos_filtros)) cond <- paste0('(',cond,') OR ',campo,' IS NULL')
      filtros <- paste0(filtros,' AND (',cond,')')
    }
  }
  DBI::dbExecute(con,paste0('CREATE OR REPLACE TEMP VIEW v05_recorte AS SELECT * FROM v05_familias WHERE ',filtros))
  resumo_sql <- function(view) paste0('SELECT especie,especie_nome,clientela_codigo,clientela,tipo_segurado,',
    'COUNT(*) AS n_beneficios,COUNT(renda_pc) AS n_renda_pc_informada,',
    'COUNT(renda_total) AS n_renda_total_informada,COUNT(membros) AS n_membros_informados,',
    'ROUND(AVG(renda_pc) FILTER(WHERE isfinite(renda_pc) AND renda_pc>=0),2) AS renda_pc_media,',
    'ROUND(MEDIAN(renda_pc) FILTER(WHERE isfinite(renda_pc) AND renda_pc>=0),2) AS renda_pc_mediana,',
    'ROUND(AVG(renda_total) FILTER(WHERE isfinite(renda_total) AND renda_total>=0),2) AS renda_total_media,',
    'ROUND(AVG(membros) FILTER(WHERE isfinite(membros) AND membros>=1 AND membros=FLOOR(membros)),2) AS membros_medios ',
    'FROM ',view,' GROUP BY ALL ORDER BY especie,clientela_codigo,tipo_segurado')
  dims <- 'especie,especie_nome,clientela_codigo,clientela,tipo_segurado'
  contagem <- function(extra) DBI::dbGetQuery(con,paste0('SELECT ',dims,',',extra,
    ',COUNT(*) AS n_beneficios,ROUND(100.0*COUNT(*) / SUM(COUNT(*)) OVER ',
    '(PARTITION BY especie,clientela_codigo,clientela,tipo_segurado),2) AS pct_grupo ',
    'FROM v05_recorte GROUP BY ',dims,',',extra,' ORDER BY especie,clientela_codigo,tipo_segurado,',extra))
  list(config=p,origem_filiacao=origem,
    auditoria=DBI::dbGetQuery(con,'SELECT (SELECT COUNT(*) FROM v05_familias) AS n_antes, (SELECT COUNT(*) FROM v05_recorte) AS n_depois'),
    dominios_filiacao=DBI::dbGetQuery(con,paste0('SELECT especie,filiacao_codigo,filiacao_nome,COUNT(*) AS n_beneficios ',
      'FROM v05_familia_base GROUP BY ALL ORDER BY especie,n_beneficios DESC')),
    resumo_antes=DBI::dbGetQuery(con,resumo_sql('v05_familias')),
    resumo_filtrado=DBI::dbGetQuery(con,resumo_sql('v05_recorte')),
    faixas_per_capita=contagem('faixa_renda_pc'),faixas_total=contagem('faixa_renda_total'),
    faixas_membros=contagem('faixa_membros'),
    cruzamento_familiar=contagem('faixa_renda_pc,faixa_renda_total,faixa_membros'))
}
