local utils  = require "utils.utils"
local config = require "config.config"
local db_setting = require "config.db_setting"


local function get_req_params()
    local req_method = ngx.req.get_method()
    local url_params = ngx.req.get_uri_args()
    if string.lower(req_method) == "post" 
        and ngx.var.content_type == "application/x-www-form-urlencoded" then
        local post_params = ngx.req.get_post_args()
        local req_params = utils.merge(url_params, post_params)
        return req_params
    else
        return url_params
    end
end

local function base_params(args)
    local t = {}
    for k, v in pairs(args) do
        if type(v) == 'string' then
            local val = ngx.escape_uri(k) .. "%3D" .. ngx.escape_uri(v)
            table.insert(t, val)
        elseif type(v) == 'table' then
            for _, iv in pairs(v) do
                local val = ngx.escape_uri(k) .. "%3D" .. ngx.escape_uri(iv)
                table.insert(t, val)
            end
        else
            local val = ngx.escape_uri(k) .. "%3D" .. ngx.escape_uri(tostring(v))
            table.insert(t, val)
        end
    end

    table.sort(t)
    local r = table.concat(t, "%26")

    if string.lower(ngx.req.get_method()) == "post" 
        and string.lower(ngx.var.content_type) ~= "application/x-www-form-urlencoded" then
        local body = ngx.req.get_body_data()
        if body ~= "" then
            r = r .. "%26" .. body
        end
    end

    return r
end

local function base_string(args)
    local req_method = ngx.req.get_method()
    local base_uri = ngx.escape_uri(ngx.var.scheme .. "://" .. ngx.var.http_host .. ngx.var.uri)
    local base_params = base_params(args)
    return req_method .. "&" .. base_uri .. "&" ..base_params
end

local ENCODE_CHARS = {
    ["+"] = "-",
    ["/"] = "_",
}

ngx.encode_base64url = function(value)
    return (ngx.encode_base64(value):gsub("[+/]", ENCODE_CHARS))
end


local _M = {
    _VERSION = '0.0.1'
}

local mt = {
    __index = _M
}


function _M:new(sig_conf)
    local self = {
        sig_conf = sig_conf,
    }
    return setmetatable(self, mt)
end


function _M:filter()
    local args = get_req_params()
    local sig = args['sig']
    if not sig then
        ngx.log(ngx.ERR, "No sig")
        ngx.exit(ngx.HTTP_FORBIDDEN)
        return true
    end
    args['sig'] = nil

    local app = utils.get_application(true)
    local secret_key = ""
    if app == "pay" then
        if not args['accesskey'] then
            ngx.log(ngx.ERR, "No accessKey")
            ngx.exit(ngx.HTTP_FORBIDDEN)
            return true
        end
        secret_key = db_setting.get_secret(args['accesskey'])
    else    
        if not (args['timestamp'] and args['nonce']) then
            ngx.log(ngx.ERR, "No timestamp or nonce")
            ngx.exit(ngx.HTTP_FORBIDDEN)
            return true
        end
        if args['accesskey'] then
            secret_key = db_setting.get_secret(args['accesskey'])
        else
            secret_key = db_setting.get_secret(app)
        end
    end
    if secret_key == nil or secret_key == "" then
        ngx.log(ngx.WARN, "No secret_key, use default.")
        secret_key = "hey~m.xunlei!"
    end

    local data = base_string(args)
    ngx.log(ngx.INFO, "base_string: " .. data)
    local mac = ngx.hmac_sha1(secret_key, data)
    local hashed = ngx.encode_base64url(mac)
    ngx.log(ngx.INFO, "sig: " .. hashed)
    if hashed ~= sig then
        ngx.log(ngx.ERR, "Invalid sig: " .. ngx.var.request_uri .. " args：" .. data .. "，sig: " .. sig)
        ngx.exit(ngx.HTTP_FORBIDDEN)
        return true
    end

    return false
end


return _M
