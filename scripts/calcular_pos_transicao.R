# Execute na raiz: Rscript scripts/calcular_pos_transicao.R
source('R/projecoes.R')
source('R/cenario_pos_transicao.R')
source('tests/test_pos_transicao.R')
entradas <- ler_entradas('Proposta de Equiparação da Idade pela DIB.xlsx')
r <- projetar_pos_transicao(entradas)
testar_pos_transicao(r)
saida <- 'resultados/pos_transicao_65_12_60'
dir.create(saida, recursive = TRUE, showWarnings = FALSE)
write.csv(r$anual, file.path(saida, 'anual.csv'), row.names = FALSE)
write.csv(r$regras, file.path(saida, 'idades.csv'), row.names = FALSE)
write.csv(r$memoria, file.path(saida, 'coortes.csv'), row.names = FALSE)
marcos <- c(2030L, 2034L, 2036L, 2037L, 2040L, 2050L, 2060L)
resumo <- r$anual[r$anual$ano %in% marcos,
  c('ano', 'economia_total_real', 'economia_total_real_acumulada',
    'economia_idade_real_acumulada', 'economia_numero_real_acumulada',
    'economia_elegibilidade_real_acumulada', 'economia_total_nominal_acumulada')]
resumo[-1] <- resumo[-1]/1e9
names(resumo)[-1] <- paste0(names(resumo)[-1], '_bi')
write.csv(resumo, file.path(saida, 'resumo_bilhoes.csv'), row.names = FALSE)
writeLines(c(paste('Git HEAD:', system('git rev-parse HEAD', intern = TRUE)),
  paste('R:', R.version.string), 'H65/M65; transição uniforme 2027–2036;',
  '13 pagamentos na referência; 12 na proposta para novas coortes;',
  '60% elegíveis para ingressos efetivos desde 2037; valor mensal inalterado;',
  'Coortes de referência anteriores a 2027 preservadas e fora da diferença;',
  'Valores reais de 2026; mesma planilha e mesmas premissas do modelo original.'),
  file.path(saida, 'proveniencia.txt'))
print(resumo, row.names = FALSE)
cat('Arquivos salvos em', saida, '\n')
