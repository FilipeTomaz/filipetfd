# Extensão do motor original: elegibilidade decidida no ingresso efetivo,
# depois da transição, e pagamentos diferentes na referência e na proposta.
# source('R/projecoes.R') deve ser executado antes de projetar_pos_transicao().
somar_coortes_pos_transicao <- function(memoria, anos, inicio_redutor,
    proporcao_elegivel, pagamentos_referencia, pagamentos_proposta) {
  stopifnot(length(inicio_redutor) == 1L, is.finite(inicio_redutor),
    inicio_redutor == floor(inicio_redutor),
    length(proporcao_elegivel) == 1L, is.finite(proporcao_elegivel),
    proporcao_elegivel >= 0, proporcao_elegivel <= 1,
    pagamentos_referencia > 0, pagamentos_proposta > 0,
    all(memoria$cenario == 'uniforme'))
  m <- memoria
  # Janeiro é o mês zero; espera está em meses inteiros.
  m$ano_ingresso <- m$coorte + (m$mes - 1L + m$espera) %/% 12L
  m$mes_ingresso <- (m$mes - 1L + m$espera) %% 12L + 1L
  m$fracao_elegivel <- ifelse(m$ano_ingresso >= inicio_redutor,
    proporcao_elegivel, 1)
  a <- data.frame(ano = anos, equivalentes_referencia = 0,
    equivalentes_idade = 0, equivalentes_elegiveis = 0,
    ingressantes_antes_redutor = 0, ingressantes_elegiveis = 0,
    ingressantes_excluidos = 0)
  for (i in seq_len(nrow(m))) {
    x <- 12 * (anos - m$coorte[i] + 1) - m$mes[i] + 1
    referencia <- pmin(pmax(x - m$delta[i], 0), 12) * m$tamanho[i] / 12
    idade <- pmin(pmax(x - m$espera[i], 0), 12) * m$tamanho[i] / 12
    a$equivalentes_referencia <- a$equivalentes_referencia + referencia
    a$equivalentes_idade <- a$equivalentes_idade + idade
    a$equivalentes_elegiveis <- a$equivalentes_elegiveis + idade * m$fracao_elegivel[i]
    entra <- anos == m$ano_ingresso[i]
    a$ingressantes_antes_redutor <- a$ingressantes_antes_redutor + entra * m$tamanho[i]
    a$ingressantes_elegiveis <- a$ingressantes_elegiveis + entra * m$tamanho[i] * m$fracao_elegivel[i]
    a$ingressantes_excluidos <- a$ingressantes_excluidos + entra * m$tamanho[i] * (1-m$fracao_elegivel[i])
  }
  a$pagamentos_referencia <- a$equivalentes_referencia * pagamentos_referencia
  a$pagamentos_proposta <- a$equivalentes_elegiveis * pagamentos_proposta
  # Decomposição sequencial: idade a 13 pagamentos; retirada do 13º entre
  # os que ingressariam pela idade; restrição a 12 pagamentos, sem dupla contagem.
  a$pagamentos_evitados_idade <- (a$equivalentes_referencia - a$equivalentes_idade) * pagamentos_referencia
  a$pagamentos_evitados_numero <- a$equivalentes_idade * (pagamentos_referencia-pagamentos_proposta)
  a$pagamentos_evitados_elegibilidade <- (a$equivalentes_idade-a$equivalentes_elegiveis) * pagamentos_proposta
  list(anual = a, memoria = m)
}

projetar_pos_transicao <- function(entradas, pagamentos_proposta = 12,
    proporcao_elegivel = 0.6, inicio = 2027L, fim = 2060L) {
  base <- projetar(entradas, list(idade_proposta_h = 65,
    idade_proposta_m = 65, duracao_uniforme = 10L, pagamentos_ano = 13,
    proporcao_elegivel = 1, inicio = inicio, fim = fim))
  inicio_redutor <- inicio + 10L
  acumulador <- somar_coortes_pos_transicao(
    subset(base$memoria, cenario == 'uniforme'), seq.int(inicio, fim),
    inicio_redutor, proporcao_elegivel, 13, pagamentos_proposta)
  a <- acumulador$anual
  d <- base$dados[match(a$ano, base$dados$ano), ]
  a$salario <- d$salario
  a$deflator <- d$deflator
  a$fracao_novos_elegiveis <- ifelse(a$ano >= inicio_redutor, proporcao_elegivel, 1)
  a$despesa_referencia_nominal <- a$pagamentos_referencia * a$salario
  a$despesa_proposta_nominal <- a$pagamentos_proposta * a$salario
  a$despesa_referencia_real <- a$despesa_referencia_nominal / a$deflator
  a$despesa_proposta_real <- a$despesa_proposta_nominal / a$deflator
  for (efeito in c('idade', 'numero', 'elegibilidade')) {
    nominal <- a[[paste0('pagamentos_evitados_', efeito)]] * a$salario
    real <- nominal / a$deflator
    a[[paste0('economia_', efeito, '_nominal')]] <- nominal
    a[[paste0('economia_', efeito, '_real')]] <- real
    a[[paste0('economia_', efeito, '_real_acumulada')]] <- cumsum(real)
  }
  a$economia_total_nominal <- a$despesa_referencia_nominal-a$despesa_proposta_nominal
  a$economia_total_real <- a$economia_total_nominal/a$deflator
  a$economia_total_real_acumulada <- cumsum(a$economia_total_real)
  a$economia_total_nominal_acumulada <- cumsum(a$economia_total_nominal)
  list(anual = a, memoria = acumulador$memoria,
    regras = subset(base$regras, cenario == 'uniforme'), base = base,
    inicio_redutor = inicio_redutor, pagamentos_proposta = pagamentos_proposta,
    proporcao_elegivel = proporcao_elegivel)
}
