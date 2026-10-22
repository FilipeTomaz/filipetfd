# Acrescenta ao banco_beneficio_cad_rais tres colunas de RENDA FAMILIAR do
# CadUnico 06/2024 (nivel familia, em REAIS — o que nao existe no nivel
# pessoa, onde a renda vem so em faixas):
#   vl_renda_media_fam  = renda familiar PER CAPITA media (regua do 1/4 SM)
#   vl_renda_total_fam  = renda total da familia
#   qt_membro_familia   = numero de membros
# REGRAS: a familia de cada CPF e reatribuida com a MESMA regra do banco
# (pessoa com estado cadastral 3; em duplicidade, a familia de atualizacao
# mais recente), garantindo consistencia com localizado_cadunico.
# Atualiza o .duckdb e regrava o .parquet do banco. 

library(duckdb)

dir_saida  <- "E:/01_Bases/09_PREVIDENCIA/04_Dados/Saidas"
arq_db     <- file.path(dir_saida, "banco_beneficio_cad_rais.duckdb")
arq_pq     <- file.path(dir_saida, "banco_beneficio_cad_rais.parquet")
arq_doc    <- file.path(dir_saida, "banco_beneficio_cad_rais_DOCUMENTACAO.txt")
dir_cad    <- "E:/01_Bases/14_FNDE_FIES/02_C\u00f3digos/output/parquet"
arq_cad_p  <- file.path(dir_cad, "cadunico_pessoa_2024_tratado.parquet")
arq_cad_f  <- file.path(dir_cad, "cadunico_familia_2024_tratado.parquet")
arq_fam_txt<- "E:/01_Bases/02_CADUNICO/01_Bases prim\u00e1rias/2024/ARQ_FAMILIA_PBF_15062024_SB8.TXT"

if (!file.exists(arq_db)) stop("Banco nao encontrado: ", arq_db)
con <- dbConnect(duckdb(arq_db))
dbExecute(con, "SET preserve_insertion_order=false")

cat(">>> Estado atual do banco...\n")
print(dbGetQuery(con, "
  SELECT COUNT(*) AS beneficios,
         COUNT(*) FILTER (WHERE localizado_cadunico = 'S') AS no_cad
  FROM tb_beneficio"))

# ── 1. De onde vem a renda da familia? ───────────────────────────────────────
cols_f <- dbGetQuery(con, sprintf("DESCRIBE SELECT * FROM read_parquet('%s')", arq_cad_f))$column_name
tem_renda_parquet <- all(c("vl_renda_media_fam", "vl_renda_total_fam", "qt_membro_familia")
                         %in% tolower(cols_f))
pv <- function(col) sprintf(
  "TRY_CAST(CASE WHEN CAST(\"%s\" AS VARCHAR) LIKE '%%,%%'
    THEN replace(replace(CAST(\"%s\" AS VARCHAR), '.', ''), ',', '.')
    ELSE CAST(\"%s\" AS VARCHAR) END AS DOUBLE)", col, col, col)
if (tem_renda_parquet) {
  cat("  Renda disponivel no parquet tratado da familia — usando-o.\n")
  fonte_fam <- sprintf("SELECT CAST(co_familiar_fam AS VARCHAR) AS co_familiar,
                               TRY_CAST(vl_renda_media_fam AS DOUBLE) AS vl_renda_media_fam,
                               TRY_CAST(vl_renda_total_fam AS DOUBLE) AS vl_renda_total_fam,
                               TRY_CAST(qt_membro_familia AS INTEGER) AS qt_membro_familia
                        FROM read_parquet('%s')", arq_cad_f)
  origem_renda <- "parquet tratado da familia (projeto FIES)"
} else {
  cat("  Parquet tratado sem os campos de renda — lendo o TXT bruto da familia.\n")
  fonte_fam <- sprintf("SELECT CAST(CO_FAMILIAR_FAM AS VARCHAR) AS co_familiar,
                               %s AS vl_renda_media_fam,
                               %s AS vl_renda_total_fam,
                               TRY_CAST(QT_MEMBRO_FAMILIA AS INTEGER) AS qt_membro_familia
                        FROM read_csv_auto('%s', delim=';', encoding='latin-1',
                             union_by_name=true, all_varchar=true, sample_size=20000,
                             strict_mode=false, null_padding=true)",
                       pv("VL_RENDA_MEDIA_FAM"), pv("VL_RENDA_TOTAL_FAM"), arq_fam_txt)
  origem_renda <- "ARQ_FAMILIA_PBF_15062024 (TXT bruto)"
}

# ── 2. Mapa CPF -> familia (mesma regra do banco) ────────────────────────────
cat("\n>>> Reatribuindo a familia de cada CPF (mesma regra do banco)...\n")
dbExecute(con, sprintf("
  CREATE OR REPLACE TEMP TABLE cpf_fam AS
  SELECT cpf, co_familiar FROM (
    SELECT
      CASE WHEN length(regexp_replace(CAST(p.nu_cpf_pessoa AS VARCHAR), '[^0-9]', '', 'g')) BETWEEN 1 AND 11
            AND regexp_replace(CAST(p.nu_cpf_pessoa AS VARCHAR), '[^0-9]', '', 'g')
                <> repeat('0', length(regexp_replace(CAST(p.nu_cpf_pessoa AS VARCHAR), '[^0-9]', '', 'g')))
           THEN lpad(regexp_replace(CAST(p.nu_cpf_pessoa AS VARCHAR), '[^0-9]', '', 'g'), 11, '0')
           ELSE NULL END AS cpf,
      CAST(p.co_familiar_fam AS VARCHAR) AS co_familiar,
      ROW_NUMBER() OVER (
        PARTITION BY lpad(regexp_replace(CAST(p.nu_cpf_pessoa AS VARCHAR), '[^0-9]', '', 'g'), 11, '0')
        ORDER BY f.dt_atualizacao_fam DESC NULLS LAST, p.co_familiar_fam DESC) AS rn
    FROM read_parquet('%s') p
    LEFT JOIN read_parquet('%s') f ON p.co_familiar_fam = f.co_familiar_fam
    WHERE p.co_est_cadastral_memb = 3 AND p.nu_cpf_pessoa IS NOT NULL
  ) WHERE rn = 1 AND cpf IS NOT NULL", arq_cad_p, arq_cad_f))

dbExecute(con, sprintf("
  CREATE OR REPLACE TEMP TABLE renda AS
  SELECT m.cpf, f.vl_renda_media_fam, f.vl_renda_total_fam, f.qt_membro_familia
  FROM cpf_fam m
  JOIN (SELECT *, ROW_NUMBER() OVER (PARTITION BY co_familiar) AS rnf
        FROM (%s)) f
    ON m.co_familiar = f.co_familiar AND f.rnf = 1", fonte_fam))
print(dbGetQuery(con, "SELECT COUNT(*) AS cpfs_com_renda FROM renda"))

# ── 3. Acrescenta as colunas ao banco ────────────────────────────────────────
cat("\n>>> Atualizando tb_beneficio...\n")
for (c in c("vl_renda_media_fam DOUBLE", "vl_renda_total_fam DOUBLE", "qt_membro_familia INTEGER"))
  try(dbExecute(con, sprintf("ALTER TABLE tb_beneficio ADD COLUMN %s", c)), silent = TRUE)
dbExecute(con, "
  UPDATE tb_beneficio t SET
    vl_renda_media_fam = r.vl_renda_media_fam,
    vl_renda_total_fam = r.vl_renda_total_fam,
    qt_membro_familia  = r.qt_membro_familia
  FROM renda r WHERE t.cpf = r.cpf")

cat("\n=== CHECAGENS (agregadas) ===\n")
chk <- dbGetQuery(con, "
  SELECT COUNT(*) AS beneficios,
         COUNT(*) FILTER (WHERE localizado_cadunico = 'S') AS no_cad,
         COUNT(*) FILTER (WHERE localizado_cadunico = 'S' AND vl_renda_media_fam IS NOT NULL) AS no_cad_com_renda,
         ROUND(100.0 * COUNT(*) FILTER (WHERE localizado_cadunico = 'S' AND vl_renda_media_fam IS NOT NULL)
               / NULLIF(COUNT(*) FILTER (WHERE localizado_cadunico = 'S'), 0), 1) AS pct_cobertura,
         COUNT(*) FILTER (WHERE localizado_cadunico = 'N' AND vl_renda_media_fam IS NOT NULL) AS fora_cad_com_renda
  FROM tb_beneficio")
print(chk)
cat("    (pct_cobertura deve ser ~100 — a renda so pode faltar nos 'S' cuja familia\n")
cat("     nao tinha registro; fora_cad_com_renda deve ser 0 por construcao)\n")
if (chk$fora_cad_com_renda > 0) stop("PARAR: renda atribuida a beneficio fora do Cad.")

cat("\n--- Sanidade da regua do 1/4 SM (SM 2024 = renda per capita <= 353) ---\n")
print(dbGetQuery(con, "
  SELECT especie,
         COUNT(*) FILTER (WHERE vl_renda_media_fam IS NOT NULL) AS com_renda,
         ROUND(median(vl_renda_media_fam), 0) AS renda_pc_mediana,
         ROUND(100.0 * COUNT(*) FILTER (WHERE vl_renda_media_fam <= 353)
               / NULLIF(COUNT(*) FILTER (WHERE vl_renda_media_fam IS NOT NULL), 0), 1) AS pct_ate_quarto_sm
  FROM tb_beneficio WHERE localizado_cadunico = 'S'
  GROUP BY 1 ORDER BY 1"))
cat("    (B88/BPC deve ter pct_ate_quarto_sm ALTO — e o criterio legal do beneficio;\n")
cat("     atencao: a renda do Cad pode ja INCLUIR o proprio beneficio recebido)\n")

# ── 4. Regrava o parquet e atualiza a documentacao ───────────────────────────
dbExecute(con, sprintf("COPY tb_beneficio TO '%s' (FORMAT PARQUET)", arq_pq))
cat("\n>> Parquet do banco regravado.\n")
cat(c("\n10. RENDA FAMILIAR (acrescentada em ", format(Sys.Date(), "%d/%m/%Y"), ")\n",
      "   Colunas novas: vl_renda_media_fam (renda familiar PER CAPITA media, em\n",
      "   reais — regua do teste de 1/4 SM), vl_renda_total_fam e qt_membro_familia.\n",
      "   Fonte: ", origem_renda, ". Familia reatribuida por CPF com a mesma regra\n",
      "   do banco (estado cadastral 3; atualizacao mais recente). Preenchidas so\n",
      "   para localizado_cadunico = 'S'.\n",
      "   AVISO: a renda declarada no Cad pode ja incluir o beneficio previdenciario\n",
      "   ou assistencial recebido — para contrafactuais, considerar o expurgo.\n"),
    file = arq_doc, append = TRUE, sep = "")
cat(">> Documentacao atualizada:", arq_doc, "\n")
dbDisconnect(con, shutdown = TRUE)
