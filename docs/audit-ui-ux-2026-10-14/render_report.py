"""Rendu HTML du sous-ensemble Markdown utilisé par le rapport local."""
from pathlib import Path
import html, re
OUT=Path(__file__).resolve().parent
text=(OUT/'rapport.md').read_text(encoding='utf-8')

def inline(s):
    s=html.escape(s)
    s=re.sub(r'`([^`]+)`',r'<code>\1</code>',s)
    s=re.sub(r'\*\*([^*]+)\*\*',r'<strong>\1</strong>',s)
    s=re.sub(r'\[([^\]]+)\]\(([^)]+)\)',r'<a href="\2">\1</a>',s)
    return s

blocks=[];toc=[];lines=text.splitlines();i=0
while i<len(lines):
    line=lines[i]
    if not line.strip(): i+=1;continue
    h=re.match(r'^(#{1,6}) (.+)',line)
    if h:
        level=len(h[1]);id=f'section-{i}'
        if level==2:toc.append((id,h[2]))
        blocks.append(f'<h{level} id="{id}">{inline(h[2])}</h{level}>');i+=1;continue
    if line.startswith('|'):
        rows=[]
        while i<len(lines) and lines[i].startswith('|'):
            row=lines[i].strip().strip('|').split('|')
            if not all(re.fullmatch(r'\s*:?-+:?\s*',v) for v in row): rows.append(row)
            i+=1
        blocks.append('<div class="table"><table>')
        for j,row in enumerate(rows):
            tag='th' if j==0 else 'td'
            blocks.append('<tr>'+''.join(f'<{tag}>{inline(v.strip())}</{tag}>' for v in row)+'</tr>')
        blocks.append('</table></div>');continue
    listmatch=re.match(r'^(?:- |\d+\. )(.+)',line)
    if listmatch:
        blocks.append('<ul>')
        while i<len(lines):
            match=re.match(r'^(?:- |\d+\. )(.+)',lines[i])
            if not match:break
            blocks.append('<li>'+inline(match[1])+'</li>');i+=1
        blocks.append('</ul>');continue
    paragraph=[]
    while i<len(lines) and lines[i].strip() and not re.match(r'^(#|\||- |\d+\. )',lines[i]):
        paragraph.append(lines[i]);i+=1
    blocks.append('<p>'+' '.join(inline(p) for p in paragraph)+'</p>')

css='''body{margin:0;background:#f1f4f8;color:#172234;font:16px/1.7 system-ui,sans-serif}main{max-width:1100px;margin:0 auto;background:white;padding:40px 48px}h1{font-size:36px;line-height:1.2}h2{font-size:25px;margin-top:52px;border-top:1px solid #dbe2eb;padding-top:24px}h3{font-size:21px;line-height:1.4;margin-top:40px;background:#f2f6fa;border-left:4px solid #15803d;padding:16px}p,li{max-width:92ch}li{margin:10px 0}a{color:#115c3b;text-underline-offset:3px}code{font-size:.88em;background:#edf1f6;padding:2px 4px;border-radius:4px;overflow-wrap:anywhere}.table{overflow:auto}table{border-collapse:collapse;font-size:13px;width:100%;min-width:750px}th,td{padding:12px;text-align:left;vertical-align:top;border:1px solid #d7dee7}th{background:#edf3ef}nav{padding:20px;background:#edf3ef;border-radius:12px}nav a{display:inline-block;margin:4px 15px 4px 0}.links{font-weight:600}h2,h3{scroll-margin-top:20px}@media(max-width:650px){main{padding:24px 20px}h1{font-size:28px}body{font-size:15px}}@media print{body{background:white}main{padding:0;max-width:none}nav{display:none}h2,h3{break-after:avoid}.table{overflow:visible}table{min-width:0;font-size:10px}a{color:inherit}}'''
nav='<nav aria-label="Sommaire">'+''.join('<a href="#'+id+'">'+html.escape(label)+'</a>' for id,label in toc)+'</nav>'
page='<!doctype html><html lang="fr"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Audit UI/UX Statoo — rapport</title><style>'+css+'</style><main><p class="links"><a href="preuves.html">Preuves annotées</a> · <a href="couverture.csv">Couverture CSV</a> · <a href="rapport.md">Source Markdown</a></p>'+nav+''.join(blocks)+'</main></html>'
(OUT/'rapport.html').write_text(page,encoding='utf-8')
print('Rapport HTML créé ;',len(toc),'sections de premier niveau.')
