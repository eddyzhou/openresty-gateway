local mysql = require "resty.mysql"
local resty_lock = require "resty.lock"
local config = require "config.config"
local ngx_shared = ngx.shared
local app_cache = ngx_shared['app_cache']
local secret_cache = ngx_shared['secret_cache']

local mark_load_db_key = "mark_load_app_setting"


local function load_db_setting()
    ngx.log(ngx.INFO, 'Load db setting')
    local db, err = mysql:new()
    if not db then
        ngx.log(ngx.ERR, "Init setting db failed.", " err:", err)
        return false
    end

    db:set_timeout(1000) -- 1 sec
    local dbconfig = config.setting_db_conf
    local env = os.getenv("ENV")
    ngx.log(ngx.DEBUG, env)
    if env == "dev" then
        dbconfig = config.dev_setting_db_conf
    elseif env == "test" then
        dbconfig = config.test_setting_db_conf
    end
    local ok, err, errno, sqlstate = db:connect{
        host = dbconfig.host,
        port = dbconfig.port,
        database = dbconfig.database,
        user = dbconfig.user,
        password = dbconfig.password,
    }
    if not ok then
        ngx.log(ngx.ERR, "Connect to setting db failed.", " errno:" , errno, ", err:", err)
        return false
    end

    local res, err, errno, sqlstate = db:query("select location, app, secret_key from access_app")
    if not res then
        ngx.log(ngx.ERR, "Load access_app failed.", ", err:", err)
        db:close()
        return false
    end
    for _, r in pairs(res) do
    	local location = r['location']
    	local secret = r['secret_key']
    	local app = r['app']
    	app_cache:set(location, app)
    	secret_cache:set(app, secret)
    end

    local res, err, errno, sqlstate = db:query("select access_key, secret_key from auth")
    if not res then
        ngx.log(ngx.ERR, "Load auth failed.", ", err:", err)
        db:close()
        return false
    end
    for _, r in pairs(res) do
    	local access_key = r['access_key']
    	local secret_key = r['secret_key']
    	secret_cache:set(access_key, secret_key)
    end

    db:close()
    return true
end


local function get_access_app(location, try_lock)
    local val, _ = app_cache:get(location)
    if val or (not try_lock) then
        return val
    end

    local lock = resty_lock:new("locks_store")
    lock:lock('app_lock')
    
    val, _ = app_cache:get(location)
    if val then
        lock:unlock()
        return val
    end

    local success, _, _ = app_cache:add(mark_load_db_key, 1)
    if success then 
    	local succ = load_db_setting()
    	if not succ then
    		app_cache:delete(mark_load_db_key)
    	end
    end
    lock:unlock()

    val, _ = app_cache:get(location)
    return val
end


local function get_secret(access_key)
    local val, _ = secret_cache:get(access_key)
    if val then
        return val
    end

    local lock = resty_lock:new("locks_store")
    lock:lock('secret_lock')
    
    val, _ = secret_cache:get(access_key)
    if val then
        lock:unlock()
        return val
    end

    local success, _, _ = app_cache:add(mark_load_db_key, 1)
    if success then 
    	local succ = load_db_setting()
    	if not succ then
    		app_cache:delete(mark_load_db_key)
    	end
    end
    lock:unlock()

    val, _ = secret_cache:get(access_key)
    return val
end


local function delete_mark_key()
    ngx.log(ngx.DEBUG, "delete mark key")
    app_cache:delete(mark_load_db_key)
end


local _M = {
    _VERSION = '0.0.1',
}

local mt = { __index = _M }

_M.get_secret = get_secret
_M.get_access_app = get_access_app
_M.delete_mark_key = delete_mark_key

return _M

