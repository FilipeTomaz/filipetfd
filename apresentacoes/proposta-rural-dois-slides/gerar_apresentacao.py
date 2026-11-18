"""Dois slides sobre a proposta rural, reutilizando os cálculos já publicados.

Execute na raiz ou em qualquer diretório. Não executa R nem altera resultados.
Requer python-pptx, reportlab, matplotlib, numpy e fontes DejaVu Sans.
"""
from pathlib import Path
import csv
import hashlib
import json
import os
import subprocess
import tempfile

os.environ.setdefault('MPLCONFIGDIR', str(Path(tempfile.gettempdir())/'filipetfd-matplotlib'))
os.environ.setdefault('XDG_CACHE_HOME', str(Path(tempfile.gettempdir())/'filipetfd-cache'))

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
from pptx import Presentation
from pptx.chart.data import CategoryChartData
from pptx.dml.color import RGBColor
from pptx.enum.chart import XL_CHART_TYPE, XL_LEGEND_POSITION, XL_LABEL_POSITION, XL_TICK_MARK
from pptx.util import Inches, Pt
from pptx.oxml.xmlchemy import OxmlElement
from reportlab.pdfgen import canvas
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.utils import simpleSplit

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[1]
DATA = ROOT/'resultados/tres_cenarios_anual.csv'
STEM = 'Proposta_protecao_rural_2_slides'
NAVY, TEAL, GOLD = '#142D45', '#008675', '#BB842B'
GRAY, LIGHT, WHITE = '#526575', '#EDF3F5', '#FFFFFF'


def fmt(value, digits=1):
    return f'{value:,.{digits}f}'.replace(',', 'X').replace('.', ',').replace('X', '.')


with DATA.open(encoding='utf-8') as f:
    original_rows = [r for r in csv.DictReader(f) if r['exercicio'] == 'base_65_62']
rows = []
for original in original_rows:
    r = {k: float(v) for k, v in original.items()
         if k not in ('cenario', 'exercicio')}
    r['despesa_referencia_real'] = r['pagamentos_referencia']*r['salario']/r['deflator']
    r['despesa_proposta_real'] = r['pagamentos_proposta']*r['salario']/r['deflator']
    rows.append(r)
assert len(rows) == 34 and [int(r['ano']) for r in rows] == list(range(2027, 2061))
for r in rows:
    assert np.isclose(r['despesa_referencia_real']-r['despesa_proposta_real'],
                      r['economia_total_real'], rtol=1e-10, atol=.01)
    assert r['proporcao_elegivel'] == 1
    assert r['idade_final_h'] == 65 and r['idade_final_m'] == 62
    assert r['pagamentos_excluidos'] == 0
years = [int(r['ano']) for r in rows]
reference = [r['despesa_referencia_real']/1e9 for r in rows]
proposal = [r['despesa_proposta_real']/1e9 for r in rows]
last = rows[-1]

plt.rcParams.update({'font.family': 'DejaVu Sans', 'font.size': 12,
                     'axes.spines.top': False, 'axes.spines.right': False})
fig, ax = plt.subplots(figsize=(12.1, 3.65), layout='constrained')
ax.plot(years, reference, color=NAVY, linewidth=2.7, label='Regra atual · H60/M55 · 13 pagamentos')
ax.plot(years, proposal, color=TEAL, linewidth=3.0, label='Cenário base · H65/M62 · 13 pagamentos')
ax.axvline(2036.5, color=GOLD, linewidth=1.2, linestyle='--')
ax.text(2037.1, 340, 'Fim da transição\nde idades em 2036', color=GRAY, fontsize=10)
ax.set_xlim(2027, 2063)
ax.set_ylim(0, 600)
ax.set_xticks([2027, 2036, 2040, 2050, 2060])
ax.set_yticks(range(0, 601, 100))
ax.tick_params(colors=GRAY)
ax.grid(axis='y', color='#DDE5E8', linewidth=.7)
ax.set_axisbelow(True)
ax.legend(loc='upper left', frameon=False, fontsize=11)
ax.annotate(fmt(reference[-1]), (2060, reference[-1]), xytext=(8, 0),
            textcoords='offset points', color=NAVY, fontsize=13, fontweight='bold', va='center')
ax.annotate(fmt(proposal[-1]), (2060, proposal[-1]), xytext=(8, 0),
            textcoords='offset points', color=TEAL, fontsize=13, fontweight='bold', va='center')
fig.savefig(OUT/'trajetorias_despesa.png', dpi=240, facecolor='white')
fig.savefig(OUT/'trajetorias_despesa.svg', facecolor='white')
plt.close(fig)

fonts = Path('/usr/share/fonts/truetype/dejavu')
for name, filename in [('DejaVu', 'DejaVuSans.ttf'), ('DejaVu-Bold', 'DejaVuSans-Bold.ttf')]:
    pdfmetrics.registerFont(TTFont(name, str(fonts/filename)))
prs = Presentation()
prs.slide_width, prs.slide_height = Inches(13.333333), Inches(7.5)
pdf = canvas.Canvas(str(OUT/f'{STEM}.pdf'), pagesize=(960, 540))
pdf.setTitle('Proposta de proteção ao idoso rural — premissas e trajetórias de despesa')
pdf.setAuthor('Projeções a partir de FilipeTomaz/filipetfd')
slide = None
page = 0


def rgb(color):
    return RGBColor.from_string(color[1:])


def rect(x, y, w, h, color):
    sh = slide.shapes.add_shape(1, Inches(x), Inches(y), Inches(w), Inches(h))
    sh.fill.solid()
    sh.fill.fore_color.rgb = rgb(color)
    sh.line.fill.background()
    pdf.setFillColor(color)
    pdf.rect(x*72, 540-(y+h)*72, w*72, h*72, fill=1, stroke=0)


def text(x, y, w, h, content, size=16, color=NAVY, bold=False):
    sh = slide.shapes.add_textbox(Inches(x), Inches(y), Inches(w), Inches(h))
    tf = sh.text_frame
    tf.word_wrap = True
    tf.margin_left = tf.margin_right = tf.margin_top = tf.margin_bottom = 0
    baseline = 540-y*72-size
    font = 'DejaVu-Bold' if bold else 'DejaVu'
    for i, line in enumerate(content.split('\n')):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        p.text = line
        p.font.name = 'DejaVu Sans'
        p.font.size = Pt(size)
        p.font.bold = bold
        p.font.color.rgb = rgb(color)
        p.space_after = Pt(3)
        for wrapped in simpleSplit(line, font, size, w*72):
            pdf.setFillColor(color)
            pdf.setFont(font, size)
            pdf.drawString(x*72, baseline, wrapped)
            baseline -= size*1.2
        baseline -= 3
    return sh


def start(kicker):
    global slide, page
    if page:
        pdf.showPage()
    page += 1
    slide = prs.slides.add_slide(prs.slide_layouts[6])
    rect(0, 0, 13.333333, 7.5, WHITE)
    rect(0, 0, 13.333333, .09, TEAL)
    text(.6, .32, 12.0, .25, kicker.upper(), 10, TEAL, True)
    rect(.6, 7.02, 12.1, .012, '#D9E3E7')
    text(.62, 7.15, 11.7, .19,
         'Fonte: FilipeTomaz/filipetfd e INSS · Cálculos preservados · Valores reais de 2026', 8, GRAY)
    text(12.2, 7.13, .45, .2, f'{page}/2', 9, GRAY)


start('01 · Desenho da proposta')
text(.6, .75, 12.1, .93, 'Proteção ao idoso rural:\ncontribuição e assistência com regras distintas', 27, NAVY, True)
text(.62, 1.8, 12.0, .28,
     'Proposta para novos ingressos, preservando benefícios concedidos e direitos já adquiridos.', 13, GRAY)

cards = [
    ('1', 'Encerrar a via rural sem contribuição individual mensal',
     'Na proposta, novos ingressos sem aposentadoria contributiva são direcionados à proteção assistencial.',
     'Objetivo: distinguir o seguro previdenciário da assistência à baixa renda.'),
    ('2', 'Preservar a proteção previdenciária de quem contribuiu ao INSS',
     'Contribuições e direitos adquiridos preservados; novos ingressos seguem a regra urbana aplicável.',
     'Referência urbana: homens aos 65 e mulheres aos 62 anos, conforme a regra aplicável.'),
    ('3', 'Transição de dez anos para a proteção assistencial',
     'A via assistencial é o BPC: 65 anos para ambos, sujeito à renda e aos demais requisitos.',
     'Objetivo: proteger o idoso de baixa renda; a passagem para o BPC não é automática.'),
]
for i, (number, title, detail, reason) in enumerate(cards):
    y = 2.26+i*1.14
    rect(.62, y, 12.05, 1.02, LIGHT)
    rect(.62, y, .07, 1.02, TEAL)
    text(.86, y+.13, .40, .35, number, 24, TEAL, True)
    text(1.37, y+.10, 11.0, .32, title, 16, NAVY, True)
    text(1.37, y+.45, 11.0, .25, detail, 12, GRAY)
    text(1.37, y+.75, 11.0, .22, reason, 10.6, TEAL)

rect(.62, 5.88, 12.05, .67, NAVY)
text(.83, 5.99, 11.63, .21, 'ETAPA QUANTIFICADA — EQUIPARAÇÃO DAS IDADES NO CENÁRIO BASE ORIGINAL', 9.5, '#8DD9CA', True)
text(.83, 6.25, 11.63, .24,
     '2027–2036: homens 60 → 65 e mulheres 55 → 62  |  13 pagamentos  |  100% do fluxo elegível',
     12, WHITE)
text(.65, 6.69, 12.0, .22,
     'Sem contribuição mensal não significa ausência de custeio: o segurado especial pode contribuir sobre a produção.',
     9.3, GRAY)
slide.notes_slide.notes_text_frame.text = (
    'Desenho de política proposto, não descrição da legislação vigente. A extinção/migração depende de alteração legal. '
    'A expressão não contributiva foi substituída por sem contribuição individual mensal: o segurado especial prevê '
    'contribuição sobre a comercialização. Preservar direitos adquiridos é diferente de congelar requisitos de '
    'novos requerimentos. A idade urbana depende da regra aplicável; a referência geral é H65/M62. '
    'BPC ao idoso: 65 anos para ambos, sem 13º e sujeito à avaliação de renda e outros requisitos. '
    'O cenário base escolhido não aplica filtro de 60% nem retira o 13º. '
    'O BPC aos 65 anos para ambos faz parte do desenho da proposta, mas não do cenário H65/M62 calculado. '
    'O CSV não distingue segmentos contributivo e assistencial: os efeitos do segmento contributivo não foram '
    'estimados separadamente. As coortes anteriores a 2027 ficam fora da diferença de despesa.\n\n'
    'Fontes oficiais consultadas em 18/11/2026:\n'
    'https://www.gov.br/inss/pt-br/direitos-e-deveres/aposentadorias/aposentadoria-programada\n'
    'https://www.gov.br/inss/pt-br/direitos-e-deveres/beneficios-assistenciais/beneficio-assistencial-a-pessoa-idosa-bpc-loas\n'
    'https://www.gov.br/inss/pt-br/direitos-e-deveres/inscricao-e-contribuicao/contribuicao-do-segurado-especial'
)

start('02 · Trajetórias de despesa')
text(.6, .77, 12.1, .48, 'Equiparar as idades reduz a despesa das novas coortes', 26, NAVY, True)
text(.62, 1.37, 12.0, .28,
     'Despesa anual em R$ bilhões de 2026 · Regra atual versus cenário base H65/M62 · 2027–2060', 13, GRAY)

# O gráfico do PowerPoint é nativo: séries e números podem ser editados.
data = CategoryChartData()
data.categories = years
data.add_series('Regra atual · H60/M55 · 13 pagamentos', reference)
data.add_series('Cenário base · H65/M62 · 13 pagamentos', proposal)
chart = slide.shapes.add_chart(XL_CHART_TYPE.LINE, Inches(.58), Inches(1.91),
    Inches(12.15), Inches(3.60), data).chart
chart.chart_style = 13
chart.has_legend = True
chart.legend.position = XL_LEGEND_POSITION.TOP
chart.legend.include_in_layout = False
chart.legend.font.name = 'DejaVu Sans'
chart.legend.font.size = Pt(11)
value_axis = chart.value_axis
value_axis.minimum_scale = 0
value_axis.maximum_scale = 600
value_axis.major_unit = 100
value_axis.tick_labels.font.name = 'DejaVu Sans'
value_axis.tick_labels.font.size = Pt(10)
value_axis.tick_labels.font.color.rgb = rgb(GRAY)
value_axis.tick_labels.number_format = '0'
value_axis.has_major_gridlines = True
value_axis.major_gridlines.format.line.color.rgb = rgb('#DDE5E8')
value_axis.major_tick_mark = XL_TICK_MARK.NONE
category_axis = chart.category_axis
category_axis.tick_labels.font.name = 'DejaVu Sans'
category_axis.tick_labels.font.size = Pt(10)
category_axis.tick_labels.font.color.rgb = rgb(GRAY)
# python-pptx não expõe tickLblSkip: registrar o intervalo no OOXML mantém
# as 34 categorias e mostra um rótulo a cada três anos, incluindo 2060.
for tag in ('c:tickLblSkip', 'c:tickMarkSkip'):
    skip = OxmlElement(tag)
    skip.set('val', '3')
    category_axis._element.insert_element_before(skip, 'c:noMultiLvlLbl')
category_axis.major_tick_mark = XL_TICK_MARK.NONE
plot = chart.plots[0]
plot.has_data_labels = True
plot.data_labels.show_value = False
for series, color in zip(chart.series, [NAVY, TEAL]):
    series.format.line.color.rgb = rgb(color)
    series.format.line.width = Pt(2.5)
    label = series.points[len(series.points)-1].data_label
    label.text_frame.text = fmt(series.values[-1])
    label.position = XL_LABEL_POSITION.ABOVE
    label.font.name = 'DejaVu Sans'
    label.font.size = Pt(12)
    label.font.bold = True
    label.font.color.rgb = rgb(color)
    series.smooth = False
pdf.drawImage(str(OUT/'trajetorias_despesa.png'), .58*72, 540-(1.91+3.60)*72,
              width=12.15*72, height=3.60*72)

text(.71, 5.57, 11.85, .23,
     'Transição de idades em 2027–2036; 13 pagamentos e 100% do fluxo elegível nos dois caminhos.',
     10.5, GRAY)
rect(.64, 6.0, 5.86, .64, LIGHT)
rect(6.72, 6.0, 5.95, .64, TEAL)
text(.85, 6.12, 5.43, .36,
     f'2060: menos R$ {fmt(last["economia_total_real"]/1e9)} bi/ano', 19, NAVY, True)
text(6.93, 6.12, 5.53, .36,
     f'2027–2060: menos R$ {fmt(last["economia_total_real_acumulada"]/1e12,3)} tri', 19, WHITE, True)
text(.66, 6.76, 12.0, .20,
     'Só coortes desde 2027; estoque anterior preservado. Migração ao BPC e separação por contribuição não foram quantificadas.',
     8.8, GRAY)
slide.notes_slide.notes_text_frame.text = (
    'Nenhum cálculo foi modificado. Dados de resultados/tres_cenarios_anual.csv, '
    'seleção exclusiva exercicio=base_65_62. Despesa real = pagamentos_referencia ou pagamentos_proposta '
    'multiplicados pelo salario e divididos pelo deflator; valores exibidos em bilhões. '
    'A comparação inclui somente as coortes de referência desde 2027 e não representa o gasto consolidado '
    'com toda a previdência rural e o BPC. O modelo não distingue contribuintes e não contribuintes; '
    'o cenário base é um recorte do efeito de equiparação H65/M62, mantendo 13 pagamentos e 100% de elegibilidade. '
    'Não inclui a migração ao BPC, o fim do 13º ou um filtro de renda. '
    'O estoque anterior permanece fora da diferença. Não há mortalidade, cessação, '
    'substituição por outros benefícios ou cálculo separado de pensões por morte. '
    'Valores reais de 2026; acumulação sem desconto financeiro adicional.'
)

prs.core_properties.title = 'Proposta de proteção ao idoso rural — dois slides'
prs.core_properties.subject = 'Premissas revisadas e comparação de despesa sem alterar os cálculos'
prs.core_properties.author = 'Projeções a partir de FilipeTomaz/filipetfd'
prs.save(OUT/f'{STEM}.pptx')
pdf.save()
assert len(prs.slides) == 2
assert sum(sh.has_chart for s in prs.slides for sh in s.shapes) == 1

with (OUT/'trajetorias_despesa.csv').open('w', encoding='utf-8', newline='') as f:
    writer = csv.writer(f, lineterminator='\n')
    writer.writerow(['ano', 'regra_atual_real_bi', 'cenario_base_real_bi', 'diferenca_real_bi'])
    writer.writerows(zip(years, reference, proposal, [r['economia_total_real']/1e9 for r in rows]))
metadata = {
    'repository': 'FilipeTomaz/filipetfd',
    'source_commit': subprocess.check_output(['git','-C',str(ROOT),'rev-parse','HEAD'],text=True).strip(),
    'source_csv': str(DATA.relative_to(ROOT)),
    'source_sha256': hashlib.sha256(DATA.read_bytes()).hexdigest(),
    'calculation_changed': False,
    'scenario': 'base_65_62: H65/M62, 13 pagamentos, 100% elegiveis, transicao 2027-2036',
    'chart_series': ['pagamentos_referencia*salario/deflator', 'pagamentos_proposta*salario/deflator'],
    'currency_base_year': 2026,
    'slides': 2,
    'editable_chart': True,
    'reference_2060_real_bi': reference[-1],
    'proposal_2060_real_bi': proposal[-1],
    'savings_2060_real_bi': last['economia_total_real']/1e9,
    'cumulative_savings_real_bi': last['economia_total_real_acumulada']/1e9,
}
(OUT/'metadados.json').write_text(json.dumps(metadata,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
print('Gerados: PowerPoint com gráfico editável, PDF de duas páginas, gráfico PNG/SVG e CSV de conferência.')
