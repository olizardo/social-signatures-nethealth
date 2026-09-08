#!/usr/bin/env python3
"""
Scripts/format_manuscript.py
Normalizes manuscript styling adhering strictly to AGENTS.md:
- Replaces styles.xml and fontTable.xml with template_example.docx definitions
- Sets all body prose paragraphs to Normal text style:
  Alegreya Sans, 11 pt (sz=22), 1.5 spacing (line=360), 0.5 inch first-line indent (firstLine=720, NO hanging), justified (both)
- Converts all Office Math (<m:oMath>, <m:oMathPara>) blocks to standard text runs (<w:r>)
- Normalizes heading hierarchy: Title (22pt burgundy), Heading1 (16pt burgundy), Heading2 (14pt burgundy)
- Strips alien font overrides (Calibri, Cambria, Nova Mono, Times New Roman)
- Formats references in APA hanging indent (0.5 in) with Alegreya Sans 11 pt
"""

import sys
import zipfile
import re
import os
import xml.etree.ElementTree as ET

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
        
        if txt in ['k', 'N', 'p', 'z', 'b', 'r', 'J', 'W', 'H', 'M', 'P', 'Q', 'alpha', 'beta', 'd']:
            ET.SubElement(rPr, f'{{{ns["w"]}}}i')
            
        t = ET.SubElement(r, f'{{{ns["w"]}}}t')
        t.set('{http://www.w3.org/XML/1998/namespace}space', 'preserve')
        t.text = txt
        
        # Replace m in parent
        for parent in p.iter():
            if m in list(parent):
                idx = list(parent).index(m)
                parent.remove(m)
                parent.insert(idx, r)
                break

def sanitize_rpr(rPr, ns, default_sz='22', keep_color=False):
    if rPr is None:
        return
    # Strip alien fonts and set Alegreya Sans
    rFonts = rPr.find('w:rFonts', ns)
    if rFonts is None:
        rFonts = ET.SubElement(rPr, f'{{{ns["w"]}}}rFonts')
    for attr in list(rFonts.attrib.keys()):
        del rFonts.attrib[attr]
    for attr in ['ascii', 'cs', 'eastAsia', 'hAnsi']:
        rFonts.set(f'{{{ns["w"]}}}{attr}', 'Alegreya Sans')
    
    # Set font size
    sz = rPr.find('w:sz', ns)
    if sz is None: sz = ET.SubElement(rPr, f'{{{ns["w"]}}}sz')
    sz.set(f'{{{ns["w"]}}}val', default_sz)
    
    szCs = rPr.find('w:szCs', ns)
    if szCs is None: szCs = ET.SubElement(rPr, f'{{{ns["w"]}}}szCs')
    szCs.set(f'{{{ns["w"]}}}val', default_sz)
    
    # Color
    if not keep_color:
        color = rPr.find('w:color', ns)
        if color is None: color = ET.SubElement(rPr, f'{{{ns["w"]}}}color')
        color.set(f'{{{ns["w"]}}}val', '222222')
        
    for prop in ['shd', 'highlight', 'vertAlign']:
        p_node = rPr.find(f'w:{prop}', ns)
        if p_node is not None:
            rPr.remove(p_node)

def main():
    if len(sys.argv) < 3:
        print("Usage: python3 format_manuscript.py <input.docx> <output.docx>")
        sys.exit(1)
        
    in_docx = sys.argv[1]
    out_docx = sys.argv[2]
    
    print(f"[format_manuscript.py] Formatting {in_docx}...")
    with zipfile.ZipFile(in_docx, 'r') as z:
        all_files = {name: z.read(name) for name in z.namelist()}
        
    # Inject proven styles.xml and fontTable.xml from templates/ if available
    if os.path.exists('templates/styles.xml'):
        with open('templates/styles.xml', 'rb') as f:
            all_files['word/styles.xml'] = f.read()
        print("  Injected reference styles.xml from templates/styles.xml")
        
    if os.path.exists('templates/fontTable.xml'):
        with open('templates/fontTable.xml', 'rb') as f:
            all_files['word/fontTable.xml'] = f.read()
        print("  Injected reference fontTable.xml from templates/fontTable.xml")
        
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
    
    for idx, p in enumerate(body.findall('w:p', ns)):
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
        
        # 1. Document Title (Paragraph 0)
        if idx == 0 or "The Persistent Architecture" in p_text:
            if pStyle is None: pStyle = ET.SubElement(pPr, f'{{{ns["w"]}}}pStyle')
            pStyle.set(f'{{{ns["w"]}}}val', 'Title')
            
            jc = pPr.find('w:jc', ns)
            if jc is None: jc = ET.SubElement(pPr, f'{{{ns["w"]}}}jc')
            jc.set(f'{{{ns["w"]}}}val', 'center')
            
            ind = pPr.find('w:ind', ns)
            if ind is None: ind = ET.SubElement(pPr, f'{{{ns["w"]}}}ind')
            ind.set(f'{{{ns["w"]}}}firstLine', '0')
            ind.set(f'{{{ns["w"]}}}left', '0')
            ind.set(f'{{{ns["w"]}}}right', '0')
            if f'{{{ns["w"]}}}hanging' in ind.attrib:
                del ind.attrib[f'{{{ns["w"]}}}hanging']
                
            for r in p.findall('w:r', ns):
                rPr = r.find('w:rPr', ns)
                if rPr is not None:
                    # preserve bold for title
                    sanitize_rpr(rPr, ns, default_sz='44', keep_color=True)
            continue
            
        # 2. Title Page Metadata (preceding 1. Introduction)
        if not past_title_page:
            # Check if this paragraph is "Abstract" heading
            if p_text == "Abstract":
                if pStyle is None: pStyle = ET.SubElement(pPr, f'{{{ns["w"]}}}pStyle')
                pStyle.set(f'{{{ns["w"]}}}val', 'Heading1')
                jc = pPr.find('w:jc', ns)
                if jc is None: jc = ET.SubElement(pPr, f'{{{ns["w"]}}}jc')
                jc.set(f'{{{ns["w"]}}}val', 'left')
                ind = pPr.find('w:ind', ns)
                if ind is None: ind = ET.SubElement(pPr, f'{{{ns["w"]}}}ind')
                ind.set(f'{{{ns["w"]}}}firstLine', '0')
                ind.set(f'{{{ns["w"]}}}left', '0')
                ind.set(f'{{{ns["w"]}}}right', '0')
                if f'{{{ns["w"]}}}hanging' in ind.attrib: del ind.attrib[f'{{{ns["w"]}}}hanging']
                continue
                
            # Check if this is the abstract body text
            if len(p_text) > 100 and "How do individuals" in p_text:
                # Abstract body: normal text
                if pStyle is not None: pPr.remove(pStyle)
                jc = pPr.find('w:jc', ns)
                if jc is None: jc = ET.SubElement(pPr, f'{{{ns["w"]}}}jc')
                jc.set(f'{{{ns["w"]}}}val', 'both')
                ind = pPr.find('w:ind', ns)
                if ind is None: ind = ET.SubElement(pPr, f'{{{ns["w"]}}}ind')
                ind.set(f'{{{ns["w"]}}}firstLine', '720')
                ind.set(f'{{{ns["w"]}}}left', '0')
                ind.set(f'{{{ns["w"]}}}right', '0')
                if f'{{{ns["w"]}}}hanging' in ind.attrib: del ind.attrib[f'{{{ns["w"]}}}hanging']
                spacing = pPr.find('w:spacing', ns)
                if spacing is None: spacing = ET.SubElement(pPr, f'{{{ns["w"]}}}spacing')
                spacing.set(f'{{{ns["w"]}}}line', '360')
                spacing.set(f'{{{ns["w"]}}}lineRule', 'auto')
                spacing.set(f'{{{ns["w"]}}}before', '0')
                spacing.set(f'{{{ns["w"]}}}after', '0')
                for r in p.findall('w:r', ns):
                    rPr = r.find('w:rPr', ns)
                    sanitize_rpr(rPr, ns, default_sz='22')
                continue
                
            # Other cover metadata: Author, Affiliation, Date -> Centered
            jc = pPr.find('w:jc', ns)
            if jc is None: jc = ET.SubElement(pPr, f'{{{ns["w"]}}}jc')
            jc.set(f'{{{ns["w"]}}}val', 'center')
            
            ind = pPr.find('w:ind', ns)
            if ind is not None:
                ind.set(f'{{{ns["w"]}}}firstLine', '0')
                ind.set(f'{{{ns["w"]}}}left', '0')
                ind.set(f'{{{ns["w"]}}}right', '0')
                if f'{{{ns["w"]}}}hanging' in ind.attrib: del ind.attrib[f'{{{ns["w"]}}}hanging']
                
            for r in p.findall('w:r', ns):
                rPr = r.find('w:rPr', ns)
                sanitize_rpr(rPr, ns, default_sz='24' if "Omar Lizardo" in p_text else '22')
            continue
            
        # 3. Main Section Headings (Heading1: 16pt bold burgundy)
        is_h1 = bool(re.match(r'^\d+\.\s+[A-Za-z]', p_text) or p_text in ["Abstract", "References"])
        is_h2 = bool(re.match(r'^\d+\.\d+\s+[A-Za-z]', p_text))
        is_h3 = bool(re.match(r'^\d+\.\d+\.\d+\s+[A-Za-z]', p_text))
        
        if is_h1:
            if pStyle is None: pStyle = ET.SubElement(pPr, f'{{{ns["w"]}}}pStyle')
            pStyle.set(f'{{{ns["w"]}}}val', 'Heading1')
            jc = pPr.find('w:jc', ns)
            if jc is None: jc = ET.SubElement(pPr, f'{{{ns["w"]}}}jc')
            jc.set(f'{{{ns["w"]}}}val', 'left')
            ind = pPr.find('w:ind', ns)
            if ind is None: ind = ET.SubElement(pPr, f'{{{ns["w"]}}}ind')
            ind.set(f'{{{ns["w"]}}}firstLine', '0')
            ind.set(f'{{{ns["w"]}}}left', '0')
            ind.set(f'{{{ns["w"]}}}right', '0')
            if f'{{{ns["w"]}}}hanging' in ind.attrib: del ind.attrib[f'{{{ns["w"]}}}hanging']
            spacing = pPr.find('w:spacing', ns)
            if spacing is None: spacing = ET.SubElement(pPr, f'{{{ns["w"]}}}spacing')
            spacing.set(f'{{{ns["w"]}}}before', '300')
            spacing.set(f'{{{ns["w"]}}}after', '60')
            for r in p.findall('w:r', ns):
                rPr = r.find('w:rPr', ns)
                sanitize_rpr(rPr, ns, default_sz='32', keep_color=True)
            continue
            
        if is_h2:
            if pStyle is None: pStyle = ET.SubElement(pPr, f'{{{ns["w"]}}}pStyle')
            pStyle.set(f'{{{ns["w"]}}}val', 'Heading2')
            jc = pPr.find('w:jc', ns)
            if jc is None: jc = ET.SubElement(pPr, f'{{{ns["w"]}}}jc')
            jc.set(f'{{{ns["w"]}}}val', 'left')
            ind = pPr.find('w:ind', ns)
            if ind is None: ind = ET.SubElement(pPr, f'{{{ns["w"]}}}ind')
            ind.set(f'{{{ns["w"]}}}firstLine', '0')
            ind.set(f'{{{ns["w"]}}}left', '0')
            ind.set(f'{{{ns["w"]}}}right', '0')
            if f'{{{ns["w"]}}}hanging' in ind.attrib: del ind.attrib[f'{{{ns["w"]}}}hanging']
            spacing = pPr.find('w:spacing', ns)
            if spacing is None: spacing = ET.SubElement(pPr, f'{{{ns["w"]}}}spacing')
            spacing.set(f'{{{ns["w"]}}}before', '200')
            spacing.set(f'{{{ns["w"]}}}after', '40')
            for r in p.findall('w:r', ns):
                rPr = r.find('w:rPr', ns)
                sanitize_rpr(rPr, ns, default_sz='28', keep_color=True)
            continue
            
        if is_h3:
            if pStyle is None: pStyle = ET.SubElement(pPr, f'{{{ns["w"]}}}pStyle')
            pStyle.set(f'{{{ns["w"]}}}val', 'Heading3')
            jc = pPr.find('w:jc', ns)
            if jc is None: jc = ET.SubElement(pPr, f'{{{ns["w"]}}}jc')
            jc.set(f'{{{ns["w"]}}}val', 'left')
            ind = pPr.find('w:ind', ns)
            if ind is None: ind = ET.SubElement(pPr, f'{{{ns["w"]}}}ind')
            ind.set(f'{{{ns["w"]}}}firstLine', '0')
            ind.set(f'{{{ns["w"]}}}left', '0')
            ind.set(f'{{{ns["w"]}}}right', '0')
            if f'{{{ns["w"]}}}hanging' in ind.attrib: del ind.attrib[f'{{{ns["w"]}}}hanging']
            for r in p.findall('w:r', ns):
                rPr = r.find('w:rPr', ns)
                sanitize_rpr(rPr, ns, default_sz='24', keep_color=True)
            continue
            
        # 4. Table/Figure Captions & Notes
        if re.match(r'^(Table|Figure)\s+\d+\.', p_text):
            if pStyle is not None: pPr.remove(pStyle)
            jc = pPr.find('w:jc', ns)
            if jc is None: jc = ET.SubElement(pPr, f'{{{ns["w"]}}}jc')
            jc.set(f'{{{ns["w"]}}}val', 'left')
            ind = pPr.find('w:ind', ns)
            if ind is None: ind = ET.SubElement(pPr, f'{{{ns["w"]}}}ind')
            ind.set(f'{{{ns["w"]}}}firstLine', '0')
            ind.set(f'{{{ns["w"]}}}left', '0')
            ind.set(f'{{{ns["w"]}}}right', '0')
            if f'{{{ns["w"]}}}hanging' in ind.attrib: del ind.attrib[f'{{{ns["w"]}}}hanging']
            spacing = pPr.find('w:spacing', ns)
            if spacing is None: spacing = ET.SubElement(pPr, f'{{{ns["w"]}}}spacing')
            spacing.set(f'{{{ns["w"]}}}before', '120')
            spacing.set(f'{{{ns["w"]}}}after', '60')
            for r in p.findall('w:r', ns):
                rPr = r.find('w:rPr', ns)
                sanitize_rpr(rPr, ns, default_sz='22')
            continue
            
        if p_text.startswith("Note:") or p_text.startswith("Note."):
            if pStyle is not None: pPr.remove(pStyle)
            ind = pPr.find('w:ind', ns)
            if ind is None: ind = ET.SubElement(pPr, f'{{{ns["w"]}}}ind')
            ind.set(f'{{{ns["w"]}}}firstLine', '0')
            ind.set(f'{{{ns["w"]}}}left', '0')
            ind.set(f'{{{ns["w"]}}}right', '0')
            if f'{{{ns["w"]}}}hanging' in ind.attrib: del ind.attrib[f'{{{ns["w"]}}}hanging']
            spacing = pPr.find('w:spacing', ns)
            if spacing is None: spacing = ET.SubElement(pPr, f'{{{ns["w"]}}}spacing')
            spacing.set(f'{{{ns["w"]}}}before', '40')
            spacing.set(f'{{{ns["w"]}}}after', '120')
            for r in p.findall('w:r', ns):
                rPr = r.find('w:rPr', ns)
                sanitize_rpr(rPr, ns, default_sz='20')
            continue
            
        # 5. Drawings (Centered)
        if p.find('.//w:drawing', ns) is not None:
            if pStyle is not None: pPr.remove(pStyle)
            jc = pPr.find('w:jc', ns)
            if jc is None: jc = ET.SubElement(pPr, f'{{{ns["w"]}}}jc')
            jc.set(f'{{{ns["w"]}}}val', 'center')
            ind = pPr.find('w:ind', ns)
            if ind is not None:
                ind.set(f'{{{ns["w"]}}}firstLine', '0')
                ind.set(f'{{{ns["w"]}}}left', '0')
                ind.set(f'{{{ns["w"]}}}right', '0')
                if f'{{{ns["w"]}}}hanging' in ind.attrib: del ind.attrib[f'{{{ns["w"]}}}hanging']
            continue
            
        # 6. References (APA hanging indent)
        if in_references:
            if pStyle is not None: pPr.remove(pStyle)
            jc = pPr.find('w:jc', ns)
            if jc is None: jc = ET.SubElement(pPr, f'{{{ns["w"]}}}jc')
            jc.set(f'{{{ns["w"]}}}val', 'left')
            ind = pPr.find('w:ind', ns)
            if ind is None: ind = ET.SubElement(pPr, f'{{{ns["w"]}}}ind')
            ind.set(f'{{{ns["w"]}}}left', '720')
            ind.set(f'{{{ns["w"]}}}hanging', '720')
            if f'{{{ns["w"]}}}firstLine' in ind.attrib: del ind.attrib[f'{{{ns["w"]}}}firstLine']
            spacing = pPr.find('w:spacing', ns)
            if spacing is None: spacing = ET.SubElement(pPr, f'{{{ns["w"]}}}spacing')
            spacing.set(f'{{{ns["w"]}}}line', '360')
            spacing.set(f'{{{ns["w"]}}}lineRule', 'auto')
            spacing.set(f'{{{ns["w"]}}}before', '0')
            spacing.set(f'{{{ns["w"]}}}after', '60')
            for r in p.findall('w:r', ns):
                rPr = r.find('w:rPr', ns)
                sanitize_rpr(rPr, ns, default_sz='22')
            continue
            
        # 7. Standard Body Prose Paragraphs
        # Remove any Pandoc BodyText / FirstParagraph style
        if pStyle is not None:
            pPr.remove(pStyle)
            
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
