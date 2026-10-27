# 65 anos, 12 pagamentos e 60% elegíveis após a transição

[PowerPoint editável](Beneficio_65_anos_12_pagamentos_60_elegiveis.pptx) ·
[PDF — oito slides](Beneficio_65_anos_12_pagamentos_60_elegiveis.pdf) ·
[Resultados anuais](../../resultados/pos_transicao_65_12_60/anual.csv)

A proposta parte das regras atuais da planilha, homens aos 60 e mulheres aos
55 anos, e eleva a idade até 65 anos para ambos entre **2027 e 2036**:
seis meses por ano para homens e um ano por ano para mulheres. Desde 2027,
as novas coortes recebem **12 pagamentos anuais**, contra 13 na referência.
O benefício mensal permanece igual a um salário mínimo.

**Apenas para ingressos efetivos a partir de janeiro de 2037, 60% permanecem
elegíveis e 40% são excluídos permanentemente deste benefício no exercício.**
O ano do ingresso é calculado após a espera imposta pela idade. Portanto, uma
pessoa que alcançou a idade antiga antes de 2037, mas cujo ingresso pela nova
regra só ocorre em 2037 ou depois, também passa pelo filtro. Quem ingressou
antes do corte não sofre redução retroativa de elegibilidade.

## Resultados

Economia acumulada desde 2027, em **R$ bilhões de 2026**, frente à manutenção
das regras atuais sem filtro adicional de elegibilidade:

| Até o ano | Idade | 13 → 12 pagamentos | Elegibilidade | Total |
|---|---:|---:|---:|---:|
| 2030 | 26,417 | 1,081 | 0,000 | **27,499** |
| 2036 | 304,160 | 8,344 | 0,000 | **312,504** |
| 2040 | 629,298 | 23,198 | 34,049 | **686,544** |
| 2050 | 1.599,314 | 139,057 | 487,762 | **2.226,134** |
| 2060 | 2.652,145 | 394,196 | 1.598,754 | **4.645,095** |

A economia anual em 2060 é de **R$ 283,795 bilhões de 2026**.
Os totais são calculados antes do arredondamento. A acumulação usa valores reais,
sem taxa adicional de desconto financeiro; não é um cálculo de valor presente.

## Decomposição e alcance

Os efeitos são aplicados sequencialmente para não contar a mesma economia duas
vezes. Se `R` é o número de benefícios equivalentes a um ano na referência,
`I` o equivalente após elevar a idade e `E` o equivalente após a elegibilidade:

- Idade: `13 × (R − I) × salário`.
- Pagamentos: `(13 − 12) × I × salário`.
- Elegibilidade: `12 × (I − E) × salário`.
- Total: `(13 × R − 12 × E) × salário`.

Cada valor nominal é dividido pelo deflator do INPC da planilha. Os pagamentos
são proporcionais aos meses de recebimento, inclusive o 13º na referência,
conforme a convenção do motor original.

As despesas comparadas abrangem somente as coortes de referência desde 2027.
As coortes anteriores são preservadas e ficam fora da diferença. **Não são
estimativas de todo o orçamento previdenciário.** Este cenário foi calculado
no modelo de aposentadoria rural existente no repositório, não no pipeline BPI.

As demais premissas foram mantidas: incidência média de concessões de 2020–2024,
idade média efetiva da referência, salário mínimo, INPC e população da planilha.
A população de referência H60/M55 não foi substituída por uma nova série aos
65 anos. O modelo não simula mortalidade, cessação, migração a outros benefícios
ou mudanças comportamentais. Os excluídos não retornam a este benefício.

## Reproduzir

Na raiz do repositório, com R e `xml2` disponíveis:

```sh
Rscript scripts/calcular_pos_transicao.R
```

O script roda as verificações de regressão, início do redutor, proteção dos
ingressos anteriores, fronteira dezembro/2036–janeiro/2037, enumeração mensal
independente de coortes artificiais e decomposição. Os arquivos são gravados
em `resultados/pos_transicao_65_12_60`, sem sobrescrever cenários anteriores.

Para refazer a apresentação, instale `python-pptx`, `reportlab`, `matplotlib` e
`numpy`, mantenha a fonte DejaVu Sans disponível e execute:

```sh
python apresentacoes/pos-transicao-65-12-60/gerar_apresentacao.py
```

O gráfico também é exportado em PNG e SVG. `metadados.json` registra o commit
da base e os hashes SHA-256 da planilha e do CSV anual. A extensão do modelo
fica em `R/cenario_pos_transicao.R`; o motor original e a planilha foram preservados.
