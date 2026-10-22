# Geração de exemplo inteiramente fictício: somente R base, sem fontes identificadas.
# No BPI.Rproj: source('scripts/gerar_base_sintetica.R'); gerar_exemplo_bpi()
# No terminal: Rscript scripts/gerar_base_sintetica.R [quantidade] [semente]

faixa_tempo_bpi <- function(x) {
  limites <- c(-Inf,3,6,12,24,36,60,120,Inf)
  rotulos <- c('<3','3-5,9','6-11,9','12-23,9','24-35,9','36-59,9','60-119,9','120+')
  as.character(cut(x,limites,right=FALSE,labels=rotulos))
}

faixa_remuneracao_bpi <- function(x) {
  limites <- c(0,.5,1,1.5,2,3,4,5,7,10,15,20,Inf)
  rotulos <- c('Até 0,5','0,51-1','1,01-1,5','1,51-2','2,01-3','3,01-4',
    '4,01-5','5,01-7','7,01-10','10,01-15','15,01-20','Acima de 20')
  as.character(cut(x,limites,right=TRUE,labels=rotulos))
}

# CPF de teste com primeiro DV calculado e segundo DV deliberadamente incorreto.
cpf_ficticio_bpi <- function(i) {
  prefixo <- sprintf('%09d',i)
  d <- as.integer(strsplit(prefixo,'',fixed=TRUE)[[1]])
  dv <- function(x,pesos) {r <- sum(x*pesos) %% 11; if (r < 2) 0L else 11L-r}
  a <- dv(d,10:2)
  b <- dv(c(d,a),11:2)
  paste0(prefixo,a,(b+1L) %% 10L)
}

simular_bpi <- function(n_beneficios=30L,semente=20261022L) {
  if (length(n_beneficios)!=1L || !is.finite(n_beneficios) ||
      n_beneficios!=floor(n_beneficios) || n_beneficios<12 || n_beneficios>100000)
    stop('n_beneficios deve ser inteiro entre 12 e 100000.')
  if (length(semente)!=1L || !is.finite(semente) || semente!=floor(semente) ||
      semente<0 || semente>.Machine$integer.max) stop('Semente inválida.')
  set.seed(semente,kind='Mersenne-Twister',normal.kind='Inversion',sample.kind='Rejection')
  n <- as.integer(n_beneficios); np <- ceiling(.8*n)
  pessoa <- c(seq_len(np),sample.int(np,n-np,replace=TRUE))
  especie <- rep(c(21L,41L,88L),length.out=n)
  sexo <- sample(c('M','F'),np,replace=TRUE)
  nasc <- as.Date('1938-01-01')+sample.int(15000,np,replace=TRUE)-1
  idosos <- unique(pessoa[especie %in% c(41L,88L)])
  nasc[idosos] <- as.Date('1938-01-01')+sample.int(6000,length(idosos),replace=TRUE)-1
  cpf <- vapply(seq_len(np),cpf_ficticio_bpi,character(1))
  cad <- rep(c(TRUE,TRUE,FALSE,FALSE),length.out=np)
  rais <- rep(c(TRUE,FALSE,TRUE,FALSE),length.out=np)
  cpf[np] <- NA_character_; cad[np] <- rais[np] <- FALSE
  ufs <- c('SP','BA','MG','PE','RS')
  nomes <- c('São Paulo','Salvador','Belo Horizonte','Recife','Porto Alegre')
  ibge <- c('3550308','2927408','3106200','2611606','4314902')
  municipio_pessoa <- sample.int(5,np,replace=TRUE)

  # Uma linha por pessoa; repetições de CPF reutilizam todos esses atributos.
  p <- data.frame(cpf,sexo_codigo=paste0('SIM_',sexo),
    sexo=ifelse(sexo=='M','MASCULINO','FEMININO'),dt_nascimento=nasc,
    localizado_cadunico=ifelse(cad,'S','N'),localizado_rais=ifelse(rais,'S','N'),
    stringsAsFactors=FALSE)
  p$uf_cad <- ifelse(cad,ufs[municipio_pessoa],NA_character_)
  p$municipio_cad_ibge <- ifelse(cad,ibge[municipio_pessoa],NA_character_)
  p$cod_local_domici_fam <- ifelse(cad,sample(c(1L,2L),np,replace=TRUE),NA_integer_)
  deficientes <- sample(c(FALSE,TRUE),np,replace=TRUE,prob=c(.8,.2))
  p$cod_deficiencia_memb <- ifelse(cad,ifelse(deficientes,1,2),NA_real_)
  inds <- paste0('ind_def_',c('cegueira','baixa_visao','surdez_profunda','surdez_leve',
    'fisica','mental','sindrome_down','transtorno_mental'),'_memb')
  tipo_def <- sample.int(length(inds),np,replace=TRUE)
  for (j in seq_along(inds)) p[[inds[j]]] <- ifelse(cad,as.numeric(deficientes & tipo_def==j),NA_real_)
  p$cod_curso_frequentou_pessoa_memb <- ifelse(cad,sample(1:8,np,replace=TRUE),NA_real_)
  trabalha <- sample(c(TRUE,FALSE),np,replace=TRUE)
  p$cod_trabalho_12_meses_memb <- ifelse(cad,ifelse(trabalha,1,2),NA_real_)
  p$qtd_meses_12_meses_memb <- ifelse(cad,ifelse(trabalha,sample(1:12,np,replace=TRUE),0),NA_real_)
  # Faixa sintética, NÃO valor em reais.
  p$val_renda_bruta_12_meses_memb <- ifelse(cad,ifelse(trabalha,sample(1:6,np,replace=TRUE),0),NA_real_)

  p$vinculo_ativo_3112 <- ifelse(rais,sample(c(0L,1L),np,replace=TRUE),NA_integer_)
  p$tipo_vinculo <- ifelse(rais,'SIM_VINCULO',NA_character_)
  p$tipo_admissao <- ifelse(rais,'SIM_ADMISSAO',NA_character_)
  p$mes_admissao <- ifelse(rais,sample(1:12,np,replace=TRUE),NA_integer_)
  p$tempo_emprego <- ifelse(rais,round(runif(np,1,180),1),NA_real_)
  p$faixa_tempo_emprego <- faixa_tempo_bpi(p$tempo_emprego)
  p$remuneracao_media_sm <- ifelse(rais,round(runif(np,.4,8),3),NA_real_)
  p$remuneracao_media_sm[which(rais)[1]] <- 0
  p$valor_remuneracao_media <- round(p$remuneracao_media_sm*1412,2)
  p$faixa_remuneracao_media_sm <- faixa_remuneracao_bpi(p$remuneracao_media_sm)
  for (campo in c('cbo_1994','cbo_2002','cnae_1','cnae_2'))
    p[[campo]] <- ifelse(rais,paste0('SIM_',toupper(campo)),NA_character_)

  # Famílias auxiliares compartilhadas; o identificador não entra nas 61 colunas.
  familia <- ceiling(seq_len(np)/2); nf <- max(familia)
  membros <- sample(2:6,nf,replace=TRUE)
  per_capita <- round(runif(nf,80,2500),2)
  total <- round(per_capita*membros,2)
  familia_preenchida <- cad
  familia_preenchida[which(cad)[3]] <- FALSE
  p$qt_membro_familia <- ifelse(familia_preenchida,membros[familia],NA_integer_)
  p$vl_renda_total_fam <- ifelse(familia_preenchida,total[familia],NA_real_)
  p$vl_renda_media_fam <- ifelse(familia_preenchida,per_capita[familia],NA_real_)

  der <- as.Date('2020-01-01')+sample.int(2192,n,replace=TRUE)-1
  ddb <- pmin(der+sample(0:180,n,replace=TRUE),as.Date('2025-12-31'))
  dib <- pmin(ddb,der+sample(-60:30,n,replace=TRUE))
  # Piso anual adotado no EXERCÍCIO (2020/2023 têm ajustes intranuais abaixo).
  piso <- c('2020'=1045,'2021'=1100,'2022'=1212,'2023'=1320,'2024'=1412,'2025'=1518)
  sm <- unname(piso[format(ddb,'%Y')])
  sm[ddb<as.Date('2020-02-01')] <- 1039
  sm[ddb>=as.Date('2023-01-01') & ddb<as.Date('2023-05-01')] <- 1302
  rmi_sm <- ifelse(especie==88L,1,round(runif(n,1,3.5),3))
  nb <- sprintf('%010.0f',9000000000+seq_len(n))
  anterior <- rep(NA_character_,n)
  ultimo <- rep(NA_integer_,np)
  for (i in order(ddb,dib,seq_len(n))) {
    j <- ultimo[pessoa[i]]
    if (!is.na(j) && dib[j]<=dib[i]) anterior[i] <- nb[j]
    ultimo[pessoa[i]] <- i
  }
  clientela <- sample(c('0','1','2'),n,replace=TRUE,prob=c(.05,.5,.45))
  clientela[1:3] <- c('0','1','2')
  local <- municipio_pessoa[pessoa]
  df <- data.frame(nb,clientela_codigo=clientela,
    clientela=unname(c('0'='NÃO INFORMADA','1'='URBANA','2'='RURAL')[clientela]),
    nb_anterior=anterior,especie,
    especie_nome=unname(c('21'='PENSÃO POR MORTE','41'='APOSENTADORIA POR IDADE',
      '88'='BPC AO IDOSO')[as.character(especie)]),
    cid=ifelse(seq_len(n) %% 11==0,'I10',NA_character_),
    despacho_codigo='SIM_CONCESSAO',despacho='CONCESSÃO SINTÉTICA',
    vl_juros_atrasados=round(runif(n,0,300),2),
    vl_correcao_monetaria=round(runif(n,0,150),2),
    vl_rmi=round(rmi_sm*sm,2),
    vl_rmi_convertido=round(rmi_sm*1412,2),rmi_em_sm=rmi_sm,
    dt_ddb=ddb,dt_dib=dib,dt_der=der,
    dt_dii=as.Date(rep(NA_character_,n)),uf=ufs[local],
    uf_processadora=sample(ufs,n,replace=TRUE),
    municipio_codigo=paste0('SIM_SUIBE_',ufs[local]),municipio=nomes[local],
    stringsAsFactors=FALSE)
  tem_cid <- !is.na(df$cid)
  df$dt_dii[tem_cid] <- df$dt_der[tem_cid]-sample(10:1000,sum(tem_cid),replace=TRUE)
  for (campo in names(p)) df[[campo]] <- p[[campo]][pessoa]
  contrib <- round(runif(n,0,40),2)
  contrib[especie==88L] <- 0
  contrib[especie==21L & seq_len(n) %% 4L==1L] <- NA_real_
  # Preserva também zero e ausência em registros de aposentadoria por idade.
  contrib[which(especie==41L)[1:2]] <- c(0,NA_real_)
  df$qt_anos_contribuicao <- contrib
  df
}

ler_bpi_sintetico <- function(arquivo,esquema) {
  # CSV não armazena tipos: impedir inferência numérica de CPF/NB/códigos.
  x <- read.csv(arquivo,colClasses='character',na.strings='',check.names=FALSE,
    fileEncoding='UTF-8',stringsAsFactors=FALSE)
  if (!identical(names(x),esquema$variavel)) stop('CSV não corresponde ao esquema de 61 colunas.')
  for (i in seq_len(nrow(esquema))) {
    v <- esquema$variavel[i];t <- esquema$tipo_duckdb[i]
    if (t=='DATE') x[[v]] <- as.Date(x[[v]])
    if (t=='DOUBLE') x[[v]] <- as.numeric(x[[v]])
    # mes_admissao (BIGINT) só contém 1–12; cabe sem perda em integer do R.
    if (t %in% c('INTEGER','BIGINT')) x[[v]] <- as.integer(x[[v]])
  }
  x
}

gerar_exemplo_bpi <- function(n_beneficios=30L,semente=20261022L,raiz='.') {
  schema <- read.csv(file.path(raiz,'esquemas/banco_beneficio_cad_rais_61.csv'),
    colClasses='character',stringsAsFactors=FALSE)
  df <- simular_bpi(n_beneficios,semente)
  stopifnot(nrow(schema)==61L,setequal(names(df),schema$variavel))
  df <- df[schema$variavel]
  destino <- file.path(raiz,'dados/sinteticos')
  dir.create(destino,recursive=TRUE,showWarnings=FALSE)
  write.csv(df,file.path(destino,'bpi_sintetico_61.csv'),row.names=FALSE,na='',
    fileEncoding='UTF-8')
  manifesto <- data.frame(item=c('natureza','n_beneficios','n_colunas',
    'pessoas_com_cpf','beneficios_sem_cpf','semente','formato_datas','ausencia',
    'identificadores','dominios_nao_confirmados','renda_808','rmi_convertido',
    'distribuicao','versao_R'),valor=c('INTEIRAMENTE_SINTETICO',nrow(df),ncol(df),
    length(unique(na.omit(df$cpf))),sum(is.na(df$cpf)),semente,'YYYY-MM-DD',
    'Campo vazio = NA; zero permanece zero','CPF com segundo DV inválido; NB fictício sequencial',
    'Convenções sintéticas descritas no README','Código de faixa sintética, não reais',
    'Normalização didática por SM de referência de 2024; não replica a fonte',
    'Exemplo funcional; sem representatividade populacional',as.character(getRversion())))
  write.csv(manifesto,file.path(destino,'manifesto.csv'),row.names=FALSE,
    fileEncoding='UTF-8')
  message('CSV sintético gerado: ',nrow(df),' linhas e ',ncol(df),' colunas.')
  invisible(df)
}

if (sys.nframe()==0L) {
  args <- commandArgs(trailingOnly=TRUE)
  script <- sub('^--file=','',grep('^--file=',commandArgs(),value=TRUE)[1])
  raiz <- normalizePath(file.path(dirname(script),'..'),mustWork=TRUE)
  gerar_exemplo_bpi(if (length(args)>=1) as.numeric(args[1]) else 30L,
    if (length(args)>=2) as.numeric(args[2]) else 20261022L,raiz)
}
