local config = require "config.config"
local db_setting = require "config.db_setting"
local get_headers = ngx.req.get_headers

local project_path = debug.getinfo(1, "S").source:match([[^@?(.*[\/])[^\/]-$]])
                      :gsub("/lua/utils", "")
local rule_path = project_path .. "rules"
local lua_path = project_path .. "lua"


function string.split(str, delimiter)
    if str == nil or str == "" or delimiter == nil then
        return str
    end

    local result = {}
    for match in (str..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match)
    end
    return result
end


local _M = {
    rule_path = rule_path,
    lua_path = lua_path,
}

function _M.get_client_ip()
    local ip = get_headers()["X-Real-IP"]
    
    if ip == nil then
        ip = get_headers()["X_Forwarded_For"]
    end

    if ip == nil then
        ip = ngx.var.remote_addr
    end

    if ip == nil then
        ip = "unknown"
    end

    return ip
end

function _M.load_rule(application, rule_file)
    local file = io.open(rule_path.."/"..application.."/"..rule_file, "r")
    if file == nil then
        file = io.open(rule_path.."/default/"..rule_file, "r")
        if file == nil then
            ngx.log(ngx.ERR, "Rule path err. rule:"..rule_file)
            return nil
        end
    end
    t = {}
    for line in file:lines() do
        table.insert(t, line)
    end
    file:close()
    return (t)
end

function _M.get_application(try_lock)
    local uri = ngx.var.uri or ''
    local location = string.split(uri, "/")[2]
    local val = db_setting.get_access_app(location, try_lock)
    if not val then
        if location == "" then
            return "default"
        else
            return location
        end
    else
        return val
    end
end

function _M.file_exists(file_name)
    local file = io.open(file_name)
    if file ~= nil then
        io.close(file)
    end
    return file ~= nil
end

function _M.is_array(tbl)
    local count=0
    for k, v in pairs(t) do
        if type(k) ~= "number" then 
            return false 
        else 
            count = count + 1 
        end
    end

    for i = 1, count do
        if not t[i] and type(t[i]) ~= "nil" then 
            return false 
        end
    end

    return true
end

function _M.merge(t1, t2)
    assert(t1)
    if not t2 then 
        return t1 
    end

    for k, v in pairs(t2) do
        t1[k] = v
    end

    return t1
end


return _M
