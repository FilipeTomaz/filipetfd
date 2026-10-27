source('R/projecoes.R')
source('R/cenario_pos_transicao.R')

testar_pos_transicao <- function(r) {
  a <- r$anual
  base <- subset(r$base$anual, cenario == 'uniforme')
  perto <- function(x, y) all(abs(x-y) <= pmax(.01, abs(y)*1e-10))
  stopifnot(nrow(a) == 34L,
    perto(a$pagamentos_referencia, base$pagamentos_referencia),
    perto(a$pagamentos_evitados_idade, base$emissoes_adiadas),
    perto(a$economia_idade_real, base$economia_real),
    all(a$pagamentos_proposta >= 0),
    all(a$economia_elegibilidade_real[a$ano < 2037] == 0),
    all(a$ingressantes_excluidos[a$ano < 2037] == 0),
    all(a$economia_elegibilidade_real[a$ano >= 2037] > 0),
    perto(a$ingressantes_elegiveis[a$ano >= 2037],
      .6 * a$ingressantes_antes_redutor[a$ano >= 2037]),
    perto(a$economia_total_real,
      a$economia_idade_real+a$economia_numero_real+a$economia_elegibilidade_real),
    perto(a$economia_total_real,
      a$despesa_referencia_real-a$despesa_proposta_real),
    perto(a$economia_total_real_acumulada, cumsum(a$economia_total_real)),
    all(r$regras$idade_exigida[r$regras$ano >= 2036] == 65),
    all(r$regras$idade_exigida[r$regras$sexo == 'h' & r$regras$ano == 2027] == 60.5),
    all(r$regras$idade_exigida[r$regras$sexo == 'm' & r$regras$ano == 2027] == 56))

  # Oráculo independente: enumeração mês a mês de duas coortes artificiais.
  # Ambas têm ano de referência anterior ao corte; uma entra em 2036 e a
  # outra em janeiro/2037. A primeira nunca sofre redução, mesmo após 2037.
  m <- data.frame(cenario = 'uniforme', sexo = 'h', coorte = c(2035, 2036),
    mes = 1L, tamanho = c(12, 12), delta = 0L, espera = 12L)
  anos <- 2035:2038
  x <- somar_coortes_pos_transicao(m, anos, 2037L, .6, 13, 12)
  esperado <- numeric(length(anos))
  for (i in 1:2) for (ano in anos) for (mes in 1:12) {
    inicio <- (m$coorte[i]+1L)*12L
    data <- ano*12L+mes-1L
    if (data >= inicio)
      esperado[match(ano, anos)] <- esperado[match(ano, anos)] +
        12 * if (i == 1L) 1 else .6
  }
  stopifnot(perto(x$anual$pagamentos_proposta, esperado),
    identical(x$memoria$ano_ingresso, c(2036, 2037)),
    identical(x$memoria$fracao_elegivel, c(1, .6)),
    perto(x$anual$ingressantes_excluidos[x$anual$ano == 2037], 4.8))
  fronteira <- m[c(1, 1), ]
  fronteira$mes <- 12L
  fronteira$espera <- c(12L, 13L)
  fronteira <- somar_coortes_pos_transicao(fronteira, anos, 2037L, .6, 13, 12)
  stopifnot(identical(fronteira$memoria$ano_ingresso, c(2036, 2037)),
    all(fronteira$memoria$mes_ingresso == c(12, 1)),
    identical(fronteira$memoria$fracao_elegivel, c(1, .6)))
  # Se o redutor for desligado e os pagamentos iguais, recupera o motor antigo.
  sem <- somar_coortes_pos_transicao(subset(r$base$memoria, cenario == 'uniforme'),
    a$ano, 2037L, 1, 13, 13)$anual
  stopifnot(perto(sem$pagamentos_proposta, base$pagamentos_proposta),
    all(sem$pagamentos_evitados_numero == 0),
    all(sem$pagamentos_evitados_elegibilidade == 0))
  cat('OK: regressão no motor original, escalonamento, corte em 2037, proteção dos ingressos anteriores, 12 pagamentos, oráculo mensal e decomposição sem dupla contagem.\n')
  invisible(TRUE)
}

if (sys.nframe() == 0L) {
  entradas <- ler_entradas('Proposta de Equiparação da Idade pela DIB.xlsx')
  testar_pos_transicao(projetar_pos_transicao(entradas))
}
