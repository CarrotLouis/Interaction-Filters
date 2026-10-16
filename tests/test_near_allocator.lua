local ROOT=assert(arg[1])
local M=assert(loadfile(ROOT..'/src/near_allocator.lua'))()
local K=65536
local site=0x100000000
local limits={minimum=K,maximum=0x7ffffffeffff,granularity=K}
local checks=0
local function check(x,why)assert(x,why);checks=checks+1 end
local function fake()
    local OS={calls=0,released=0}
    function OS.limits()return limits end
    function OS.release()OS.released=OS.released+1 end
    return OS
end
-- Regression: the old probes cover only 64 MiB either side of the image.
-- Occupy those bands, but leave a free region 256 MiB from the instruction.
local OS=fake()
local free=site+256*1024*1024
function OS.query(cursor)
    if cursor<free then return {base=site,size=free-site,free=false}end
    return {base=free,size=16*K,free=true}
end
function OS.alloc(address,size)OS.calls=OS.calls+1;return address end
local address,d=M.allocate(OS,site,8192)
check(address==free and d.queries==2 and OS.calls==1,'large occupied band not skipped')
check(address>site+64*1024*1024,'fixture does not exceed old scan range')
check(d.backend=='VirtualQuery + VirtualAlloc' and d.last_error==0,'fallback diagnostics')
-- OS-assisted allocation has bounds and makes no page-by-page queries.
OS=fake()
function OS.alloc2(low,high,size)
    check(low%K==0 and (high+1)%K==0 and size==8192,'VirtualAlloc2 address requirements')
    return free
end
function OS.query()error('unexpected query after alloc2 success')end
address,d=M.allocate(OS,site,8192)
check(address==free and d.backend=='VirtualAlloc2' and d.queries==0,'alloc2')
-- A missing/failed alloc2 is optional; query actual free regions next.
OS=fake()
function OS.alloc2()return nil,87 end
function OS.query(cursor)return {base=cursor,size=K,free=true}end
function OS.alloc(a)return a end
address,d=M.allocate(OS,site,8192)
check(address==site and d.alloc2_error==87 and d.attempts==2,'alloc2 fallback')
-- Access denied is reported, not retried thousands of times.
OS=fake()
function OS.query(cursor)return {base=cursor,size=K,free=true}end
function OS.alloc()OS.calls=OS.calls+1;return nil,5 end
address,d=M.allocate(OS,site,8192)
check(address==nil and d.last_error==5 and OS.calls==1,'access denial hidden/repeated')
-- A allocation race can be retried in a different free region.
OS=fake()
function OS.query(cursor)return {base=cursor,size=K,free=true}end
function OS.alloc(a)OS.calls=OS.calls+1;if OS.calls==1 then return nil,487 end;return a end
address,d=M.allocate(OS,site,8192)
check(address==site+K and OS.calls==2,'address race stopped discovery')
-- Guard the address-space API and never spin on an invalid/non-progressing row.
OS=fake()
function OS.query(cursor)return {base=cursor,size=0,free=false}end
address,d=M.allocate(OS,site,8192)
check(address==nil and d.queries==1 and d.reason:find('invalid',1,true),'invalid query loop')
OS=fake()
function OS.query()return nil,87 end
address,d=M.allocate(OS,site,8192)
check(address==nil and d.last_error==87,'query error absent')
-- Clamp a DLL near the system's upper address ceiling and preserve granularity.
local hi=0x7ffffffeffff
local low,high,g=M.bounds(hi-K,8192,limits)
check(low>=K and high<=hi and low%g==0 and (high+1)%g==0,'upper user-space boundary')
low,high,g=M.bounds(K,8192,limits)
check(low==K and high>low,'lower user-space boundary')
-- Reject a broken backend returning memory outside the signed jump window.
OS=fake()
function OS.alloc2()return site+0x90000000 end
function OS.query()return nil,87 end
address,d=M.allocate(OS,site,8192)
check(address==nil and OS.released==1,'out-of-range allocation leaked')
print('PASS '..checks..' near-allocation checks: occupied 64 MiB bands, OS range API, free-region fallback and errors')
