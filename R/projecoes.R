# Somente células literais são importadas. Nenhum resultado de fórmula é usado.
ler_entradas <- function(arquivo) {
  z <- tempfile(); dir.create(z); on.exit(unlink(z, recursive = TRUE))
  unzip(arquivo, exdir = z)
  wb <- xml2::read_xml(file.path(z, 'xl/workbook.xml'))
  ns <- xml2::xml_ns(wb)
  abas <- xml2::xml_find_all(wb, './/d1:sheet', ns)
  aba <- abas[xml2::xml_attr(abas, 'name') == 'Transição 9 H e 13 M Anos']
  if (length(aba) != 1) stop('Aba de entradas ausente.')
  relid <- xml2::xml_attr(aba, 'r:id', ns = ns)
  rels <- xml2::read_xml(file.path(z, 'xl/_rels/workbook.xml.rels'))
  rel <- xml2::xml_find_all(rels, '//*[local-name()="Relationship"]')
  alvo <- xml2::xml_attr(rel, 'Target')[xml2::xml_attr(rel, 'Id') == relid]
  caminho <- if (startsWith(alvo, '/')) file.path(z, substring(alvo, 2)) else file.path(z, 'xl', alvo)
  doc <- xml2::read_xml(caminho)
  celulas <- xml2::xml_find_all(doc, '//*[local-name()="c"]')
  enderecos <- xml2::xml_attr(celulas, 'r')
  literal <- function(endereco, opcional = FALSE) {
    c <- celulas[match(endereco, enderecos)]
    formula <- xml2::xml_find_first(c, './*[local-name()="f"]')
    if (!is.na(formula)) {
      if (opcional) return(NA_real_)
      stop('Entrada contém fórmula: ', endereco)
    }
    valor <- suppressWarnings(as.numeric(xml2::xml_text(xml2::xml_find_first(c, './*[local-name()="v"]'))))
    if (!is.finite(valor)) stop('Entrada numérica ausente: ', endereco)
    valor
  }
  anos <- vapply(paste0('B', 5:55), literal, numeric(1))
  col <- function(letra, opcional = FALSE) vapply(paste0(letra, 5:55), literal, numeric(1), opcional = opcional)
  list(dados = data.frame(ano = anos, concessoes_h = col('C', TRUE),
       populacao_h = col('D'), concessoes_m = col('F', TRUE), populacao_m = col('G'),
       salario = col('I'), inpc = col('J')),
       medias_h = vapply(paste0('AH', 7:12), literal, numeric(1)),
       medias_m = vapply(paste0('AI', 7:12), literal, numeric(1)))
}

# Excel arredonda empates para longe de zero; round() do R usa o par mais próximo.
arred_excel <- function(x) sign(x) * floor(abs(x) + 0.5)

parametros_padrao <- function() list(
  idade_vigente_h = 60, idade_vigente_m = 55,
  idade_proposta_h = 65, idade_proposta_m = 62,
  idades_medias_h = NULL, idades_medias_m = NULL,
  referencia = 'media', inicio = 2027, fim = 2060, ano_base = 2026,
  intervalo_degraus = 2, duracao_uniforme = 10, pagamentos_ano = 13)

validar_parametros <- function(p, e) {
  escalares <- c('idade_vigente_h', 'idade_vigente_m', 'idade_proposta_h',
    'idade_proposta_m', 'inicio', 'fim', 'ano_base', 'intervalo_degraus',
    'duracao_uniforme', 'pagamentos_ano')
  for (n in escalares) if (length(p[[n]]) != 1 || !is.numeric(p[[n]]) ||
      !is.finite(p[[n]])) stop('Parâmetro inválido: ', n)
  for (n in c('inicio','fim','ano_base','intervalo_degraus','duracao_uniforme'))
    if (p[[n]] != floor(p[[n]])) stop('Parâmetro deve ser inteiro: ', n)
  if (!p$referencia %in% c('media', 'minima')) stop('referencia: media ou minima')
  if (p$intervalo_degraus < 1 || p$duracao_uniforme < 1 || p$pagamentos_ano <= 0)
    stop('Durações e pagamentos devem ser positivos.')
  if (p$inicio <= p$ano_base || p$fim < p$inicio ||
      !all(c(p$inicio, p$fim, p$ano_base) %in% e$dados$ano))
    stop('Use início posterior à base, e horizonte dentro dos dados da planilha.')
  for (s in c('h','m')) {
    v <- p[[paste0('idade_vigente_', s)]]; a <- p[[paste0('idade_proposta_', s)]]
    if (v <= 0 || a < v || v != floor(v) || a != floor(a))
      stop('Idades mínimas devem ser inteiras e proposta >= vigente.')
    m <- p[[paste0('idades_medias_', s)]]
    if (!is.null(m) && (length(m) != 6 || any(!is.finite(m)) || any(m < v)))
      stop('Informe seis idades médias (2020–2025), todas >= idade vigente.')
  }
}

projetar <- function(entradas, parametros = list()) {
  p <- utils::modifyList(parametros_padrao(), parametros)
  validar_parametros(p, entradas)
  d <- entradas$dados
  historico <- d$ano %in% 2020:2024
  for (s in c('h','m')) {
    c <- paste0('concessoes_',s); pop <- paste0('populacao_',s)
    if (anyNA(d[[c]][d$ano <= 2024])) stop('Histórico sem concessões literais.')
    taxa <- mean(d[[c]][historico] / d[[pop]][historico])
    futuro <- d$ano >= 2025
    d[[c]][futuro] <- d[[pop]][futuro] * taxa
    d[[paste0('incidencia_',s)]] <- d[[c]] / d[[pop]]
  }
  d$deflator <- NA_real_
  base <- match(p$ano_base, d$ano); d$deflator[base] <- 1
  for (i in seq.int(base + 1, nrow(d))) d$deflator[i] <- d$deflator[i-1] * (1+d$inpc[i])
  anos <- seq.int(p$inicio, p$fim)
  resultados <- list(); memorias <- list(); regras <- list()
  # C(z) e H(X;n): equivalentes às auxiliares da primeira aba.
  C <- function(z) ifelse(z <= 0, 0, ifelse(z <= 12, z*(z+1)/2, 78+12*(z-12)))
  H <- function(x,n) C(x)-C(x-n)
  for (cenario in c('sem_transicao','degraus','uniforme')) {
    emissoes <- numeric(length(anos))
    for (sexo in c('h','m')) {
      vigente <- p[[paste0('idade_vigente_',sexo)]]
      proposta <- p[[paste0('idade_proposta_',sexo)]]
      medias <- p[[paste0('idades_medias_',sexo)]]
      if (is.null(medias)) medias <- entradas[[paste0('medias_',sexo)]]
      delta <- if (p$referencia == 'media') max(0, arred_excel(12*(mean(medias)-vigente))) else 0
      acrescimo <- function(ano) {
        t <- pmax(ano-p$inicio+1, 0)
        if (cenario == 'sem_transicao') return(ifelse(t > 0, 12*(proposta-vigente), 0))
        if (cenario == 'uniforme') return(arred_excel(12*(proposta-vigente)*pmin(t,p$duracao_uniforme)/p$duracao_uniforme))
        ifelse(t > 0, 12*pmin(proposta-vigente, 1+floor((ano-p$inicio)/p$intervalo_degraus)), 0)
      }
      regras[[length(regras)+1]] <- data.frame(cenario, sexo, ano=anos,
        idade_exigida=vigente+acrescimo(anos)/12, defasagem_meses=delta)
      for (coorte in anos) {
        tamanho <- d[[paste0('concessoes_',sexo)]][match(coorte,d$ano)]
        if (cenario == 'uniforme') {
          # Primeiro mês elegível: a exigência é atualizada em janeiro de cada ano.
          for (mes in 1:12) {
            limite <- ceiling(max(delta,12*(proposta-vigente))/12)+2
            j <- 0:limite
            candidato <- pmax(delta, 12*j-mes+1, acrescimo(coorte+j))
            espera <- min(candidato[candidato <= 12*j-mes+12])
            x <- 12*(anos-coorte+1)-mes+1
            evitados <- (pmin(pmax(x-delta,0),12)-pmin(pmax(x-espera,0),12))*p$pagamentos_ano/12
            emissoes <- emissoes+tamanho/12*evitados
            memorias[[length(memorias)+1]] <- data.frame(cenario,sexo,coorte,mes,
              tamanho=tamanho/12,delta,espera)
          }
        } else {
          # Reprodução literal da divisão dos meses de entrada em grupos A e B.
          a <- floor(delta/12); b <- delta %% 12
          k <- if (cenario == 'sem_transicao' || p$intervalo_degraus <= 1)
            proposta-vigente else min(proposta-vigente, floor((coorte-p$inicio)/(p$intervalo_degraus-1))+1)
          espera_a <- max(delta, acrescimo(coorte+max(k,a)))
          espera_b <- max(delta, acrescimo(coorte+max(k,a+1)))
          x <- 12*(anos-coorte+1)
          clip <- function(x) pmin(pmax(x,0),24)
          evitados <- p$pagamentos_ano/144 * (H(clip(x-delta),12)-
            H(clip(x-espera_a),12-b)-H(clip(x-espera_b-12+b),b))
          emissoes <- emissoes+tamanho*evitados
          memorias[[length(memorias)+1]] <- data.frame(cenario,sexo,coorte,mes=NA,
            tamanho,delta,espera=espera_a,espera_b)
        }
      }
    }
    econ <- d[match(anos,d$ano),]
    econ$cenario <- cenario; econ$emissoes_adiadas <- emissoes
    econ$economia_nominal <- emissoes*econ$salario
    econ$economia_nominal_acumulada <- cumsum(econ$economia_nominal)
    econ$economia_real <- econ$economia_nominal/econ$deflator
    econ$economia_real_acumulada <- cumsum(econ$economia_real)
    resultados[[cenario]] <- econ
  }
  # Memórias têm colunas distintas conforme o método.
  nomes <- unique(unlist(lapply(memorias,names)))
  memorias <- lapply(memorias,function(x) {x[setdiff(nomes,names(x))] <- NA_real_; x[nomes]})
  list(anual=do.call(rbind,resultados), memoria=do.call(rbind,memorias),
       regras=do.call(rbind,regras), dados=d, parametros=p)
}
