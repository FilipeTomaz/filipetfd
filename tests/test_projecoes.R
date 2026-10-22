source('R/projecoes.R')
arquivo <- 'Proposta de Equiparação da Idade pela DIB.xlsx'
e <- ler_entradas(arquivo)
r <- projetar(e)
esperado <- read.csv('tests/referencia_excel.csv')
atual <- r$anual
chave <- function(x) paste(x$cenario,x$ano)
atual <- atual[match(chave(esperado),chave(atual)), names(esperado)]
for (col in names(esperado)[-(1:2)]) {
  erro <- abs(atual[[col]]-esperado[[col]])
  stopifnot(all(erro <= pmax(0.01, abs(esperado[[col]])*1e-10)))
  cat(col, ': 102 valores anuais conferidos; erro máximo =',max(erro),'\n')
}
zero <- projetar(e,list(idade_proposta_h=60,idade_proposta_m=55))
stopifnot(all(abs(zero$anual$economia_real) < 0.01))
minima <- projetar(e,list(referencia='minima'))
stopifnot(all(minima$anual$economia_real_acumulada >= r$anual$economia_real_acumulada-0.01))
alterado <- projetar(e,list(idade_proposta_h=64,idade_proposta_m=61,
  duracao_uniforme=12,intervalo_degraus=3))
stopifnot(!isTRUE(all.equal(alterado$anual$economia_real,r$anual$economia_real)))
media <- projetar(e,list(idades_medias_h=rep(61,6),idades_medias_m=rep(57,6)))
stopifnot(all(media$regras$defasagem_meses[media$regras$sexo=='h']==12),
  all(media$regras$defasagem_meses[media$regras$sexo=='m']==24))
curto <- projetar(e,list(inicio=2030,fim=2040))
stopifnot(all(curto$anual$ano %in% 2030:2040),nrow(curto$anual)==33)
# Sem aumentos, inclusive com referência mínima, nenhuma economia é criada.
z <- projetar(e,list(idade_proposta_h=60,idade_proposta_m=55,referencia='minima'))
stopifnot(all(abs(z$anual$economia_nominal) < 0.01))
# Referências salvas não podem influenciar o motor: nenhuma fórmula é importada.
stopifnot(all(is.na(e$dados$concessoes_h[e$dados$ano>=2025])),
          all(is.na(e$dados$concessoes_m[e$dados$ano>=2025])))
invalido <- try(projetar(e,list(duracao_uniforme=0)),silent=TRUE)
stopifnot(inherits(invalido,'try-error'))
cat('Cenários alternativos, idades médias, referência mínima, horizonte e parâmetros inválidos: OK\n')
# Elegibilidade: escala o fluxo, sem alterar histórico ou a incidência estimada.
completo <- projetar(e,list(idade_proposta_m=65))
restrito <- projetar(e,list(idade_proposta_m=65,proporcao_elegivel=0.6))
stopifnot(isTRUE(all.equal(restrito$anual$economia_real,0.6*completo$anual$economia_real)),
  isTRUE(all.equal(restrito$dados,completo$dados)),
  all(abs(restrito$anual$pagamentos_referencia-restrito$anual$pagamentos_proposta-
    restrito$anual$pagamentos_excluidos-restrito$anual$emissoes_adiadas)<1e-5),
  all(restrito$anual$pagamentos_proposta >= -1e-5))
# Exclusão completa elimina pagamentos das novas coortes; 100% mantém a economia original.
ninguem <- projetar(e,list(proporcao_elegivel=0))
stopifnot(all(ninguem$anual$pagamentos_proposta==0),
  all(ninguem$anual$economia_real==0),
  all(r$anual$economia_total_real==r$anual$economia_real),
  inherits(try(projetar(e,list(proporcao_elegivel=1.1)),silent=TRUE),'try-error'))
cat('Elegibilidade de 60%, 0% e 100%, decomposição e conservação dos pagamentos: OK\n')
