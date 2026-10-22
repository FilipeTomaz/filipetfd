# Exemplo sintético: 61 colunas

`bpi_sintetico_61.csv` contém **30 benefícios fictícios e 61 colunas**, na mesma
ordem e com os mesmos nomes da classificação compartilhada. As 60 variáveis do
esquema anterior foram mantidas e `qt_anos_contribuicao` foi acrescentada no final.
Nenhum registro ou identificador das fontes reais foi utilizado.

O arquivo é UTF-8, separado por vírgula, com ponto decimal e datas ISO
`YYYY-MM-DD`. Campo vazio é ausência (`NA`); zero é um valor informado.
Há NBs únicos, CPFs repetidos entre benefícios, CPF ausente e as quatro
combinações de localização CadÚnico/RAIS. Os atributos pessoais e dessas fontes
se repetem de forma coerente quando o CPF se repete. Também há pessoa localizada
no CadÚnico sem informação familiar e remuneração zero com faixa ausente.

## Abrir no RStudio sem perder identificadores

CSV não guarda tipos de coluna. O esquema é a especificação para reconstruí-los;
CPF, NB e códigos devem ser lidos como texto. Abra `BPI.Rproj` e execute:

```r
source("scripts/gerar_base_sintetica.R")
esquema <- read.csv("esquemas/banco_beneficio_cad_rais_61.csv",
                    colClasses = "character")
base <- ler_bpi_sintetico("dados/sinteticos/bpi_sintetico_61.csv", esquema)
dim(base)  # 30 linhas e 61 colunas
str(base)
```

`mes_admissao` está especificada como BIGINT no DuckDB; como só contém 1–12,
o leitor R usa `integer` sem perda. Ao criar uma tabela DuckDB/Parquet, deve-se
usar o esquema explícito de 61 colunas para recuperar os tipos físicos exatos.
Não foi gerado Parquet nesta etapa.

## Gerar novamente ou mudar o tamanho

O gerador utiliza apenas R base e não executa os scripts originais de integração:

```r
source("scripts/gerar_base_sintetica.R")
gerar_exemplo_bpi()  # 30 benefícios; semente 20261022
# Sobrescreve somente os dois arquivos sintéticos gerados nesta pasta:
gerar_exemplo_bpi(n_beneficios = 100, semente = 123)
```

O tamanho aceito vai de 12 a 100.000 benefícios. A semente e a versão do R são
registradas em `manifesto.csv`. A mesma semente e versão do R reproduzem a execução.
Os parâmetros e distribuições são didáticos, sem representatividade populacional.

## Convenções desta simulação

| Grupo | Regra usada no exemplo |
|---|---|
| CPF e NB | CPF gerado com segundo dígito verificador deliberadamente inválido; NBs fictícios sequenciais; NB anterior aponta para outro benefício sintético da mesma pessoa, anterior em DIB e DDB |
| Espécie/clientela | Espécies 21/41/88; clientela 0 não informada, 1 urbana, 2 rural |
| Sexo/despacho | Códigos `SIM_M`/`SIM_F` e `SIM_CONCESSAO`: marcadores fictícios, não domínios oficiais |
| Município INSS | `SIM_SUIBE_UF`: marcador de teste; não é código SUIBE oficial. Municípios IBGE/CadÚnico usam códigos geográficos públicos |
| Deficiência | Código sintético 1 sim, 2 não; indicadores 0 não, 1 sim, armazenados numericamente. Não são medidas contínuas |
| Curso/trabalho | Curso sintético 1–8; trabalho 1 sim, 2 não; meses trabalhados 0–12; não substituem os domínios oficiais |
| Renda 808 | Código ordinal sintético 0–6; não é valor monetário em reais nem domínio oficial confirmado |
| RAIS | Marcadores `SIM_*` para vínculo/admissão/CBO/CNAE; vínculo ativo 1/0; tempo em meses e faixas de tempo/remuneração consistentes |
| Família | Membros sintéticos compartilham renda e tamanho familiar; per capita × tamanho = total. Essa é regra do gerador, não fórmula comprovada na fonte |
| RMI | RMI em SM × piso da data DDB. Pisos do exercício: 2020 jan 1039/fev 1045; 2021 1100; 2022 1212; 2023 jan 1302/mai 1320; 2024 1412; 2025 1518 |
| RMI convertida | Normalização didática para piso de referência 1412; não reproduz a regra heterogênea da fonte real |
| Contribuição | Anos sintéticos; zero e ausência aparecem separadamente; o exemplo usa zero para BPC sem impor requisito contributivo. Não deriva o histórico da RAIS nem atribui o histórico do instituidor ao pensionista |

As codificações `SIM_*` tornam visíveis os domínios ainda não confirmados. O
exemplo testa o esquema final e os relatórios por espécie/clientela; não substitui
os arquivos brutos nem valida suas regras de normalização ou seleção de vínculos.
Para testar esses passos, será necessária a etapa separada de fontes sintéticas.
