# NB concedido, com:
#   (a) 18 campos previdenciarios dos Concedidos (especies 21, 41 e 88);
#   (b) flag de localizacao no CadUnico (jun/2024) + 16 campos cadastrais;
#   (c) 11 campos do vinculo principal na RAIS 2024 (identificada).
# Chave de cruzamento: CPF do titular (11 digitos, zeros a esquerda).
# Parametros: especies 21/41/88; Cad 06/2024; RAIS 2024; vinculo principal = ativo em 31/12 de maior remuneracao
# media; sem vinculo ativo, o ultimo desligado do ano.

library(duckdb)
library(data.table)

dir_conc  <- "E:/01_Bases/09_PREVIDENCIA/04_Dados/Concedidos"
dir_cad   <- "E:/01_Bases/14_FNDE_FIES/02_Códigos/output/parquet"
arq_rais  <- "E:/01_Bases/01_RAIS/04_parquet/rais_2024.parquet"
dir_saida <- "E:/01_Bases/09_PREVIDENCIA/04_Dados/Saidas"
ESPECIES  <- c(21, 41, 88)
ANO_CAD   <- 2024
ANO_RAIS  <- 2024
nome_banco <- "banco_beneficio_cad_rais"

con <- dbConnect(duckdb())
dbExecute(con, "SET preserve_insertion_order=false")
dbExecute(con, sprintf("SET temp_directory='%s/duckdb_tmp'", dir_saida))
leitura <- "encoding='latin-1', union_by_name=true, all_varchar=true, sample_size=20000, strict_mode=false, null_padding=true"
t0 <- Sys.time()

parse_data <- function(col) sprintf("
  CASE
    WHEN regexp_matches(CAST(\"%s\" AS VARCHAR), '^[0-9]{8}$')
      THEN TRY_CAST(strptime(CAST(\"%s\" AS VARCHAR), '%%d%%m%%Y') AS DATE)
    WHEN regexp_matches(CAST(\"%s\" AS VARCHAR), '^[0-9]{2}/[0-9]{2}/[0-9]{4}')
      THEN TRY_CAST(strptime(substr(CAST(\"%s\" AS VARCHAR), 1, 10), '%%d/%%m/%%Y') AS DATE)
    WHEN regexp_matches(CAST(\"%s\" AS VARCHAR), '^[0-9]{4}-[0-9]{2}-[0-9]{2}')
      THEN TRY_CAST(substr(CAST(\"%s\" AS VARCHAR), 1, 10) AS DATE)
    ELSE NULL END", col, col, col, col, col, col)
parse_valor <- function(col) sprintf("
  TRY_CAST(CASE WHEN CAST(\"%s\" AS VARCHAR) LIKE '%%,%%'
                THEN replace(replace(CAST(\"%s\" AS VARCHAR), '.', ''), ',', '.')
                ELSE CAST(\"%s\" AS VARCHAR) END AS DOUBLE)", col, col, col)
cpf11 <- function(expr) sprintf("
  CASE WHEN length(regexp_replace(CAST(%s AS VARCHAR), '[^0-9]', '', 'g')) BETWEEN 1 AND 11
        AND regexp_replace(CAST(%s AS VARCHAR), '[^0-9]', '', 'g') <> repeat('0', length(regexp_replace(CAST(%s AS VARCHAR), '[^0-9]', '', 'g')))
       THEN lpad(regexp_replace(CAST(%s AS VARCHAR), '[^0-9]', '', 'g'), 11, '0')
       ELSE NULL END", expr, expr, expr, expr)

# ══ PARTE 0 —  CHECAGEM DAS FONTES ══════════════════════════
cat("═══ PARTE 0: checagem das fontes ═══\n")
for (p in c(dir_conc, dir_cad)) if (!dir.exists(p)) stop("PARAR: pasta nao encontrada: ", p)
if (!file.exists(arq_rais)) stop("PARAR: parquet da RAIS nao encontrado: ", arq_rais)
arq_cad_p <- sprintf("%s/cadunico_pessoa_%d_tratado.parquet",  dir_cad, ANO_CAD)
arq_cad_f <- sprintf("%s/cadunico_familia_%d_tratado.parquet", dir_cad, ANO_CAD)
for (p in c(arq_cad_p, arq_cad_f)) if (!file.exists(p)) stop("PARAR: arquivo nao encontrado: ", p)
dir.create(file.path(dir_saida, "duckdb_tmp"), showWarnings = FALSE)
# pontos de retomada: cada parte pesada grava seu resultado; se o arquivo
# existir, a parte e pulada (apagar a pasta duckdb_tmp para refazer tudo)
ckpt_conc <- sprintf("%s/duckdb_tmp/ckpt_conc.parquet", dir_saida)
ckpt_cad  <- sprintf("%s/duckdb_tmp/ckpt_cad.parquet",  dir_saida)

# --- Concedidos: nomes das colunas (variam entre anos) ---
cols_c <- dbGetQuery(con, sprintf(
  "DESCRIBE SELECT * FROM read_csv_auto('%s/*.csv', %s)", dir_conc, leitura))$column_name
cat("\n--- Concedidos:", length(cols_c), "colunas (uniao de todos os anos) ---\n"); print(cols_c)
acha <- function(padroes, rotulo, obrig = TRUE) {
  for (p in padroes) {
    hit <- grep(p, cols_c, value = TRUE, ignore.case = TRUE)
    if (length(hit) > 0) { cat(sprintf("    %-28s -> \"%s\"\n", rotulo, hit[1])); return(hit[1]) }
  }
  if (obrig) stop("PARAR: nao achei coluna de ", rotulo, " em Concedidos. Ajustar padroes.")
  cat(sprintf("    %-28s -> (AUSENTE, sai NULL)\n", rotulo)); NULL
}
cat("\n--- Campos do layout em Concedidos ---\n")
C_NB      <- acha(c("^NB$"), "NB")
C_NBANT   <- acha(c("^NB Anterior"), "NB Anterior")
C_CPF     <- acha(c("^CPF Titular"), "CPF Titular")
C_ESP     <- acha(c("Esp.cie \\(C.digo\\)"), "Especie (codigo)")
C_ESPN    <- acha(c("Esp.cie \\(Nome\\)"), "Especie (nome)", FALSE)
C_CLI     <- acha(c("Clientela \\(C.digo\\)"), "Clientela (codigo)", FALSE)
C_CLIN    <- acha(c("Clientela \\(Nome\\)"), "Clientela (nome)")
C_CID     <- acha(c("^CID"), "CID", FALSE)
C_DESP    <- acha(c("^Despacho \\(C.digo\\)"), "Despacho (codigo)", FALSE)
C_DESPN   <- acha(c("^Despacho \\(Nome\\)"), "Despacho (nome)")
C_SEXO    <- acha(c("Sexo Titular \\(C.digo\\)"), "Sexo (codigo)", FALSE)
C_SEXON   <- acha(c("Sexo Titular \\(Nome\\)"), "Sexo (nome)")
C_JUROS   <- acha(c("Juros Atrasados"), "Vl Juros Atrasados")
C_CORR    <- acha(c("Corre.{1,2}o Monet"), "Vl Correcao Monetaria")
C_RMI     <- acha(c("Vl RMI - Renda"), "Vl RMI")
C_RMICONV <- acha(c("Vl RMI Convertido"), "Vl RMI Convertido")
C_RMISM   <- acha(c("Quantidade Sal.rios M.nimos - RMI"), "RMI em SM", FALSE)
C_DDB     <- acha(c("^DDB"), "DDB")
C_DIB     <- acha(c("^DIB"), "DIB")
C_DER     <- acha(c("^DER"), "DER")
C_DII     <- acha(c("^DII"), "DII")
C_NASC    <- acha(c("Data Nascimento Titular"), "Data Nascimento")
C_UF      <- acha(c("^UF \\(Nome\\)"), "UF (processadora)")
C_MUNC    <- acha(c("Munic.pio Resid Titular \\(C.digo\\)"), "Municipio resid (codigo)")
C_MUNN    <- acha(c("Munic.pio Resid Titular \\(Nome\\)"), "Municipio resid (nome)")
C_CARGA   <- acha(c("^Data Carga"), "Data Carga", FALSE)
sel <- function(col, alias, tipo = "texto") {
  if (is.null(col)) return(sprintf("NULL AS %s", alias))
  switch(tipo,
         texto = sprintf("trim(CAST(\"%s\" AS VARCHAR)) AS %s", col, alias),
         data  = sprintf("%s AS %s", parse_data(col), alias),
         valor = sprintf("%s AS %s", parse_valor(col), alias))
}

# --- CadUnico: colunas ---
cols_p <- dbGetQuery(con, sprintf("DESCRIBE SELECT * FROM read_parquet('%s')", arq_cad_p))$column_name
cols_f <- dbGetQuery(con, sprintf("DESCRIBE SELECT * FROM read_parquet('%s')", arq_cad_f))$column_name
req_p <- c("nu_cpf_pessoa", "co_familiar_fam", "co_est_cadastral_memb", "cd_ibge_cadastro",
           "co_deficiencia_memb", "in_def_cegueira_memb", "in_def_baixa_visao_memb",
           "in_def_surdez_profunda_memb", "in_def_surdez_leve_memb", "in_def_fisica_memb",
           "in_def_mental_memb", "in_def_sindrome_down_memb", "in_def_transtorno_mental_memb",
           "co_curso_freq_pessoa_memb", "co_trabalho_12_meses_memb", "qt_meses_12_meses_memb",
           "fx_renda_individual_808")
req_f <- c("co_familiar_fam", "cd_ibge_cadastro", "co_local_domic_fam", "dt_atualizacao_fam")
falta <- c(setdiff(req_p, cols_p), setdiff(req_f, cols_f))
if (length(falta) > 0)
  stop("PARAR: colunas ausentes no CadUnico tratado: ", paste(falta, collapse = ", "),
       "\nConferir nomes com DESCRIBE e ajustar req_p/req_f.")
cat("\n--- CadUnico", ANO_CAD, "tratado: todas as", length(req_p) + length(req_f), "colunas necessarias presentes ---\n")

# --- RAIS: colunas  ---
cols_r <- dbGetQuery(con, sprintf("DESCRIBE SELECT * FROM read_parquet('%s')", arq_rais))$column_name
req_r <- c("cpf", "vinculo_ativo_31_12", "tipo_vinculo", "tipo_admissao", "data_admissao",
           "tempo_emprego", "vl_remun_media_nom", "vl_remun_media_sm", "cbo_94", "cbo_2002",
           "cnae_95_classe", "cnae_20_classe", "mes_desligamento", "dia_desligamento")
falta <- setdiff(req_r, cols_r)
if (length(falta) > 0) {
  cat("--- Colunas da RAIS ---\n"); print(cols_r)
  stop("PARAR: colunas ausentes na RAIS ", ANO_RAIS, ": ", paste(falta, collapse = ", "))
}
cat("--- RAIS", ANO_RAIS, "parquet: todas as", length(req_r), "colunas necessarias presentes ---\n")

# ══ PARTE 1 — CONCEDIDOS (uma linha por NB) ══════════════════════════════════
cat("\n═══ PARTE 1: Concedidos, especies", paste(ESPECIES, collapse = "/"), "═══\n")
if (file.exists(ckpt_conc)) {
  cat("  (retomada: Concedidos ja processados — carregando)\n")
  dbExecute(con, sprintf("CREATE OR REPLACE TEMP TABLE conc AS SELECT * FROM read_parquet('%s')", ckpt_conc))
  n_bruto <- NA
} else {
  dbExecute(con, sprintf("
  CREATE OR REPLACE TEMP TABLE conc_bruto AS
  SELECT %s
  FROM read_csv_auto('%s/*.csv', %s)
  WHERE TRY_CAST(regexp_extract(CAST(\"%s\" AS VARCHAR), '[0-9]+') AS INTEGER) IN (%s)",
                         paste(c(
                           sel(C_NB,      "nb"),
                           sprintf("%s AS cpf", cpf11(sprintf('"%s"', C_CPF))),
                           sel(C_CLI,     "clientela_codigo"),
                           sel(C_CLIN,    "clientela"),
                           sel(C_NBANT,   "nb_anterior"),
                           sprintf("TRY_CAST(regexp_extract(CAST(\"%s\" AS VARCHAR), '[0-9]+') AS INTEGER) AS especie", C_ESP),
                           sel(C_ESPN,    "especie_nome"),
                           sel(C_CID,     "cid"),
                           sel(C_DESP,    "despacho_codigo"),
                           sel(C_DESPN,   "despacho"),
                           sel(C_SEXO,    "sexo_codigo"),
                           sel(C_SEXON,   "sexo"),
                           sel(C_JUROS,   "vl_juros_atrasados", "valor"),
                           sel(C_CORR,    "vl_correcao_monetaria", "valor"),
                           sel(C_RMI,     "vl_rmi", "valor"),
                           sel(C_RMICONV, "vl_rmi_convertido", "valor"),
                           sel(C_RMISM,   "rmi_em_sm", "valor"),
                           sel(C_DDB,     "dt_ddb", "data"),
                           sel(C_DIB,     "dt_dib", "data"),
                           sel(C_DER,     "dt_der", "data"),
                           sel(C_DII,     "dt_dii", "data"),
                           sel(C_NASC,    "dt_nascimento", "data"),
                           sel(C_UF,      "uf_processadora"),
                           sprintf("trim(regexp_extract(CAST(\"%s\" AS VARCHAR), '[0-9]+')) AS municipio_codigo", C_MUNC),
                           sel(C_MUNN,    "municipio"),
                           sel(C_CARGA,   "dt_carga", "data")
                         ), collapse = ",\n         "),
                         dir_conc, leitura, C_ESP, paste(ESPECIES, collapse = ",")))
  
  # UF de residencia: 2 primeiros digitos do codigo de municipio
  dbExecute(con, "
  CREATE OR REPLACE TEMP TABLE conc AS
  SELECT * EXCLUDE (rn),
         CASE substr(lpad(municipio_codigo, 5, '0'), 1, 2)
           WHEN '02' THEN 'AL' WHEN '03' THEN 'AM' WHEN '04' THEN 'BA' WHEN '05' THEN 'CE'
           WHEN '06' THEN 'MS' WHEN '07' THEN 'ES' WHEN '08' THEN 'GO' WHEN '09' THEN 'MA'
           WHEN '10' THEN 'MT' WHEN '11' THEN 'MG' WHEN '12' THEN 'PA' WHEN '13' THEN 'PB'
           WHEN '14' THEN 'PR' WHEN '15' THEN 'PE' WHEN '16' THEN 'PI' WHEN '17' THEN 'RJ'
           WHEN '18' THEN 'RN' WHEN '19' THEN 'RS' WHEN '20' THEN 'SC' WHEN '21' THEN 'SP'
           WHEN '22' THEN 'SE' WHEN '23' THEN 'DF' WHEN '24' THEN 'AC' WHEN '25' THEN 'AP'
           WHEN '26' THEN 'RO' WHEN '27' THEN 'RR' WHEN '28' THEN 'TO'
           ELSE NULL END AS uf
  FROM (
    SELECT *, ROW_NUMBER() OVER (
             PARTITION BY nb ORDER BY dt_carga DESC NULLS LAST, dt_ddb DESC NULLS LAST) AS rn
    FROM conc_bruto WHERE nb IS NOT NULL AND nb <> '')
  WHERE rn = 1")
  n_bruto <- dbGetQuery(con, "SELECT COUNT(*) n FROM conc_bruto")$n
  dbExecute(con, sprintf("COPY conc TO '%s' (FORMAT PARQUET)", ckpt_conc))
}
chk_c <- dbGetQuery(con, "
  SELECT COUNT(*) AS beneficios, COUNT(DISTINCT nb) AS nb_distintos,
         COUNT(*) FILTER (WHERE cpf IS NULL) AS sem_cpf,
         COUNT(*) FILTER (WHERE dt_ddb IS NULL) AS sem_ddb,
         COUNT(*) FILTER (WHERE uf IS NULL) AS sem_uf_residencia,
         MIN(year(dt_ddb)) AS ano_min, MAX(year(dt_ddb)) AS ano_max
  FROM conc")
cat("Linhas lidas:", format(n_bruto, big.mark = ".", decimal.mark = ","), "| apos dedup por NB:\n"); print(chk_c)
if (chk_c$beneficios != chk_c$nb_distintos) stop("PARAR: NB repetido apos dedup.")
cat("\nBeneficios por especie e ano (DDB):\n")
print(dcast(as.data.table(dbGetQuery(con,
                                     "SELECT especie, year(dt_ddb) AS ano, COUNT(*) AS n FROM conc GROUP BY 1,2")),
            ano ~ especie, value.var = "n", fill = 0))
cat("CHECAGEM UF residencia (capitais na UF certa):\n")
print(dbGetQuery(con, "
  SELECT municipio, uf, COUNT(*) n FROM conc
  WHERE municipio IN ('SALVADOR','FORTALEZA','BELO HORIZONTE','PORTO ALEGRE') GROUP BY 1,2 ORDER BY 1"))
cat(sprintf("Tempo: %.1f min\n", as.numeric(difftime(Sys.time(), t0, units = "mins"))))

# ══ PARTE 2 — CADUNICO 06/2024 (uma linha por CPF) ═══════════════════════════
cat("\n═══ PARTE 2: CadUnico", ANO_CAD, "═══\n")
if (file.exists(ckpt_cad)) {
  cat("  (retomada: CadUnico ja processado — carregando)\n")
  dbExecute(con, sprintf("CREATE OR REPLACE TEMP TABLE cad AS SELECT * FROM read_parquet('%s')", ckpt_cad))
} else {
  # Regras: so membros com estado cadastral 3 (cadastrado); CPF normalizado;
  # se a mesma pessoa aparece mais de uma vez, fica o registro da familia com
  # atualizacao mais recente. UF Cad = 2 primeiros digitos do IBGE do cadastro.
  dbExecute(con, sprintf("
  CREATE OR REPLACE TEMP TABLE cad AS
  SELECT * EXCLUDE (rn) FROM (
    SELECT
      %s AS cpf,
      CASE substr(CAST(p.cd_ibge_cadastro AS VARCHAR), 1, 2)
        WHEN '11' THEN 'RO' WHEN '12' THEN 'AC' WHEN '13' THEN 'AM' WHEN '14' THEN 'RR'
        WHEN '15' THEN 'PA' WHEN '16' THEN 'AP' WHEN '17' THEN 'TO' WHEN '21' THEN 'MA'
        WHEN '22' THEN 'PI' WHEN '23' THEN 'CE' WHEN '24' THEN 'RN' WHEN '25' THEN 'PB'
        WHEN '26' THEN 'PE' WHEN '27' THEN 'AL' WHEN '28' THEN 'SE' WHEN '29' THEN 'BA'
        WHEN '31' THEN 'MG' WHEN '32' THEN 'ES' WHEN '33' THEN 'RJ' WHEN '35' THEN 'SP'
        WHEN '41' THEN 'PR' WHEN '42' THEN 'SC' WHEN '43' THEN 'RS' WHEN '50' THEN 'MS'
        WHEN '51' THEN 'MT' WHEN '52' THEN 'GO' WHEN '53' THEN 'DF' ELSE NULL END AS uf_cad,
      CAST(p.cd_ibge_cadastro AS VARCHAR)       AS municipio_cad_ibge,
      f.co_local_domic_fam                      AS cod_local_domici_fam,
      p.co_deficiencia_memb                     AS cod_deficiencia_memb,
      p.in_def_cegueira_memb                    AS ind_def_cegueira_memb,
      p.in_def_baixa_visao_memb                 AS ind_def_baixa_visao_memb,
      p.in_def_surdez_profunda_memb             AS ind_def_surdez_profunda_memb,
      p.in_def_surdez_leve_memb                 AS ind_def_surdez_leve_memb,
      p.in_def_fisica_memb                      AS ind_def_fisica_memb,
      p.in_def_mental_memb                      AS ind_def_mental_memb,
      TRY_CAST(p.in_def_sindrome_down_memb AS DOUBLE) AS ind_def_sindrome_down_memb,
      p.in_def_transtorno_mental_memb           AS ind_def_transtorno_mental_memb,
      p.co_curso_freq_pessoa_memb               AS cod_curso_frequentou_pessoa_memb,
      p.co_trabalho_12_meses_memb               AS cod_trabalho_12_meses_memb,
      p.qt_meses_12_meses_memb                  AS qtd_meses_12_meses_memb,
      p.fx_renda_individual_808                 AS val_renda_bruta_12_meses_memb,
      ROW_NUMBER() OVER (PARTITION BY %s
                         ORDER BY f.dt_atualizacao_fam DESC NULLS LAST, p.co_familiar_fam DESC) AS rn
    FROM read_parquet('%s') p
    LEFT JOIN read_parquet('%s') f ON p.co_familiar_fam = f.co_familiar_fam
    WHERE p.co_est_cadastral_memb = 3 AND p.nu_cpf_pessoa IS NOT NULL
  ) WHERE rn = 1 AND cpf IS NOT NULL",
                         cpf11("p.nu_cpf_pessoa"), cpf11("p.nu_cpf_pessoa"),
                         arq_cad_p, arq_cad_f))
  dbExecute(con, sprintf("COPY cad TO '%s' (FORMAT PARQUET)", ckpt_cad))
}
chk_cad <- dbGetQuery(con, "
  SELECT COUNT(*) AS pessoas_com_cpf, COUNT(DISTINCT cpf) AS cpfs_distintos,
         COUNT(*) FILTER (WHERE uf_cad IS NULL) AS sem_uf_cad,
         COUNT(*) FILTER (WHERE cod_local_domici_fam IS NULL) AS sem_familia
  FROM cad")
print(chk_cad)
if (chk_cad$pessoas_com_cpf != chk_cad$cpfs_distintos) stop("PARAR: CPF repetido no Cad apos dedup.")
cat("    (esperado: dezenas de milhoes de pessoas; sem_familia deve ser ~0)\n")
# a coluna 808 do Cad tratado pode vir como VALOR ou como FAIXA — registrar
niv808 <- dbGetQuery(con, "
  SELECT COUNT(DISTINCT val_renda_bruta_12_meses_memb) AS niveis,
         MIN(val_renda_bruta_12_meses_memb) AS minimo, MAX(val_renda_bruta_12_meses_memb) AS maximo
  FROM cad WHERE val_renda_bruta_12_meses_memb IS NOT NULL")
print(niv808)
renda808_e_faixa <- niv808$niveis <= 20
cat(if (renda808_e_faixa) "    >>> campo 808 e FAIXA (poucos niveis) — vai documentado como faixa\n"
    else "    campo 808 e VALOR em reais\n")
cat(sprintf("Tempo: %.1f min\n", as.numeric(difftime(Sys.time(), t0, units = "mins"))))

# ══ PARTE 3 — RAIS 2024: vinculo principal por CPF ═══════════════════════════
cat("\n═══ PARTE 3: RAIS", ANO_RAIS, "═══\n")
# Regra do vinculo principal: (1) ativo em 31/12 de maior remuneracao media;
# (2) sem ativo, o ultimo desligado do ano (mes/dia de desligamento mais
# tardio; empate pela maior remuneracao). So CPFs do universo de beneficios.
# Faixas derivadas pelas reguas do layout da RAIS (tempo em meses; remuneracao
# media em salarios minimos).
dbExecute(con, sprintf("
  CREATE OR REPLACE TEMP TABLE rais AS
  SELECT * EXCLUDE (rn, ativo, mes_deslig, dia_deslig) FROM (
    SELECT
      r.cpf,
      TRY_CAST(r.vinculo_ativo_31_12 AS INTEGER)                 AS ativo,
      TRY_CAST(r.mes_desligamento AS INTEGER)                    AS mes_deslig,
      TRY_CAST(r.dia_desligamento AS INTEGER)                    AS dia_deslig,
      TRY_CAST(r.vinculo_ativo_31_12 AS INTEGER)                 AS vinculo_ativo_3112,
      trim(CAST(r.tipo_vinculo AS VARCHAR))                      AS tipo_vinculo,
      trim(CAST(r.tipo_admissao AS VARCHAR))                     AS tipo_admissao,
      month(%s)                                                  AS mes_admissao,
      r.tempo_meses                                              AS tempo_emprego,
      CASE WHEN r.tempo_meses IS NULL THEN NULL
           WHEN r.tempo_meses <  3   THEN '1: ate 2,9 meses'
           WHEN r.tempo_meses <  6   THEN '2: 3,0 a 5,9 meses'
           WHEN r.tempo_meses < 12   THEN '3: 6,0 a 11,9 meses'
           WHEN r.tempo_meses < 24   THEN '4: 12,0 a 23,9 meses'
           WHEN r.tempo_meses < 36   THEN '5: 24,0 a 35,9 meses'
           WHEN r.tempo_meses < 60   THEN '6: 36,0 a 59,9 meses'
           WHEN r.tempo_meses < 120  THEN '7: 60,0 a 119,9 meses'
           ELSE '8: 120 meses ou mais' END                       AS faixa_tempo_emprego,
      r.remun_sm                                                 AS remuneracao_media_sm,
      CASE WHEN r.remun_sm IS NULL OR r.remun_sm <= 0 THEN NULL
           WHEN r.remun_sm <= 0.50 THEN '01: ate 0,50 SM'
           WHEN r.remun_sm <= 1.00 THEN '02: 0,51 a 1,00 SM'
           WHEN r.remun_sm <= 1.50 THEN '03: 1,01 a 1,50 SM'
           WHEN r.remun_sm <= 2.00 THEN '04: 1,51 a 2,00 SM'
           WHEN r.remun_sm <= 3.00 THEN '05: 2,01 a 3,00 SM'
           WHEN r.remun_sm <= 4.00 THEN '06: 3,01 a 4,00 SM'
           WHEN r.remun_sm <= 5.00 THEN '07: 4,01 a 5,00 SM'
           WHEN r.remun_sm <= 7.00 THEN '08: 5,01 a 7,00 SM'
           WHEN r.remun_sm <= 10.00 THEN '09: 7,01 a 10,00 SM'
           WHEN r.remun_sm <= 15.00 THEN '10: 10,01 a 15,00 SM'
           WHEN r.remun_sm <= 20.00 THEN '11: 15,01 a 20,00 SM'
           ELSE '12: mais de 20,00 SM' END                       AS faixa_remuneracao_media_sm,
      r.remun_nom                                                AS valor_remuneracao_media,
      trim(CAST(r.cbo_94 AS VARCHAR))                            AS cbo_1994,
      trim(CAST(r.cbo_2002 AS VARCHAR))                          AS cbo_2002,
      trim(CAST(r.cnae_95_classe AS VARCHAR))                    AS cnae_1,
      trim(CAST(r.cnae_20_classe AS VARCHAR))                    AS cnae_2,
      ROW_NUMBER() OVER (
        PARTITION BY r.cpf
        ORDER BY TRY_CAST(r.vinculo_ativo_31_12 AS INTEGER) DESC NULLS LAST,
                 CASE WHEN TRY_CAST(r.vinculo_ativo_31_12 AS INTEGER) = 1 THEN r.remun_nom END DESC NULLS LAST,
                 TRY_CAST(r.mes_desligamento AS INTEGER) DESC NULLS LAST,
                 TRY_CAST(r.dia_desligamento AS INTEGER) DESC NULLS LAST,
                 r.remun_nom DESC NULLS LAST) AS rn
    FROM (
      SELECT *,
             %s AS tempo_meses, %s AS remun_sm, %s AS remun_nom,
             lpad(regexp_replace(CAST(cpf AS VARCHAR), '[^0-9]', '', 'g'), 11, '0') AS cpf11
      FROM read_parquet('%s')
      WHERE cpf IS NOT NULL
    ) r
    WHERE r.cpf11 IN (SELECT cpf FROM conc WHERE cpf IS NOT NULL)
  ) WHERE rn = 1",
                       parse_data("data_admissao"),
                       parse_valor("tempo_emprego"), parse_valor("vl_remun_media_sm"), parse_valor("vl_remun_media_nom"),
                       arq_rais))
# o cpf que sai da RAIS e o original; a chave do banco usa a versao normalizada
dbExecute(con, "ALTER TABLE rais ALTER cpf SET DATA TYPE VARCHAR")
dbExecute(con, "UPDATE rais SET cpf = lpad(regexp_replace(cpf, '[^0-9]', '', 'g'), 11, '0')")
chk_r <- dbGetQuery(con, "
  SELECT COUNT(*) AS cpfs_com_vinculo, COUNT(DISTINCT cpf) AS cpfs_distintos,
         COUNT(*) FILTER (WHERE vinculo_ativo_3112 = 1) AS ativos_3112,
         COUNT(*) FILTER (WHERE tempo_emprego IS NULL) AS sem_tempo,
         COUNT(*) FILTER (WHERE remuneracao_media_sm IS NULL) AS sem_remun_sm
  FROM rais")
print(chk_r)
if (chk_r$cpfs_com_vinculo != chk_r$cpfs_distintos) stop("PARAR: CPF repetido na RAIS apos escolha do vinculo.")
cat("Faixas de remuneracao (checar: ate 1 SM deve ser minoria, 1-2 SM a moda):\n")
print(dbGetQuery(con, "SELECT faixa_remuneracao_media_sm, COUNT(*) n FROM rais GROUP BY 1 ORDER BY 1"))
cat(sprintf("Tempo: %.1f min\n", as.numeric(difftime(Sys.time(), t0, units = "mins"))))

# ══ PARTE 4 — MONTAGEM DO BANCO (grao NB) ════════════════════════════════════
cat("\n═══ PARTE 4: montagem ═══\n")
dbExecute(con, "
  CREATE OR REPLACE TEMP TABLE tb_beneficio AS
  SELECT
    c.nb, c.clientela_codigo, c.clientela, c.nb_anterior, c.especie, c.especie_nome,
    c.cid, c.despacho_codigo, c.despacho, c.sexo_codigo, c.sexo,
    c.vl_juros_atrasados, c.vl_correcao_monetaria, c.vl_rmi, c.vl_rmi_convertido, c.rmi_em_sm,
    c.dt_ddb, c.dt_dib, c.dt_der, c.dt_dii, c.dt_nascimento,
    c.uf, c.uf_processadora, c.municipio_codigo, c.municipio, c.cpf,
    CASE WHEN k.cpf IS NOT NULL THEN 'S' ELSE 'N' END AS localizado_cadunico,
    k.uf_cad, k.municipio_cad_ibge, k.cod_local_domici_fam, k.cod_deficiencia_memb,
    k.ind_def_cegueira_memb, k.ind_def_baixa_visao_memb, k.ind_def_surdez_profunda_memb,
    k.ind_def_surdez_leve_memb, k.ind_def_fisica_memb, k.ind_def_mental_memb,
    k.ind_def_sindrome_down_memb, k.ind_def_transtorno_mental_memb,
    k.cod_curso_frequentou_pessoa_memb, k.cod_trabalho_12_meses_memb,
    k.qtd_meses_12_meses_memb, k.val_renda_bruta_12_meses_memb,
    CASE WHEN r.cpf IS NOT NULL THEN 'S' ELSE 'N' END AS localizado_rais,
    r.vinculo_ativo_3112, r.tipo_vinculo, r.tipo_admissao, r.mes_admissao,
    r.faixa_tempo_emprego, r.tempo_emprego, r.faixa_remuneracao_media_sm,
    r.remuneracao_media_sm, r.valor_remuneracao_media,
    r.cbo_1994, r.cbo_2002, r.cnae_1, r.cnae_2
  FROM conc c
  LEFT JOIN cad  k ON c.cpf = k.cpf
  LEFT JOIN rais r ON c.cpf = r.cpf")
chk_b <- dbGetQuery(con, "
  SELECT COUNT(*) AS beneficios, COUNT(DISTINCT nb) AS nb_distintos,
         COUNT(*) FILTER (WHERE localizado_cadunico = 'S') AS no_cad,
         COUNT(*) FILTER (WHERE localizado_rais = 'S') AS na_rais
  FROM tb_beneficio")
print(chk_b)
if (chk_b$beneficios != chk_c$beneficios) stop("PARAR: o cruzamento mudou o numero de linhas (join duplicou).")
resumo <- as.data.table(dbGetQuery(con, "
  SELECT especie, year(dt_ddb) AS ano, COUNT(*) AS beneficios,
         COUNT(*) FILTER (WHERE cpf IS NULL) AS sem_cpf,
         COUNT(*) FILTER (WHERE localizado_cadunico = 'S') AS localizados_cadunico,
         ROUND(100.0 * COUNT(*) FILTER (WHERE localizado_cadunico = 'S') / COUNT(*), 1) AS pct_cadunico,
         COUNT(*) FILTER (WHERE localizado_rais = 'S') AS localizados_rais,
         ROUND(100.0 * COUNT(*) FILTER (WHERE localizado_rais = 'S') / COUNT(*), 1) AS pct_rais
  FROM tb_beneficio GROUP BY 1, 2 ORDER BY 1, 2"))
cat("\nLocalizacao por especie e ano (AGREGADO — este e o unico que sai do servidor):\n")
print(resumo)
cat("    (esperado: B88 com % Cad bem acima de B21/B41; % RAIS baixo nas tres,\n")
cat("     maior nas concessoes recentes. B88 = BPC, inscricao no Cad e exigida)\n")

# ══ PARTE 5 — GRAVACAO: banco DuckDB + parquet + documentacao ════════════════
cat("\n═══ PARTE 5: gravacao ═══\n")
arq_db  <- sprintf("%s/%s.duckdb",  dir_saida, nome_banco)
arq_pq  <- sprintf("%s/%s.parquet", dir_saida, nome_banco)
arq_doc <- sprintf("%s/%s_DOCUMENTACAO.txt", dir_saida, nome_banco)
arq_dic <- sprintf("%s/%s_dicionario.csv", dir_saida, nome_banco)
arq_res <- sprintf("%s/%s_resumo_localizacao.csv", dir_saida, nome_banco)
if (file.exists(arq_db)) file.remove(arq_db)
dbExecute(con, sprintf("ATTACH '%s' AS banco", arq_db))
dbExecute(con, "CREATE TABLE banco.tb_beneficio AS SELECT * FROM tb_beneficio")
dbExecute(con, "DETACH banco")
dbExecute(con, sprintf("COPY tb_beneficio TO '%s' (FORMAT PARQUET)", arq_pq))
fwrite(resumo, arq_res)
cat("Gravados:", arq_db, "|", arq_pq, "|", arq_res, "\n")

dic <- data.table(rbind(
  c("nb", "Concedidos", C_NB, "numero do beneficio; chave unica do banco"),
  c("clientela_codigo / clientela", "Concedidos", paste(C_CLI, C_CLIN, sep = " / "), "codigo e nome"),
  c("nb_anterior", "Concedidos", C_NBANT, ""),
  c("especie / especie_nome", "Concedidos", paste(C_ESP, C_ESPN, sep = " / "), "numero extraido do campo codigo"),
  c("cid", "Concedidos", ifelse(is.null(C_CID), "(ausente)", C_CID), "preenchido so nas especies de incapacidade; vazio e esperado nas demais"),
  c("despacho_codigo / despacho", "Concedidos", paste(C_DESP, C_DESPN, sep = " / "), ""),
  c("sexo_codigo / sexo", "Concedidos", paste(C_SEXO, C_SEXON, sep = " / "), ""),
  c("vl_juros_atrasados", "Concedidos", C_JUROS, "numerico; virgula decimal convertida"),
  c("vl_correcao_monetaria", "Concedidos", C_CORR, "idem"),
  c("vl_rmi", "Concedidos", C_RMI, "RMI nominal na concessao"),
  c("vl_rmi_convertido", "Concedidos", C_RMICONV, "ATENCAO: convertido ao SM da data de carga de cada arquivo anual (moedas misturadas entre anos); para comparar use rmi_em_sm"),
  c("rmi_em_sm", "Concedidos", ifelse(is.null(C_RMISM), "(ausente)", C_RMISM), "RMI em multiplos do SM (campo extra, comparavel entre anos)"),
  c("dt_ddb / dt_dib / dt_der / dt_dii / dt_nascimento", "Concedidos", paste(C_DDB, C_DIB, C_DER, C_DII, C_NASC, sep = " / "), "datas; formatos ddmmaaaa, dd/mm/aaaa e aaaa-mm-dd aceitos"),
  c("uf", "Concedidos (derivada)", C_MUNC, "UF de RESIDENCIA: 2 primeiros digitos do codigo de municipio (numeracao SUIBE)"),
  c("uf_processadora", "Concedidos", C_UF, "campo 'UF' original = unidade que PROCESSOU a concessao (DF concentra ~44%); nao e residencia"),
  c("municipio_codigo / municipio", "Concedidos", paste(C_MUNC, C_MUNN, sep = " / "), "municipio de residencia do titular"),
  c("cpf", "Concedidos", C_CPF, "11 digitos com zeros a esquerda; vazio ou so zeros = NULL; chave dos cruzamentos"),
  c("localizado_cadunico", "derivada", "", "S se o CPF existe no CadUnico 06/2024 (estado cadastral 3); N caso contrario"),
  c("uf_cad", "CadUnico familia", "cd_ibge_cadastro", "sigla pelos 2 primeiros digitos do IBGE"),
  c("municipio_cad_ibge", "CadUnico familia", "cd_ibge_cadastro", "IBGE 7 digitos"),
  c("cod_local_domici_fam", "CadUnico familia", "co_local_domic_fam", "1 urbano, 2 rural"),
  c("cod_deficiencia_memb", "CadUnico pessoa", "co_deficiencia_memb", ""),
  c("ind_def_* (8 flags)", "CadUnico pessoa", "in_def_*_memb", "cegueira, baixa visao, surdez profunda, surdez leve, fisica, mental, sindrome de down, transtorno mental"),
  c("cod_curso_frequentou_pessoa_memb", "CadUnico pessoa", "co_curso_freq_pessoa_memb", ""),
  c("cod_trabalho_12_meses_memb", "CadUnico pessoa", "co_trabalho_12_meses_memb", ""),
  c("qtd_meses_12_meses_memb", "CadUnico pessoa", "qt_meses_12_meses_memb", ""),
  c("val_renda_bruta_12_meses_memb", "CadUnico pessoa", "fx_renda_individual_808",
    if (renda808_e_faixa) "ATENCAO: no Cad tratado este campo vem como FAIXA (poucos niveis), nao como valor em reais" else "valor em reais"),
  c("localizado_rais", "derivada", "", sprintf("S se o CPF tem ao menos um vinculo na RAIS %d", ANO_RAIS)),
  c("vinculo_ativo_3112", "RAIS", "vinculo_ativo_31_12", "1 = vinculo principal estava ativo em 31/12"),
  c("tipo_vinculo / tipo_admissao", "RAIS", "tipo_vinculo / tipo_admissao", "codigos da RAIS"),
  c("mes_admissao", "RAIS (derivada)", "data_admissao", "mes da data de admissao"),
  c("tempo_emprego", "RAIS", "tempo_emprego", "meses no vinculo"),
  c("faixa_tempo_emprego", "RAIS (derivada)", "tempo_emprego", "regua do layout da RAIS: <3, 3-5,9, 6-11,9, 12-23,9, 24-35,9, 36-59,9, 60-119,9, 120+ meses"),
  c("valor_remuneracao_media", "RAIS", "vl_remun_media_nom", "remuneracao media do ano, em reais"),
  c("remuneracao_media_sm", "RAIS", "vl_remun_media_sm", "remuneracao media em SM (campo extra)"),
  c("faixa_remuneracao_media_sm", "RAIS (derivada)", "vl_remun_media_sm", "regua do layout da RAIS: ate 0,5; 0,51-1; 1,01-1,5; 1,51-2; 2,01-3; 3,01-4; 4,01-5; 5,01-7; 7,01-10; 10,01-15; 15,01-20; >20 SM"),
  c("cbo_1994 / cbo_2002", "RAIS", "cbo_94 / cbo_2002", ""),
  c("cnae_1 / cnae_2", "RAIS", "cnae_95_classe / cnae_20_classe", "CNAE_1 = classe CNAE 95; CNAE_2 = classe CNAE 2.0")
))
setnames(dic, c("coluna_banco", "origem", "campo_fonte", "regra_ou_observacao"))
fwrite(dic, arq_dic)

doc <- c(
  sprintf("BANCO %s — DOCUMENTACAO (gerado em %s)", toupper(nome_banco), format(Sys.time(), "%d/%m/%Y %H:%M")),
  "",
  "1. O QUE E",
  "   Uma linha por beneficio (NB) concedido pelo INSS nas especies 21, 41 e 88,",
  "   com os campos do layout TB_BENEFICIO: dados da concessao, localizacao e",
  "   campos cadastrais no CadUnico, e vinculo principal na RAIS.",
  sprintf("   Linhas: %s | NBs distintos: %s", format(chk_b$beneficios, big.mark = ".", decimal.mark = ","), format(chk_b$nb_distintos, big.mark = ".", decimal.mark = ",")),
  "",
  "2. FONTES",
  sprintf("   Concedidos INSS (extratos anuais %d-%d), especies %s.", chk_c$ano_min, chk_c$ano_max, paste(ESPECIES, collapse = ", ")),
  sprintf("   CadUnico base tratada de %d (extracao de junho/%d), nivel pessoa + familia.", ANO_CAD, ANO_CAD),
  sprintf("   RAIS %d identificada (vinculos), formato colunar.", ANO_RAIS),
  "",
  "3. UNIVERSO E DEDUPLICACAO",
  "   Todos os NBs das tres especies em todos os anos disponiveis. Quando o",
  "   mesmo NB aparece em mais de um extrato anual, fica o registro de data de",
  "   carga mais recente (desempate: DDB mais recente).",
  sprintf("   Beneficios sem CPF valido: %s (ficam no banco, sem cruzamento).", format(chk_c$sem_cpf, big.mark = ".", decimal.mark = ",")),
  "",
  "4. CHAVE DE CRUZAMENTO",
  "   CPF com 11 digitos (zeros a esquerda), nas tres fontes. CPF vazio ou",
  "   composto so de zeros e tratado como ausente.",
  "",
  "5. CADUNICO",
  "   Pessoas com estado cadastral 3 (cadastrado) e CPF informado. Se a mesma",
  "   pessoa aparece mais de uma vez, fica o registro da familia com data de",
  "   atualizacao mais recente. UF e municipio sao os do cadastro da familia.",
  sprintf("   Pessoas com CPF apos deduplicacao: %s.", format(chk_cad$pessoas_com_cpf, big.mark = ".", decimal.mark = ",")),
  sprintf("   Beneficios localizados no Cad: %s (%.1f%%).", format(chk_b$no_cad, big.mark = ".", decimal.mark = ","), 100 * chk_b$no_cad / chk_b$beneficios),
  if (renda808_e_faixa) "   AVISO: a renda bruta de 12 meses vem como FAIXA no Cad tratado, nao em reais." else "   Renda bruta de 12 meses em reais.",
  sprintf("   Pessoas do Cad sem registro de familia correspondente: %s (UF, municipio e", format(chk_cad$sem_familia, big.mark = ".", decimal.mark = ",")),
  "   local do domicilio ficam vazios para elas; o banco de beneficios nao e afetado).",
  "   Beneficios de 2025 e 2026 tendem a ter menor localizacao no Cad porque a",
  "   foto do Cad e de junho/2024 (inscricoes posteriores nao aparecem).",
  "",
  "6. RAIS — VINCULO PRINCIPAL",
  "   Entre os vinculos do CPF no ano: (1) o vinculo ATIVO em 31/12 de maior",
  "   remuneracao media; (2) se nenhum ativo, o ULTIMO desligado no ano (mes e",
  "   dia de desligamento mais tardios; empate pela maior remuneracao media).",
  "   Faixas de tempo de emprego e de remuneracao derivadas pelas reguas do",
  "   layout da RAIS (ver dicionario). Mes de admissao derivado da data.",
  "   Faixa de remuneracao vazia = remuneracao media igual a zero no ano (vinculo",
  "   sem remuneracao, por exemplo afastado o ano inteiro); o vinculo e mantido.",
  sprintf("   Beneficios localizados na RAIS: %s (%.1f%%).", format(chk_b$na_rais, big.mark = ".", decimal.mark = ","), 100 * chk_b$na_rais / chk_b$beneficios),
  "",
  "7. AVISOS DE USO",
  "   - 'uf_processadora' e a unidade do INSS que processou a concessao (nao a",
  "     residencia); para recortes regionais use 'uf' e 'municipio' (residencia).",
  "   - 'vl_rmi_convertido' mistura moedas entre anos; use 'rmi_em_sm'.",
  "   - CID so existe nas especies de incapacidade; vazio e esperado em 21/41/88.",
  "   - Banco IDENTIFICADO (CPF, NB): uso restrito ao servidor; so agregados saem.",
  "",
  "8. ARQUIVOS",
  sprintf("   %s (tabela tb_beneficio) | %s (mesmo conteudo)", basename(arq_db), basename(arq_pq)),
  sprintf("   %s (dicionario de colunas) | %s (agregado por especie e ano)", basename(arq_dic), basename(arq_res))
)
writeLines(doc, arq_doc)
cat("Documentacao:", arq_doc, "\nDicionario:", arq_dic, "\n")
cat(sprintf("\nConcluido em %.1f min.\n", as.numeric(difftime(Sys.time(), t0, units = "mins"))))
dbDisconnect(con, shutdown = TRUE)
unlink(file.path(dir_saida, "duckdb_tmp"), recursive = TRUE)   # apaga os pontos de retomada
