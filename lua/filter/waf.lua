local utils = require "utils.utils"
local ngx_find = ngx.re.find
local get_headers = ngx.req.get_headers
local unescape = ngx.unescape_uri


local _M = {
    _VERSION = '0.0.1'
}

local mt = {
    __index = _M
}


function _M:new(waf_conf)
    local self = {
        waf_conf = waf_conf,
        application = utils.get_application(true),
    }
    return setmetatable(self, mt)
end


function _M:check_url()
    if not self.waf_conf['url_enable'] then
        return false
    end

    local rules = utils.load_rule(self.application, "url.rule")
    for _, rule in pairs(rules) do
        if rule ~= "" and ngx_find(ngx.var.request_uri, rule, "isjo") then
            ngx.log(ngx.ERR, ngx.var.request_uri .. " match url rule: " .. rule)
            ngx.exit(ngx.HTTP_FORBIDDEN)
            return true
        end
    end
    return false
end


function _M:check_get()
    if not self.waf_conf['get_enable'] then
        return false
    end

    local rules = utils.load_rule(self.application, "get.rule")
    local args  = ngx.req.get_uri_args()
    if not args then
        return false
    end

    for _, rule in pairs(rules) do
        for k, val in pairs(args) do
            if type(val) == "table" then
                local t = {}
                for k, v in pairs(val) do
                    if v == true then
                        v = ""
                    end
                    table.insert(t, v)
                end
                data = table.concat(t, " ")
            else
                data = val
            end

            if data and type(data) ~= "boolean" and rule ~= "" and ngx_find(unescape(data),rule, "isjo") then
                ngx.log(ngx.ERR, ngx.var.request_uri .. " match get rule： " .. rule)
                ngx.exit(ngx.HTTP_FORBIDDEN)
                return true
            end
        end
    end

    return false
end


function _M:check_post()
    if not self.waf_conf['post_enable'] then
        return false
    end
    
    local rules = utils.load_rule(self.application, "post.rule")
    local args = ngx.req.get_post_args()
    local data = ""

    for _, rule in pairs(rules) do
        for k, v in pairs(args) do
            if type(v) == "table" then
                if type(v[1]) == "boolean" then
                    return false
                end
                data = table.concat(v, ", ")
            else
                data = v
            end

            if data and type(data) ~= "boolean" and rule ~= "" and ngx_find(unescape(data), rule, "isjo") then
                ngx.log(ngx.ERR, ngx.var.request_uri .. " args：" .. data .. "，match post rule: " .. rule)
                ngx.exit(ngx.HTTP_FORBIDDEN)
                return true
            end
        end
    end

    return false
end


function _M:check_cookie()
    if not self.waf_conf['cookie_enable'] then
        return false
    end

    local ck = ngx.var.http_cookie
    if not ck then
        return false
    end

    local rules = utils.load_rule(self.application, "cookie.rule")
    for _, rule in pairs(rules) do
        if rule ~= "" and ngx_find(ck, rule, "isjo") then
            ngx.log(ngx.ERR, ngx.var.request_uri .. ", current cookie:" .. ck .. " match cookie rule: " .. rule)
            ngx.exit(ngx.HTTP_FORBIDDEN)
            return true
        end
    end

    return false
end


function _M:WAF()
    if self:check_url() then
        return true
    end

    if ngx.req.get_method() == "POST" then
        if self:check_post() then
            return true
        end
    else
        if self:check_get() then 
            return true
        end
    end

    return self:check_cookie()
end


return _M
