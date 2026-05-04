from __future__ import annotations

from datetime import datetime
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import cm
from reportlab.platypus import (
    Image,
    PageBreak,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)

ROOT = Path(__file__).resolve().parents[1]
PRINTS_DIR = ROOT / "docs" / "module-prints"
DATE_TAG = datetime.now().strftime("%Y-%m-%d")
OUTPUT_PDF = ROOT / "docs" / f"relatorio_modulos_soutracking_{DATE_TAG}.pdf"

MODULES = [
    {
        "menu": "Dashboard",
        "slug": "dashboard",
        "status": "Hibrido",
        "observacao": "Painel com telas reais de operacao e um bloco de estrutura futura.",
    },
    {
        "menu": "Mapa",
        "slug": "mapa",
        "status": "Hibrido",
        "observacao": "Mapa operacional ativo com atalhos visuais ainda em estrutura.",
    },
    {
        "menu": "Veiculos",
        "slug": "veiculos",
        "status": "Hibrido",
        "observacao": "Cadastro e consultas operacionais com alguns subitens em estrutura.",
    },
    {
        "menu": "Rotas",
        "slug": "rotas",
        "status": "Parcial",
        "observacao": "Historico e replay ativos; regras avancadas de rota ainda em estrutura.",
    },
    {
        "menu": "Alertas",
        "slug": "alertas",
        "status": "Parcial",
        "observacao": "Lista funcional de alertas com catalogo de tipos em estrutura.",
    },
    {
        "menu": "Cercas",
        "slug": "cercas",
        "status": "Parcial",
        "observacao": "Lista de cercas ativa com criacao inteligente ainda em estrutura.",
    },
    {
        "menu": "Chamados",
        "slug": "chamados",
        "status": "Parcial",
        "observacao": "Fluxo de chamados ativo com trilhas especializadas em estrutura.",
    },
    {
        "menu": "Comunicacao",
        "slug": "comunicacao",
        "status": "Parcial",
        "observacao": "Hub de conversa ativo com automacoes e atalhos em estrutura.",
    },
    {
        "menu": "IA Operacional",
        "slug": "ia_operacional",
        "status": "Estrutura",
        "observacao": "Modulo com cards de proposta visual, sem acoplamento real ainda.",
    },
    {
        "menu": "Financeiro",
        "slug": "financeiro",
        "status": "Parcial",
        "observacao": "Clientes e cobrancas ativos; meios de pagamento em estrutura.",
    },
    {
        "menu": "Estoque",
        "slug": "estoque",
        "status": "Demo visual",
        "observacao": "Painel demo novo com resumo, tabela e movimentacoes simuladas.",
    },
    {
        "menu": "MDVR / Cameras",
        "slug": "mdvr_cameras",
        "status": "Demo visual",
        "observacao": "Painel demo visual com grade de cameras e eventos simulados.",
    },
    {
        "menu": "Demo Telemetria",
        "slug": "demo_telemetria",
        "status": "Demo visual",
        "observacao": "Tela de demonstracao dedicada com metricas e eventos clicaveis.",
    },
    {
        "menu": "Relatorios",
        "slug": "relatorios",
        "status": "Parcial",
        "observacao": "Relatorios base ativos com catalogo executivo em estrutura.",
    },
    {
        "menu": "Automacoes",
        "slug": "automacoes",
        "status": "Estrutura",
        "observacao": "Modulo planejado com itens de regra e gatilho ainda visuais.",
    },
    {
        "menu": "Configuracoes",
        "slug": "configuracoes",
        "status": "Hibrido",
        "observacao": "Gestao administrativa ampla com trilhas de integracao em estrutura.",
    },
]



def _find_image_for_slug(slug: str) -> Path | None:
    candidates = sorted(PRINTS_DIR.glob(f"*_{slug}.png"))
    return candidates[0] if candidates else None



def build_pdf() -> Path:
    styles = getSampleStyleSheet()
    title_style = ParagraphStyle(
        "Title",
        parent=styles["Title"],
        fontSize=24,
        leading=28,
        textColor=colors.HexColor("#0F172A"),
        spaceAfter=12,
    )
    subtitle_style = ParagraphStyle(
        "SubTitle",
        parent=styles["BodyText"],
        fontSize=11,
        leading=15,
        textColor=colors.HexColor("#334155"),
        spaceAfter=10,
    )
    section_style = ParagraphStyle(
        "Section",
        parent=styles["Heading2"],
        fontSize=15,
        leading=19,
        textColor=colors.HexColor("#1D4ED8"),
        spaceAfter=8,
    )
    tiny_style = ParagraphStyle(
        "Tiny",
        parent=styles["BodyText"],
        fontSize=9,
        leading=12,
        textColor=colors.HexColor("#475569"),
    )

    doc = SimpleDocTemplate(
        str(OUTPUT_PDF),
        pagesize=A4,
        leftMargin=1.5 * cm,
        rightMargin=1.5 * cm,
        topMargin=1.5 * cm,
        bottomMargin=1.5 * cm,
        title="Relatorio de Modulos SouTracking",
        author="GitHub Copilot",
    )

    status_count: dict[str, int] = {}
    for item in MODULES:
        status_count[item["status"]] = status_count.get(item["status"], 0) + 1

    summary_rows = [["Status", "Quantidade"]]
    for key in sorted(status_count.keys()):
        summary_rows.append([key, str(status_count[key])])

    module_rows = [["Modulo", "Estagio", "Observacao"]]
    for item in MODULES:
        module_rows.append([item["menu"], item["status"], item["observacao"]])

    flow = []
    flow.append(Paragraph("SouTracking - Relatorio de Modulos", title_style))
    flow.append(
        Paragraph(
            f"Gerado em {datetime.now().strftime('%d/%m/%Y %H:%M')} | Fonte: HomeShell (menus operacionais)",
            subtitle_style,
        )
    )
    flow.append(
        Paragraph(
            "Objetivo: visualizar o estado atual de cada modulo para priorizar entregas.",
            subtitle_style,
        )
    )

    flow.append(Paragraph("Resumo por estagio", section_style))
    summary_table = Table(summary_rows, colWidths=[10 * cm, 5 * cm])
    summary_table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#E2E8F0")),
                ("TEXTCOLOR", (0, 0), (-1, 0), colors.HexColor("#0F172A")),
                ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
                ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#CBD5E1")),
                ("ALIGN", (1, 1), (1, -1), "CENTER"),
                ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
            ]
        )
    )
    flow.append(summary_table)
    flow.append(Spacer(1, 0.4 * cm))

    flow.append(Paragraph("Mapa atual dos modulos", section_style))
    module_table = Table(module_rows, colWidths=[4.5 * cm, 2.7 * cm, 8.8 * cm])
    module_table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#E2E8F0")),
                ("TEXTCOLOR", (0, 0), (-1, 0), colors.HexColor("#0F172A")),
                ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
                ("GRID", (0, 0), (-1, -1), 0.45, colors.HexColor("#CBD5E1")),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
            ]
        )
    )
    flow.append(module_table)
    flow.append(PageBreak())

    # Prints section in landscape for better readability.
    landscape_doc = SimpleDocTemplate(
        str(OUTPUT_PDF),
        pagesize=landscape(A4),
        leftMargin=1.2 * cm,
        rightMargin=1.2 * cm,
        topMargin=1.2 * cm,
        bottomMargin=1.2 * cm,
    )

    first_part = flow[:]

    screenshot_flow = []
    screenshot_flow.append(Paragraph("Prints por modulo", section_style))
    screenshot_flow.append(
        Paragraph(
            "Cada pagina abaixo traz o estado visual atual capturado no preview local.",
            tiny_style,
        )
    )
    screenshot_flow.append(Spacer(1, 0.3 * cm))

    max_w = landscape(A4)[0] - (2.4 * cm)
    max_h = landscape(A4)[1] - (4.0 * cm)

    for item in MODULES:
        image_path = _find_image_for_slug(item["slug"])
        screenshot_flow.append(
            Paragraph(f"{item['menu']} - {item['status']}", section_style)
        )
        if image_path and image_path.exists():
            img = Image(str(image_path))
            iw, ih = img.imageWidth, img.imageHeight
            ratio = min(max_w / iw, max_h / ih)
            img.drawWidth = iw * ratio
            img.drawHeight = ih * ratio
            screenshot_flow.append(img)
            screenshot_flow.append(
                Paragraph(
                    f"Arquivo: {image_path.name}",
                    tiny_style,
                )
            )
        else:
            screenshot_flow.append(
                Paragraph("Print nao encontrado para este modulo.", tiny_style)
            )
        screenshot_flow.append(PageBreak())

    doc.build(first_part)

    # Append the screenshot pages by rebuilding a complete landscape-friendly document
    # with cover + screenshots in one pass for stable pagination.
    merged = []
    merged.extend(first_part)
    merged.append(PageBreak())
    merged.extend(screenshot_flow)
    landscape_doc.build(merged)

    return OUTPUT_PDF


if __name__ == "__main__":
    output = build_pdf()
    print(f"PDF criado em: {output}")
