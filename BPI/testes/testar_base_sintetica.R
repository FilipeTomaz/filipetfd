# Execute a partir de BPI: Rscript testes/testar_base_sintetica.R
source('scripts/gerar_base_sintetica.R')
schema <- read.csv('esquemas/banco_beneficio_cad_rais_61.csv',colClasses='character')
x <- ler_bpi_sintetico('dados/sinteticos/bpi_sintetico_61.csv',schema)
stopifnot(nrow(x)==30L,ncol(x)==61L,identical(names(x),schema$variavel),
  !anyDuplicated(x$nb),!anyNA(x$nb),anyDuplicated(na.omit(x$cpf))>0,
  all(nchar(na.omit(x$cpf))==11L),all(nchar(x$nb)==10L),
  identical(sort(unique(x$especie)),c(21L,41L,88L)),
  all(c('SS','SN','NS','NN') %in% paste0(x$localizado_cadunico,x$localizado_rais)))
for (i in seq_len(nrow(schema))) {
 t <- schema$tipo_duckdb[i];v <- x[[schema$variavel[i]]]
 stopifnot(switch(t,VARCHAR=is.character(v),DATE=inherits(v,'Date'),
   DOUBLE=is.double(v),INTEGER=is.integer(v),BIGINT=is.integer(v)))
}
# Verificação independente do gerador: nenhum CPF passa nos dois DVs.
cpf_valido <- function(cpf) {
 d <- as.integer(strsplit(cpf,'',fixed=TRUE)[[1]])
 if (length(unique(d))==1L) return(FALSE)
 resto1 <- (sum(d[1:9]*(10:2))*10) %% 11
 if (resto1==10) resto1 <- 0
 resto2 <- (sum(d[1:10]*(11:2))*10) %% 11
 if (resto2==10) resto2 <- 0
 d[10]==resto1 && d[11]==resto2
}
stopifnot(!any(vapply(na.omit(x$cpf),cpf_valido,logical(1))))
pessoais <- c('cpf','sexo','sexo_codigo','dt_nascimento',schema$variavel[27:60])
for (cpf in unique(na.omit(x$cpf))) {
 z <- x[!is.na(x$cpf) & x$cpf==cpf,pessoais,drop=FALSE]
 stopifnot(nrow(unique(z))==1L)
}
cad_cols <- c(schema$variavel[28:43],schema$variavel[58:60])
rais_cols <- schema$variavel[45:57]
stopifnot(all(is.na(x[x$localizado_cadunico=='N',cad_cols])),
 all(is.na(x[x$localizado_rais=='N',rais_cols])),
 all(x$dt_nascimento<x$dt_der),all(x$dt_ddb>=x$dt_der),
 all(x$dt_dib<=x$dt_ddb),any(x$dt_dib<x$dt_der),
 all(x$vl_rmi>=0),all(x$qt_anos_contribuicao>=0,na.rm=TRUE),
 any(is.na(x$qt_anos_contribuicao)),any(x$qt_anos_contribuicao==0,na.rm=TRUE),
 any(x$especie==21 & !is.na(x$qt_anos_contribuicao)),
 all(x$qtd_meses_12_meses_memb>=0 & x$qtd_meses_12_meses_memb<=12,na.rm=TRUE))
for (i in which(!is.na(x$nb_anterior))) {
 j <- match(x$nb_anterior[i],x$nb)
 stopifnot(!is.na(j),identical(x$cpf[i],x$cpf[j]),
   x$dt_dib[j]<=x$dt_dib[i],x$dt_ddb[j]<=x$dt_ddb[i])
}
fam <- !is.na(x$vl_renda_total_fam)
stopifnot(all(abs(x$vl_renda_total_fam[fam]-
 x$vl_renda_media_fam[fam]*x$qt_membro_familia[fam])<.011))
a <- simular_bpi(30,20261022);b <- simular_bpi(30,20261022);c <- simular_bpi(30,123)
stopifnot(identical(a,b),!identical(a,c))
z <- simular_bpi(12,123)
stopifnot(nrow(z)==12,ncol(z)==61,!anyDuplicated(z$nb))
stopifnot(inherits(try(simular_bpi(0),silent=TRUE),'try-error'))
cat('OK: 30×61, tipos, chaves, CPFs inválidos, relações pessoais, cronologia, ausências, rendas e reprodutibilidade.\n')
