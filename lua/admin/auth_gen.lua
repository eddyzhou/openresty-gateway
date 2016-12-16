local resty_random = require "resty.random"
local str = require "resty.string"
local mysql = require "resty.mysql"
local resty_lock = require "resty.lock"
local cjson = require "cjson.safe"
local config = require "config.config"
local ngx_shared = ngx.shared
local secret_cache = ngx_shared['secret_cache']


local function gen()
    local random = resty_random.bytes(16)
    local secret_key = str.to_hex(random)
    return secret_key
end


local function write_to_db(access_key, secret_key)
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

    local sql = "insert into auth(access_key, secret_key, description) values('" 
                .. access_key .. "', '" .. secret_key .. "', 'game pay key')"
    local res, err, errno, sqlstate = db:query(sql)
    if not res then
        ngx.log(ngx.ERR, "Insert access_key, secret_key failed.", " errno:" , errno, ", err:", err)
        db:close()
        return false
    end

    db:close()
    return true
end


local function write_to_cache(access_key, secret_key)
	local lock = resty_lock:new("locks_store")
	lock:lock('secret_lock')
    secret_cache:set(access_key, secret_key)
    lock:unlock()
end


local function on_fail()
	ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR  
    ngx.header.content_type = "application/json; charset=utf-8"  
    ngx.say(cjson.encode({ 
        ['error'] = 'generate access_key, secret_key failed',
    }))
end


local function handle()
    --local body = ngx.var.request_body
    --local post_data = cjson.decode(body)
    local post_data = ngx.req.get_post_args()
    local access_key = post_data['access_key']

	local secret_key = gen()
	if not write_to_db(access_key, secret_key) then
		on_fail()
        return
	end

	write_to_cache(access_key, secret_key)

	ngx.status = ngx.HTTP_OK  
    ngx.header.content_type = "application/json; charset=utf-8"  
    ngx.say(cjson.encode({ 
    	['access_key'] = access_key,
    	['secret_key'] = secret_key,
    }))
end


handle()