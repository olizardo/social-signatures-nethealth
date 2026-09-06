#!/usr/bin/env python3
"""
Scripts/format_manuscript.py
Normalizes manuscript styling adhering strictly to AGENTS.md:
- Sets all body prose paragraphs to Normal text style:
  Alegreya Sans, 11 pt (sz=22), 1.5 spacing (line=360), 0.5 inch first-line indent (firstLine=720, NO hanging), justified (both)
- Converts all Office Math (<m:oMath>, <m:oMathPara>) blocks to standard text runs (<w:r>) to eliminate alien Cambria serif fonts
- Strips alien font overrides (Nova Mono, Cardo, Cambria, Times New Roman)
- Preserves title page metadata (centered, 0 indent), headings (left-aligned, 0 indent), captions (0 indent), notes (0 indent), drawings (centered), tables, and page breaks
- Formats references in APA hanging indent (0.5 in) with Alegreya Sans 11 pt
"""

import sys
import zipfile
import re
import xml.etree.ElementTree as ET

def update_styles_xml(styles_bytes):
    ET.register_namespace('w', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main')
    root = ET.fromstring(styles_bytes)
    ns = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
    
    # 1. Update docDefaults
    docDefaults = root.find('w:docDefaults', ns)
    if docDefaults is not None:
        rPrDef = docDefaults.find('w:rPrDefault/w:rPr', ns)
        if rPrDef is not None:
            rFonts = rPrDef.find('w:rFonts', ns)
            if rFonts is not None:
                for attr in ['ascii', 'cs', 'eastAsia', 'hAnsi']:
                    rFonts.set(f'{{{ns["w"]}}}{attr}', 'Alegreya Sans')
            sz = rPrDef.find('w:sz', ns)
            if sz is not None:
                sz.set(f'{{{ns["w"]}}}val', '22')
            szCs = rPrDef.find('w:szCs', ns)
            if szCs is not None:
                szCs.set(f'{{{ns["w"]}}}val', '22')

        pPrDef = docDefaults.find('w:pPrDefault/w:pPr', ns)
        if pPrDef is not None:
            spacing = pPrDef.find('w:spacing', ns)
            if spacing is not None:
                spacing.set(f'{{{ns["w"]}}}line', '360')
                spacing.set(f'{{{ns["w"]}}}lineRule', 'auto')
                spacing.set(f'{{{ns["w"]}}}before', '0')
                spacing.set(f'{{{ns["w"]}}}after', '0')
            ind = pPrDef.find('w:ind', ns)
            if ind is not None:
                if f'{{{ns["w"]}}}hanging' in ind.attrib:
                    del ind.attrib[f'{{{ns["w"]}}}hanging']
                ind.set(f'{{{ns["w"]}}}firstLine', '720')
                ind.set(f'{{{ns["w"]}}}left', '0')
                ind.set(f'{{{ns["w"]}}}right', '0')
            jc = pPrDef.find('w:jc', ns)
            if jc is not None:
                jc.set(f'{{{ns["w"]}}}val', 'both')

    # 2. Update styleId="Normal"
    for s in root.findall('w:style', ns):
        if s.attrib.get(f'{{{ns["w"]}}}styleId') == 'Normal':
            pPr = s.find('w:pPr', ns)
            if pPr is None:
                pPr = ET.SubElement(s, f'{{{ns["w"]}}}pPr')
            
            spacing = pPr.find('w:spacing', ns)
            if spacing is None:
                spacing = ET.SubElement(pPr, f'{{{ns["w"]}}}spacing')
            spacing.set(f'{{{ns["w"]}}}line', '360')
            spacing.set(f'{{{ns["w"]}}}lineRule', 'auto')
            spacing.set(f'{{{ns["w"]}}}before', '0')
            spacing.set(f'{{{ns["w"]}}}after', '0')

            ind = pPr.find('w:ind', ns)
            if ind is None:
                ind = ET.SubElement(pPr, f'{{{ns["w"]}}}ind')
            if f'{{{ns["w"]}}}hanging' in ind.attrib:
                del ind.attrib[f'{{{ns["w"]}}}hanging']
            ind.set(f'{{{ns["w"]}}}firstLine', '720')
            ind.set(f'{{{ns["w"]}}}left', '0')
            ind.set(f'{{{ns["w"]}}}right', '0')

            jc = pPr.find('w:jc', ns)
            if jc is None:
                jc = ET.SubElement(pPr, f'{{{ns["w"]}}}jc')
            jc.set(f'{{{ns["w"]}}}val', 'both')

            rPr = s.find('w:rPr', ns)
            if rPr is None:
                rPr = ET.SubElement(s, f'{{{ns["w"]}}}rPr')
            
            rFonts = rPr.find('w:rFonts', ns)
            if rFonts is None:
                rFonts = ET.SubElement(rPr, f'{{{ns["w"]}}}rFonts')
            for attr in ['ascii', 'cs', 'eastAsia', 'hAnsi']:
                rFonts.set(f'{{{ns["w"]}}}{attr}', 'Alegreya Sans')

            sz = rPr.find('w:sz', ns)
            if sz is None:
                sz = ET.SubElement(rPr, f'{{{ns["w"]}}}sz')
            sz.set(f'{{{ns["w"]}}}val', '22')

            szCs = rPr.find('w:szCs', ns)
            if szCs is None:
                szCs = ET.SubElement(rPr, f'{{{ns["w"]}}}szCs')
            szCs.set(f'{{{ns["w"]}}}val', '22')

    return ET.tostring(root, encoding='utf-8', xml_declaration=True)

def sanitize_rpr(rPr, ns, default_sz='22'):
    if rPr is None:
        return
    # Strip alien fonts
    rFonts = rPr.find('w:rFonts', ns)
    if rFonts is not None:
        for attr in ['ascii', 'cs', 'eastAsia', 'hAnsi']:
            rFonts.set(f'{{{ns["w"]}}}{attr}', 'Alegreya Sans')
    
    # Set size
    sz = rPr.find('w:sz', ns)
    if sz is not None:
        sz.set(f'{{{ns["w"]}}}val', default_sz)
    szCs = rPr.find('w:szCs', ns)
    if szCs is not None:
        szCs.set(f'{{{ns["w"]}}}val', default_sz)
        
    for prop in ['color', 'shd', 'highlight', 'vertAlign']:
        p_node = rPr.find(f'w:{prop}', ns)
        if p_node is not None:
            rPr.remove(p_node)

def convert_omath_to_runs(p, ns, default_sz='22'):
    """Converts any <m:oMath> or <m:oMathPara> elements inside a paragraph into standard <w:r> text runs."""
    m_ns = ns.get('m', 'http://schemas.openxmlformats.org/officeDocument/2006/math')
    math_nodes = p.findall(f'.//{{{m_ns}}}oMath')
    for m in math_nodes:
        txt = ''.join(m.itertext()).strip()
        if not txt:
            continue
        r = ET.Element(f'{{{ns["w"]}}}r')
        rPr = ET.SubElement(r, f'{{{ns["w"]}}}rPr')
        
        rFonts = ET.SubElement(rPr, f'{{{ns["w"]}}}rFonts')
        for attr in ['ascii', 'cs', 'eastAsia', 'hAnsi']:
            rFonts.set(f'{{{ns["w"]}}}{attr}', 'Alegreya Sans')
            
        sz = ET.SubElement(rPr, f'{{{ns["w"]}}}sz')
        sz.set(f'{{{ns["w"]}}}val', default_sz)
        szCs = ET.SubElement(rPr, f'{{{ns["w"]}}}szCs')
        szCs.set(f'{{{ns["w"]}}}val', default_sz)
        
        # Add italics for standard single-letter math variables
        if txt in ['k', 'N', 'p', 'z', 'b', 'r', 'J', 'W', 'H', 'M', 'P', 'Q']:
            ET.SubElement(rPr, f'{{{ns["w"]}}}i')
            
        t = ET.SubElement(r, f'{{{ns["w"]}}}t')
        t.set('{http://www.w3.org/XML/1998/namespace}space', 'preserve')
        t.text = txt
        
        # Replace m in parent
        # find parent of m
        for parent in p.iter():
            if m in list(parent):
                idx = list(parent).index(m)
                parent.remove(m)
                parent.insert(idx, r)
                break

def main():
    if len(sys.argv) < 3:
        print("Usage: python3 format_manuscript.py <input.docx> <output.docx>")
        sys.exit(1)
        
    in_docx = sys.argv[1]
    out_docx = sys.argv[2]
    
    print(f"[format_manuscript.py] Formatting {in_docx}...")
    with zipfile.ZipFile(in_docx, 'r') as z:
        all_files = {name: z.read(name) for name in z.namelist()}
        
    # Update styles.xml
    if 'word/styles.xml' in all_files:
        all_files['word/styles.xml'] = update_styles_xml(all_files['word/styles.xml'])
        
    # Process document.xml
    doc_path = 'word/document.xml'
    root = ET.fromstring(all_files[doc_path])
    ns = {
        'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
        'm': 'http://schemas.openxmlformats.org/officeDocument/2006/math'
    }
    body = root.find('w:body', ns)
    
    past_title_page = False
    in_references = False
    
    for p in body.findall('w:p', ns):
        # Convert any Office Math elements to regular text runs
        convert_omath_to_runs(p, ns, default_sz='22')
        
        p_text = ''.join(p.itertext()).strip()
        
        # Check section boundaries
        if "1. Introduction" in p_text or p_text.startswith("1. Introduction"):
            past_title_page = True
        if "References" in p_text and len(p_text) < 30:
            in_references = True
            
        pPr = p.find('w:pPr', ns)
        if pPr is None:
            pPr = ET.SubElement(p, f'{{{ns["w"]}}}pPr')
            
        pStyle = pPr.find('w:pStyle', ns)
        style_val = pStyle.get(f'{{{ns["w"]}}}val') if pStyle is not None else ""
        
        # 1. Title Page elements
        if not past_title_page:
            # Center alignment, zero indent
            jc = pPr.find('w:jc', ns)
            if jc is None: jc = ET.SubElement(pPr, f'{{{ns["w"]}}}jc')
            jc.set(f'{{{ns["w"]}}}val', 'center')
            
            ind = pPr.find('w:ind', ns)
            if ind is not None:
                ind.set(f'{{{ns["w"]}}}firstLine', '0')
                ind.set(f'{{{ns["w"]}}}left', '0')
                ind.set(f'{{{ns["w"]}}}right', '0')
                if f'{{{ns["w"]}}}hanging' in ind.attrib:
                    del ind.attrib[f'{{{ns["w"]}}}hanging']
                    
            # Set Title styling
            if style_val == "Title" or "The Persistent Architecture" in p_text:
                for r in p.findall('w:r', ns):
                    rPr = r.find('w:rPr', ns)
                    if rPr is None: rPr = ET.SubElement(r, f'{{{ns["w"]}}}rPr')
                    b = rPr.find('w:b', ns)
                    if b is None: ET.SubElement(rPr, f'{{{ns["w"]}}}b')
                    sz = rPr.find('w:sz', ns)
                    if sz is None: sz = ET.SubElement(rPr, f'{{{ns["w"]}}}sz')
                    sz.set(f'{{{ns["w"]}}}val', '32')  # 16pt
                    rFonts = rPr.find('w:rFonts', ns)
                    if rFonts is None: rFonts = ET.SubElement(rPr, f'{{{ns["w"]}}}rFonts')
                    for attr in ['ascii', 'cs', 'eastAsia', 'hAnsi']:
                        rFonts.set(f'{{{ns["w"]}}}{attr}', 'Alegreya Sans')
            continue
            
        # 2. Headings
        if style_val.startswith("Heading"):
            jc = pPr.find('w:jc', ns)
            if jc is None: jc = ET.SubElement(pPr, f'{{{ns["w"]}}}jc')
            jc.set(f'{{{ns["w"]}}}val', 'left')
            
            ind = pPr.find('w:ind', ns)
            if ind is not None:
                ind.set(f'{{{ns["w"]}}}firstLine', '0')
                ind.set(f'{{{ns["w"]}}}left', '0')
                ind.set(f'{{{ns["w"]}}}right', '0')
                if f'{{{ns["w"]}}}hanging' in ind.attrib:
                    del ind.attrib[f'{{{ns["w"]}}}hanging']
                    
            for r in p.findall('w:r', ns):
                rPr = r.find('w:rPr', ns)
                if rPr is not None:
                    rFonts = rPr.find('w:rFonts', ns)
                    if rFonts is not None:
                        for attr in ['ascii', 'cs', 'eastAsia', 'hAnsi']:
                            rFonts.set(f'{{{ns["w"]}}}{attr}', 'Alegreya Sans')
            continue
            
        # 3. Table/Figure Captions & Notes
        if re.match(r'^(Table|Figure)\s+\d+\.', p_text):
            jc = pPr.find('w:jc', ns)
            if jc is None: jc = ET.SubElement(pPr, f'{{{ns["w"]}}}jc')
            jc.set(f'{{{ns["w"]}}}val', 'left')
            
            ind = pPr.find('w:ind', ns)
            if ind is None: ind = ET.SubElement(pPr, f'{{{ns["w"]}}}ind')
            ind.set(f'{{{ns["w"]}}}firstLine', '0')
            ind.set(f'{{{ns["w"]}}}left', '0')
            ind.set(f'{{{ns["w"]}}}right', '0')
            if f'{{{ns["w"]}}}hanging' in ind.attrib:
                del ind.attrib[f'{{{ns["w"]}}}hanging']
                
            spacing = pPr.find('w:spacing', ns)
            if spacing is None: spacing = ET.SubElement(pPr, f'{{{ns["w"]}}}spacing')
            spacing.set(f'{{{ns["w"]}}}before', '120')
            spacing.set(f'{{{ns["w"]}}}after', '60')
            
            for r in p.findall('w:r', ns):
                rPr = r.find('w:rPr', ns)
                sanitize_rpr(rPr, ns, default_sz='22')
            continue
            
        if p_text.startswith("Note:") or p_text.startswith("Note."):
            ind = pPr.find('w:ind', ns)
            if ind is None: ind = ET.SubElement(pPr, f'{{{ns["w"]}}}ind')
            ind.set(f'{{{ns["w"]}}}firstLine', '0')
            ind.set(f'{{{ns["w"]}}}left', '0')
            ind.set(f'{{{ns["w"]}}}right', '0')
            if f'{{{ns["w"]}}}hanging' in ind.attrib:
                del ind.attrib[f'{{{ns["w"]}}}hanging']
            spacing = pPr.find('w:spacing', ns)
            if spacing is None: spacing = ET.SubElement(pPr, f'{{{ns["w"]}}}spacing')
            spacing.set(f'{{{ns["w"]}}}before', '40')
            spacing.set(f'{{{ns["w"]}}}after', '120')
            for r in p.findall('w:r', ns):
                rPr = r.find('w:rPr', ns)
                sanitize_rpr(rPr, ns, default_sz='20') # 10pt for notes
            continue
            
        # 4. Drawings
        if p.find('.//w:drawing', ns) is not None:
            jc = pPr.find('w:jc', ns)
            if jc is None: jc = ET.SubElement(pPr, f'{{{ns["w"]}}}jc')
            jc.set(f'{{{ns["w"]}}}val', 'center')
            ind = pPr.find('w:ind', ns)
            if ind is not None:
                ind.set(f'{{{ns["w"]}}}firstLine', '0')
                if f'{{{ns["w"]}}}hanging' in ind.attrib:
                    del ind.attrib[f'{{{ns["w"]}}}hanging']
            continue
            
        # 5. References (APA hanging indent)
        if in_references:
            jc = pPr.find('w:jc', ns)
            if jc is None: jc = ET.SubElement(pPr, f'{{{ns["w"]}}}jc')
            jc.set(f'{{{ns["w"]}}}val', 'left')
            ind = pPr.find('w:ind', ns)
            if ind is None: ind = ET.SubElement(pPr, f'{{{ns["w"]}}}ind')
            ind.set(f'{{{ns["w"]}}}left', '720')
            ind.set(f'{{{ns["w"]}}}hanging', '720')
            if f'{{{ns["w"]}}}firstLine' in ind.attrib:
                del ind.attrib[f'{{{ns["w"]}}}firstLine']
            for r in p.findall('w:r', ns):
                rPr = r.find('w:rPr', ns)
                sanitize_rpr(rPr, ns, default_sz='22')
            continue
            
        # 6. Standard Body Prose Paragraphs
        jc = pPr.find('w:jc', ns)
        if jc is None: jc = ET.SubElement(pPr, f'{{{ns["w"]}}}jc')
        jc.set(f'{{{ns["w"]}}}val', 'both')
        
        spacing = pPr.find('w:spacing', ns)
        if spacing is None: spacing = ET.SubElement(pPr, f'{{{ns["w"]}}}spacing')
        spacing.set(f'{{{ns["w"]}}}line', '360')
        spacing.set(f'{{{ns["w"]}}}lineRule', 'auto')
        spacing.set(f'{{{ns["w"]}}}before', '0')
        spacing.set(f'{{{ns["w"]}}}after', '0')
        
        ind = pPr.find('w:ind', ns)
        if ind is None: ind = ET.SubElement(pPr, f'{{{ns["w"]}}}ind')
        ind.set(f'{{{ns["w"]}}}firstLine', '720')
        ind.set(f'{{{ns["w"]}}}left', '0')
        ind.set(f'{{{ns["w"]}}}right', '0')
        if f'{{{ns["w"]}}}hanging' in ind.attrib:
            del ind.attrib[f'{{{ns["w"]}}}hanging']
            
        for r in p.findall('w:r', ns):
            rPr = r.find('w:rPr', ns)
            sanitize_rpr(rPr, ns, default_sz='22')
            
    all_files[doc_path] = ET.tostring(root, encoding='utf-8', xml_declaration=True)
    
    with zipfile.ZipFile(out_docx, 'w', compression=zipfile.ZIP_DEFLATED) as z_out:
        for name, data in all_files.items():
            z_out.writestr(name, data)
            
    print(f"[format_manuscript.py] Formatted document saved to {out_docx}!")

if __name__ == '__main__':
    main()
