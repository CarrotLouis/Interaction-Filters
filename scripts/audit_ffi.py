"""The skill's declaration gate, including private __asm__ aliases and pcall cdefs."""
import re

FORBIDDEN={'GetCursorPos','GetClientRect','ScreenToClient','GetForegroundWindow',
           'GetAsyncKeyState','GetWindowThreadProcessId','GetCurrentProcessId'}

def audit(source):
    blocks=re.findall(r'ffi\.cdef\s*(?:,\s*)?\[\[(.*?)\]\]',source,re.S)
    blocks+=re.findall(r"ffi\.cdef\s*,\s*'([^']*)'",source)
    # Shared Runtime keeps its private, sentinel-protected declarations in a
    # local constant and calls ffi.cdef(DECLARATIONS) only once for every copy.
    for identifier in re.findall(r'ffi\.cdef\s*(?:\(\s*)?([A-Za-z_]\w*)',source):
        blocks+=re.findall(r'\b'+re.escape(identifier)+r'\s*=\s*\[\[(.*?)\]\]',source,re.S)
    declared=set()
    physical=set()
    pattern=r'\b([A-Za-z_]\w*)\s*\([^();]*\)\s*(?:__asm__\s*\(\s*"([^"]+)"\s*\))?\s*;'
    for block in blocks:
        for name,alias in re.findall(pattern,block):
            if name=='__asm__':
                continue
            declared.add(name)
            physical.add(alias or name)
            if alias:
                declared.add(alias) # module's bound public-key -> private FFI alias
    if physical & FORBIDDEN:
        raise SystemExit('FAIL forbidden user32 declaration: '+', '.join(sorted(physical & FORBIDDEN)))
    called=set(re.findall(r'\b(?:k|u|kernel32|user32|bcrypt|ffi\.C|kernel)\.([A-Za-z_]\w*)\s*\(',source))
    missing=called-declared
    if missing:
        raise SystemExit('FAIL called but not declared: '+', '.join(sorted(missing)))
    return declared,called

if __name__=='__main__':
    from pathlib import Path
    import sys
    declared,called=audit(Path(sys.argv[1]).read_text(encoding='utf-8'))
    print(f'PASS FFI declarations: {len(declared)} symbols, {len(called)} calls, no user32')
