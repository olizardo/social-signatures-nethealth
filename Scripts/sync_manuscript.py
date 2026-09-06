#!/usr/bin/env python3
"""
Scripts/sync_manuscript.py
DOM-based OpenXML table & figure injector adhering strictly to AGENTS.md:
- In-place XML injection of APA 7th tables and high-resolution figures
- 6.5-inch full printable portrait width scaling (9360 dxa / 5,943,600 EMUs)
- Dual DrawingML extent synchronization (cx, cy)
- Mandatory XML escaping and strict ECMA-376 tag ordering
- Universal APA 7th table standards (no vertical borders, 1pt top/bottom, 0.5pt header-bottom)
"""

import os
import re
import sys
import struct
import zipfile
import xml.etree.ElementTree as ET

def xml_escape(s):
    if s is None: return ""
    return str(s).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace('"', "&quot;")

def get_png_dimensions(image_path):
    if not os.path.exists(image_path):
        return 2550, 1650
    with open(image_path, "rb") as f:
        data = f.read(24)
        if len(data) >= 24 and data.startswith(b'\x89PNG\r\n\x1a\n'):
            return struct.unpack('>II', data[16:24])
    return 2550, 1650

def parse_markdown_table(file_path):
    if not os.path.exists(file_path):
        return [], []
    with open(file_path, "r", encoding="utf-8") as f:
        lines = [line.strip() for line in f if line.strip()]
    table_lines = [line for line in lines if line.startswith("|") and line.endswith("|")]
    if len(table_lines) < 3: return [], []
    headers = [c.strip().strip('*').strip() for c in table_lines[0].strip("|").split("|")]
    rows = []
    for line in table_lines[2:]:
        row = [c.strip() for c in line.strip("|").split("|")]
        rows.append(row)
    return headers, rows

def format_cell_runs(text, is_header=False):
    parts = re.split(r"<br\s*/?>", text, flags=re.IGNORECASE)
    runs_xml = []
    for idx, part in enumerate(parts):
        if idx > 0:
            runs_xml.append('<w:r><w:br/></w:r>')
        escaped = xml_escape(part.strip())
        if is_header:
            runs_xml.append(f'<w:r><w:rPr><w:b/></w:rPr><w:t>{escaped}</w:t></w:r>')
        else:
            runs_xml.append(f'<w:r><w:t>{escaped}</w:t></w:r>')
    return "".join(runs_xml)

def create_apa_table_xml(headers, rows_data, col_widths=None):
    total_w = 9360  # 6.5 in portrait width in dxa
    num_cols = len(headers)
    if col_widths is None:
        col1_w = int(total_w * 0.35)
        rem_w = total_w - col1_w
        sub_w = int(rem_w / (num_cols - 1)) if num_cols > 1 else rem_w
        col_widths = [col1_w] + [sub_w] * (num_cols - 2)
        if num_cols > 1:
            col_widths.append(total_w - sum(col_widths))
        else:
            col_widths = [total_w]

    xml = [f'<w:tbl xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:tblPr><w:tblW w:w="{total_w}" w:type="dxa"/><w:jc w:val="left"/><w:tblBorders><w:top w:val="single" w:sz="8" w:space="0" w:color="000000"/><w:left w:val="none"/><w:bottom w:val="single" w:sz="8" w:space="0" w:color="000000"/><w:right w:val="none"/><w:insideH w:val="none"/><w:insideV w:val="none"/></w:tblBorders><w:tblLayout w:type="fixed"/><w:tblCellMar><w:top w:w="120" w:type="dxa"/><w:bottom w:w="120" w:type="dxa"/><w:left w:w="140" w:type="dxa"/><w:right w:w="140" w:type="dxa"/></w:tblCellMar></w:tblPr><w:tblGrid>']
    for w in col_widths: xml.append(f'<w:gridCol w:w="{w}"/>')
    xml.append('</w:tblGrid>')
    
    # Header Row
    xml.append('<w:tr><w:trPr><w:tblHeader/><w:cantSplit/></w:trPr>')
    for i, h in enumerate(headers):
        align = "left" if i == 0 else "center"
        runs = format_cell_runs(h, is_header=True)
        xml.append(f'<w:tc><w:tcPr><w:tcW w:w="{col_widths[i]}" w:type="dxa"/><w:tcBorders><w:bottom w:val="single" w:sz="4" w:space="0" w:color="000000"/></w:tcBorders></w:tcPr><w:p><w:pPr><w:suppressAutoHyphens/><w:spacing w:before="0" w:after="0"/><w:ind w:left="0" w:right="0" w:firstLine="0" w:hanging="0"/><w:jc w:val="{align}"/></w:pPr>{runs}</w:p></w:tc>')
    xml.append('</w:tr>')
    
    # Data Rows
    for row in rows_data:
        xml.append('<w:tr><w:trPr><w:cantSplit/></w:trPr>')
        for i, val in enumerate(row):
            w_idx = min(i, len(col_widths) - 1)
            align = "left" if i == 0 else "center"
            runs = format_cell_runs(val, is_header=False)
            no_wrap = "<w:noWrap/>" if i > 0 else ""
            xml.append(f'<w:tc><w:tcPr><w:tcW w:w="{col_widths[w_idx]}" w:type="dxa"/>{no_wrap}</w:tcPr><w:p><w:pPr><w:suppressAutoHyphens/><w:spacing w:before="0" w:after="0"/><w:ind w:left="0" w:right="0" w:firstLine="0" w:hanging="0"/><w:jc w:val="{align}"/></w:pPr>{runs}</w:p></w:tc>')
        xml.append('</w:tr>')
    xml.append('</w:tbl>')
    return "".join(xml)

def create_drawing_xml(r_id, image_path):
    pw, ph = get_png_dimensions(image_path)
    cx = 5943600  # 6.5 in portrait width in EMUs
    cy = int(round(5943600 * (ph / pw)))
    
    xml = (
        f'<w:p xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        f'<w:pPr><w:spacing w:before="60" w:after="120"/><w:ind w:left="0" w:right="0" w:firstLine="0" w:hanging="0"/><w:jc w:val="center"/></w:pPr>'
        f'<w:r>'
        f'<w:drawing xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing">'
        f'<wp:inline distT="0" distB="0" distL="0" distR="0">'
        f'<wp:extent cx="{cx}" cy="{cy}"/>'
        f'<wp:docPr id="1" name="Figure"/>'
        f'<wp:cNvGraphicFramePr><a:graphicFrameLocks xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" noChangeAspect="1"/></wp:cNvGraphicFramePr>'
        f'<a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">'
        f'<a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">'
        f'<pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">'
        f'<pic:nvPicPr>'
        f'<pic:cNvPr id="0" name="Figure"/>'
        f'<pic:cNvPicPr><a:picLocks noChangeAspect="1" noChangeArrowheads="1"/></pic:cNvPicPr>'
        f'</pic:nvPicPr>'
        f'<pic:blipFill>'
        f'<a:blip xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" r:embed="{r_id}"/>'
        f'<a:stretch><a:fillRect/></a:stretch>'
        f'</pic:blipFill>'
        f'<pic:spPr>'
        f'<a:xfrm><a:off x="0" y="0"/><a:ext cx="{cx}" cy="{cy}"/></a:xfrm>'
        f'<a:prstGeom prst="rect"><a:avLst/></a:prstGeom>'
        f'</pic:spPr>'
        f'</pic:pic>'
        f'</a:graphicData>'
        f'</a:graphic>'
        f'</wp:inline>'
        f'</w:drawing>'
        f'</w:r>'
        f'</w:p>'
    )
    return xml

def main():
    if len(sys.argv) < 3:
        print("Usage: python3 sync_manuscript.py <input.docx> <output.docx>")
        sys.exit(1)
    
    in_docx = sys.argv[1]
    out_docx = sys.argv[2]
    
    print(f"[sync_manuscript.py] Loading {in_docx}...")
    with zipfile.ZipFile(in_docx, 'r') as z:
        all_files = {name: z.read(name) for name in z.namelist()}
    
    # 1. Parse tables from cache/
    tables = {}
    h1, r1 = parse_markdown_table("cache/table1_cohort_summary.md")
    if h1 and r1: tables["{{TABLE_1}}"] = create_apa_table_xml(h1, r1, [2360, 2100, 1100, 2400, 1400])
    
    h2, r2 = parse_markdown_table("cache/table2_stability_tests.md")
    if h2 and r2: tables["{{TABLE_2}}"] = create_apa_table_xml(h2, r2, [2560, 1100, 1600, 1600, 1300, 1200])
    
    h3, r3 = parse_markdown_table("cache/table3_parametric_models.md")
    if h3 and r3: tables["{{TABLE_3}}"] = create_apa_table_xml(h3, r3, [1960, 1200, 1700, 1300, 1100, 1000, 1100])
    
    h4, r4 = parse_markdown_table("cache/table4_support_tiers.md")
    if h4 and r4: tables["{{TABLE_4}}"] = create_apa_table_xml(h4, r4, [1960, 1000, 1000, 1000, 1100, 1100, 1100, 1100])
    
    h5, r5 = parse_markdown_table("cache/table5_multilevel_models.md")
    if h5 and r5: tables["{{TABLE_5}}"] = create_apa_table_xml(h5, r5, [3660, 1900, 1900, 1900])
    
    h6, r6 = parse_markdown_table("cache/table6_personality_models.md")
    if h6 and r6: tables["{{TABLE_6}}"] = create_apa_table_xml(h6, r6, [3360, 1500, 1500, 1500, 1500])
    
    # 2. Add figures to relationships and media
    figures = {
        "{{FIGURE_1}}": "Plots/fig01_mean_signatures_by_window.png",
        "{{FIGURE_2}}": "Plots/fig02_self_vs_ref_divergence.png",
        "{{FIGURE_3}}": "Plots/fig03_power_law_vs_exponential.png",
        "{{FIGURE_4}}": "Plots/fig04_parameter_burnin.png",
        "{{FIGURE_5}}": "Plots/fig05_rank_by_support_tiers.png",
        "{{FIGURE_6}}": "Plots/fig06_turnover_vs_stability.png",
        "{{FIGURE_7}}": "Plots/fig07_personality_signature_effects.png"
    }
    
    # Parse rels
    rels_path = 'word/_rels/document.xml.rels'
    root_rels = ET.fromstring(all_files[rels_path])
    
    existing_rids = [e.get('Id') for e in root_rels if e.get('Id', '').startswith('rId')]
    max_rid_num = max([int(r[3:]) for r in existing_rids if r[3:].isdigit()] + [0])
    
    existing_images = [f for f in all_files.keys() if f.startswith('word/media/image')]
    max_img_num = max([int(re.search(r'image(\d+)', f).group(1)) for f in existing_images if re.search(r'image(\d+)', f)] + [0])
    
    figure_drawings = {}
    for tag, img_path in figures.items():
        if os.path.exists(img_path):
            max_rid_num += 1
            max_img_num += 1
            r_id = f"rId{max_rid_num}"
            img_name = f"image{max_img_num}.png"
            target_media = f"word/media/{img_name}"
            
            with open(img_path, "rb") as f_img:
                all_files[target_media] = f_img.read()
            
            rel_elem = ET.Element('{http://schemas.openxmlformats.org/package/2006/relationships}Relationship')
            rel_elem.set('Id', r_id)
            rel_elem.set('Type', 'http://schemas.openxmlformats.org/officeDocument/2006/relationships/image')
            rel_elem.set('Target', f'media/{img_name}')
            root_rels.append(rel_elem)
            
            figure_drawings[tag] = create_drawing_xml(r_id, img_path)
            print(f"  [Figure] Added {img_path} as {img_name} ({r_id}) for {tag}")
        else:
            print(f"  [Warning] {img_path} not found for {tag}")
            
    all_files[rels_path] = ET.tostring(root_rels, encoding='utf-8', xml_declaration=True)
    
    # 3. Replace tags in document.xml
    doc_path = 'word/document.xml'
    root_doc = ET.fromstring(all_files[doc_path])
    ns = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
    body = root_doc.find('w:body', ns)
    
    # Replace paragraphs containing tags
    new_children = []
    injected_count = 0
    for child in list(body):
        p_text = ''.join(child.itertext()).strip()
        matched = False
        
        # Check table tags
        for t_tag, t_xml in tables.items():
            if t_tag in p_text:
                new_children.append(ET.fromstring(t_xml))
                matched = True
                injected_count += 1
                print(f"  [Injection] Injected table for {t_tag}")
                break
        if matched: continue
        
        # Check figure tags
        for f_tag, f_xml in figure_drawings.items():
            if f_tag in p_text:
                new_children.append(ET.fromstring(f_xml))
                matched = True
                injected_count += 1
                print(f"  [Injection] Injected figure for {f_tag}")
                break
        if matched: continue
        
        new_children.append(child)
        
    # Rebuild body
    # keep sectPr at end
    sectPr = body.find('w:sectPr', ns)
    body.clear()
    for c in new_children:
        if c.tag.endswith('sectPr'): continue
        body.append(c)
    if sectPr is not None:
        body.append(sectPr)
        
    all_files[doc_path] = ET.tostring(root_doc, encoding='utf-8', xml_declaration=True)
    print(f"[sync_manuscript.py] Injected {injected_count} tables and figures.")
    
    # Save output docx
    with zipfile.ZipFile(out_docx, 'w', compression=zipfile.ZIP_DEFLATED) as z_out:
        for name, data in all_files.items():
            z_out.writestr(name, data)
    print(f"[sync_manuscript.py] Successfully wrote {out_docx}!")

if __name__ == '__main__':
    main()
