# Especificação para a próxima etapa: base teste sintética

## Objetivo e escopo inicial

Gerar uma base aleatória reprodutível que permita testar os relatórios sem acessar
as fontes identificadas. O alvo inicial é a base final com 60 colunas, mais uma
tabela auxiliar de contribuição por NB. A simulação das fontes brutas e de
Mantidos é uma segunda camada para testar os cruzamentos e as regras de situação.
Nada foi gerado ainda; esta é a especificação do próximo trabalho.

O esquema final foi extraído da tabela de metadados do HTML recebido, sem usar
seus registros individuais. As descrições derivam dos roteiros e não substituem
os dicionários oficiais das fontes.

## Parâmetros a expor no gerador

| Parâmetro | Uso |
|---|---|
| `n_beneficios` | Quantidade configurável; sugestão inicial de 10.000 NBs |
| `semente` | Semente explícita e registrada para reproduzir a mesma execução |
| `n_pessoas` e múltiplos benefícios | Gerar CPFs repetidos entre NBs sem perder unicidade de NB |
| Distribuição de espécies/clientelas | Categorias conhecidas 21/41/88 e clientela 0/1/2 |
| Correspondência CadÚnico e RAIS | Probabilidades distintas e quatro combinações de localização |
| Ausências | Taxas condicionais, inclusive renda/contribuição ausente |
| Valores e datas | Faixas configuráveis e relações lógicas; sem calibração implícita pelos HTMLs |
| Casos anômalos | Quantidade/configuração separada das linhas normais |

Os dados serão funcionais para testes. Não devem ser apresentados como estimativa
populacional nem como reprodução da distribuição dos dados reais.

## Entidades e relações

1. **Pessoas:** identificador sintético e CPF fictício com 11 posições e zeros
   preservados. Os valores não vêm das fontes; podem ter dígitos verificadores
   deliberadamente inválidos para evidenciar que são dados de teste.
2. **Famílias:** renda/tamanho e identificador auxiliar compartilhado pelos seus
   membros. Esse identificador não faz parte das 60 colunas finais, mas deve
   existir no suporte da simulação para conferir coerência.
3. **Benefícios:** NBs sintéticos únicos, cada um associado à pessoa; duplicidade
   de CPF entre benefícios é permitida. NB anterior pode apontar para outro
   benefício sintético ou ficar ausente.
4. **CadÚnico/RAIS:** atributos da pessoa repetidos coerentemente nos benefícios
   do mesmo CPF. Vínculos e suas regras de seleção precisam ser mantidos em tabela
   própria se o objetivo for testar a integração de fontes brutas.
5. **Contribuição:** tabela por NB com `nb`, `cpf`, `qt_anos_contribuicao`; os anos
   podem ser fracionários. Ausência não é zero.

Não será feita amostragem de registros dos HTMLs nem reutilização de pessoas,
CPFs ou NBs reais. Um manifesto externo aos dados indicará que toda a execução é
sintética, preservando o layout exato de 60 colunas.

## Coerência esperada nos dados normais

- NB único e contagem preservada após LEFT JOIN de contribuição.
- CPF pode ser ausente; isso impede correspondência por pessoa. Uma pessoa pode
  ter mais de um benefício, mas seus atributos de CadÚnico/RAIS devem coincidir.
- Flags de localização `S`/`N`, com campos da fonte ausentes quando `N`.
  Localização no CadÚnico não garante família localizada/preenchida.
- Valores monetários não negativos; renda pessoal em faixa separada de renda
  familiar em reais. Renda familiar per capita pode ser gerada a partir de total
  e tamanho na simulação, deixando explícito que essa é uma regra sintética e
  não uma fórmula comprovada no arquivo de origem.
- Remuneração e faixas compatíveis, tempo de emprego em meses, mês de admissão
  entre 1 e 12 e meses trabalhados entre 0 e 12. Remuneração zero pode coexistir
  com vínculo encontrado e faixa de remuneração ausente.
- Datas de nascimento anteriores à concessão. DIB anterior à DER é possível por
  retroatividade e não deve ser proibida automaticamente. DII pode estar ausente.
- `rmi_em_sm` e valores nominais coerentes com uma tabela de SM por ano
  explicitamente fornecida, quando esse vínculo for usado na simulação.
- Clientela INSS não deve ser igualada por construção ao domicílio CadÚnico.
  UF processadora, residência SUIBE e município IBGE são campos distintos.
- Contribuição não é estimada pelo tempo no vínculo RAIS. Na pensão, registrar
  a ambiguidade do titular do histórico; no BPC, não impor requisito contributivo.

## Casos de teste separados

Os defeitos deliberados devem vir em lote separado e com um catálogo de casos,
sem contaminar silenciosamente a base normal:

- CPF ausente, zeros à esquerda, caracteres a limpar e variantes que colidem
  após normalização; NB duplicado antes da consolidação e conflitante entre fontes.
- Duplicatas CadÚnico com famílias/atualizações diferentes e múltiplos vínculos
  RAIS, ativos e desligados, incluindo empates de seleção.
- Contribuição ausente, zero, fracionária, negativa e acima de 80 anos.
- Datas inválidas, sentinelas, DCB anterior à DIB, DCB após referência e situação
  suspensa/indeterminada; NB de Concedidos não encontrado em Mantidos.
- Divergência de duração informada versus DCB menos DIB.

## Entregas previstas e verificação

- Script R de geração com parâmetros de tamanho e semente.
- Base final sintética e auxiliar de contribuição em formatos adequados ao
  pipeline (Parquet e/ou DuckDB), mantendo nomes e tipos do esquema observado.
- Se necessário, arquivos de fontes brutas em layouts de 54 posições para
  Concedidos e 51 para Mantidos, com origens sintéticas identificadas.
- R Markdown adaptado com caminhos relativos ao BPI e resultados agregados.
- Verificação de esquema, unicidade, integridade dos vínculos, faixas, datas,
  conservação de contagens e reprodução da execução com a mesma semente.

A integração Mantidos só poderá classificar posição em julho/2026 se houver
uma regra temporal explicitamente definida. Para o teste, a data-base deve ser
um parâmetro da simulação, não uma afirmação sobre os arquivos reais recebidos.
