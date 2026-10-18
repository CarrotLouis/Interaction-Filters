-- Use Mod Options Menu's actual current production author API in a private VM.
-- Native UI is unavailable in this test process, so no game/UI pointers are called.
local ROOT,DIR,MOM=assert(arg[1]),assert(arg[2]),assert(arg[3])
local other='primary_pickup_tools.primary_pickup_blocker.team_support'
local seed=assert(io.open(DIR..'/ModOptionsMenu.values','wb'))
seed:write(other..'\ttrue\n');seed:close()
CowboyBingusModLoader={log_directory=DIR,open_log=function(name)return io.open(DIR..'/'..name,'w')end}
BingusTranslations={version=1,serial=0,packs={},game_language='en',steam_language=false}
mom_text={module=dofile(MOM..'/src/bingus_text.lua'),
          locales={en=dofile(MOM..'/locales/en.lua'),bundled={}}}
mom_files=setmetatable({}, {__index=function(files,name)
    local value=assert(loadfile(MOM..'/src/'..name..'.lua'))
    rawset(files,name,value);return value
end})
dofile(MOM..'/src/mod_options_menu.lua')
assert(ModOptionsMenu and ModOptionsMenu.api==1)
local Controller=assert(loadfile(ROOT..'/src/controller.lua'))()
local native={installed=false,active=false,blocked=0,enables=0,disables=0}
function native.enable()native.installed=true;native.active=true;native.enables=native.enables+1;return true end
function native.disable()native.installed=false;native.active=false;native.disables=native.disables+1;return true end
function native.audit()return true end
function native.configure(mask)native.mask=mask;if mask==0 then return native.disable()end;return native.enable()end
local locales=dofile(ROOT..'/src/locales.lua')
local c=Controller.new(_G,native,function(k)return locales.english.strings[k]end,function()end,function()end)
c.step()
assert(c.registered and ModOptionsMenu.get(Controller.OPTION)==true and c.active,'actual MOM registration/default ON')
assert(#Controller.DEFS==1 and c.filters.team_support==nil,'optional filters registered')
assert(ModOptionsMenu.set(Controller.OPTION,true))
c.step()
assert(c.enabled and c.active and native.enables==1,'actual MOM get/set ON')
assert(ModOptionsMenu.set(Controller.OPTION,false))
c.step()
assert(not c.enabled and not c.active and native.disables==1,'actual MOM get/set OFF')
-- Invalid values are refused by the real menu and cannot enable the feature.
assert(not ModOptionsMenu.set(Controller.OPTION,'on'))
c.step();assert(not c.active)
c.stop('test complete')
if type(shutdown)=='function' then shutdown()end
local saved=assert(io.open(DIR..'/ModOptionsMenu.values','rb'))
local content=saved:read('*a');saved:close()
assert(content:find(other..'\ttrue\n',1,true),'unregistered optional setting lost')
print('PASS actual Mod Options Menu: primary isolation row, defaults, get/set and value refusal')
