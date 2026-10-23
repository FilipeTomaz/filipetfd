# Execute em BPI: Rscript testes/testar_filtros_05.R
library(DBI)
library(duckdb)
source('R/filtros_05.R')
con <- dbConnect(duckdb(shared_home=FALSE),dbdir=':memory:')
x <- data.frame(nb=sprintf('%010d',1:12),especie=c(rep(41L,10),21L,88L),
 especie_nome=c(rep('APOSENTADORIA POR IDADE',10),'PENSÃO POR MORTE','BPC AO IDOSO'),
 clientela_codigo=c(rep('2',11),'1'),clientela=c(rep('RURAL',11),'URBANA'),
 vl_renda_media_fam=c(0,353,353.01,706,706.01,1412,1412.01,2824,2824.01,NA,-1,0),
 vl_renda_total_fam=c(0,1412,1412.01,2824,2824.01,4236,4236.01,7060,7060.01,NA,-1,0),
 qt_membro_familia=c(1,2,3,4,5,6,0,2.5,NA,3,2,1))
dbWriteTable(con,'tb_beneficio',x,overwrite=TRUE)
r <- filtrar_familias_05(con)
stopifnot(r$auditoria$n_antes==12,r$auditoria$n_depois==12,
 sum(r$resumo_filtrado$n_beneficios)==12,
 all(r$resumo_filtrado$tipo_segurado %in% c('Não informado/não classificado','Não se aplica (BPC)')))
for (t in list(r$faixas_per_capita,r$faixas_total,r$faixas_membros,r$cruzamento_familiar))
 stopifnot(sum(t$n_beneficios)==12)
v <- dbGetQuery(con,'SELECT renda_pc,faixa_renda_pc,renda_total,faixa_renda_total,membros,faixa_membros FROM v05_recorte')
stopifnot(v$faixa_renda_pc[match(353,v$renda_pc)]=='Até 1/4 SM',
 v$faixa_renda_pc[match(353.01,v$renda_pc)]=='>1/4 até 1/2 SM',
 v$faixa_renda_pc[match(706,v$renda_pc)]=='>1/4 até 1/2 SM',
 v$faixa_renda_pc[match(706.01,v$renda_pc)]=='>1/2 até 1 SM',
 v$faixa_renda_pc[match(1412,v$renda_pc)]=='>1/2 até 1 SM',
 v$faixa_renda_pc[match(2824,v$renda_pc)]=='>1 até 2 SM',
 v$faixa_renda_pc[match(-1,v$renda_pc)]=='Inválida',
 v$faixa_membros[match(0,v$membros)]=='Inválida',
 v$faixa_membros[match(2.5,v$membros)]=='Inválida')
t <- r$faixas_per_capita
s <- aggregate(t$pct_grupo,t[c('especie','clientela_codigo','clientela','tipo_segurado')],sum)
stopifnot(all(abs(s$x-100)<.1))
r2 <- filtrar_familias_05(con,list(renda_pc_min=353,renda_pc_max=706))
stopifnot(r2$auditoria$n_depois==3)
r3 <- filtrar_familias_05(con,list(renda_pc_min=353,renda_pc_max=706,
 incluir_ausentes_nos_filtros=TRUE))
stopifnot(r3$auditoria$n_depois==4)
invisible(filtrar_familias_05(con,list(renda_total_max=2824,membros_min=2,membros_max=4)))
v <- dbGetQuery(con,'SELECT * FROM v05_recorte')
stopifnot(nrow(v)==3,all(v$renda_total<=2824),all(v$membros %in% 2:4))
x$filiacao_nome <- c(' segurado   especial ','Empregado','NÃO INFORMADO','',
 'Contribuinte individual','Segurada especial','Empregado','NA',NA,'Facultativo',
 'Empregado','Segurado especial')
x$filiacao_codigo <- c('T01','T02','0','T03','T04','T01','T02','T05','T_ESPECIAL',
 'T06','T02','T01')
dbWriteTable(con,'tb_beneficio',x,overwrite=TRUE)
r <- filtrar_familias_05(con)
v <- dbGetQuery(con,'SELECT * FROM v05_familias')
stopifnot(sum(v$tipo_segurado=='Segurado especial')==2,
 sum(v$tipo_segurado=='Não informado/não classificado')==4,
 v$tipo_segurado[v$especie==88]=='Não se aplica (BPC)')
r <- filtrar_familias_05(con,list(codigos_especial='T_ESPECIAL',tipo_segurado='Segurado especial'))
stopifnot(r$auditoria$n_depois==3)
vazio <- filtrar_familias_05(con,list(renda_pc_min=999999))
stopifnot(vazio$auditoria$n_depois==0,nrow(vazio$resumo_filtrado)==0)
y <- x[setdiff(names(x),c('filiacao_nome','filiacao_codigo'))]
dbWriteTable(con,'tb_beneficio',y,overwrite=TRUE)
aux <- x[c('nb','filiacao_nome','filiacao_codigo')]
arq <- tempfile(fileext='.csv')
write.csv(aux,arq,row.names=FALSE,na='')
r <- filtrar_familias_05(con,list(arquivo_filiacao_aux=arq))
stopifnot(r$auditoria$n_antes==12,r$auditoria$n_depois==12,
 sum(r$resumo_filtrado$n_beneficios[r$resumo_filtrado$tipo_segurado=='Segurado especial'])==2)
# Prioridade do par da base: não combinar EMPREGADO com código especial auxiliar.
y$filiacao_nome <- c('Empregado',rep(NA_character_,11))
dbWriteTable(con,'tb_beneficio',y,overwrite=TRUE)
r <- filtrar_familias_05(con,list(arquivo_filiacao_aux=arq,codigos_especial='T01'))
dominio <- r$dominios_filiacao
empregado <- dominio[!is.na(dominio$filiacao_nome) & dominio$filiacao_nome=='Empregado',]
stopifnot(any(is.na(empregado$filiacao_codigo)),
 !any(empregado$filiacao_codigo=='T01',na.rm=TRUE))
# Conflito no mesmo par também não pode receber classificação de especial.
y$filiacao_codigo <- c('T01',rep(NA_character_,11))
dbWriteTable(con,'tb_beneficio',y,overwrite=TRUE)
r <- filtrar_familias_05(con,list(codigos_especial='T01'))
stopifnot(!any(r$resumo_filtrado$tipo_segurado=='Segurado especial'))
write.csv(rbind(aux,aux[1,]),arq,row.names=FALSE,na='')
stopifnot(inherits(try(filtrar_familias_05(con,list(arquivo_filiacao_aux=arq)),silent=TRUE),'try-error'),
 inherits(try(filtrar_familias_05(con,list(renda_pc_min=100,renda_pc_max=10)),silent=TRUE),'try-error'))
unlink(arq)
dbDisconnect(con,shutdown=TRUE)
cat('OK: limites, ausências, categorias, denominadores, referência de SM e JOIN 1:1 de filiação.\n')
