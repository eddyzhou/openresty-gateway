local cjson = require "cjson.safe"
local utils = require "utils.utils"
local ngx_shared = ngx.shared


local _M = {
    _VERSION = '0.0.1'
}

local mt = {
    __index = _M
}


function _M:new(ip_dict_name, referrer_dict_name, window_dict_name, spider_conf)
    local ip_dict = ngx_shared[ip_dict_name]
    local referrer_dict = ngx_shared[referrer_dict_name]
    local window_dict = ngx_shared[window_dict_name]

    local self = {
        ip_dict = ip_dict,
        referrer_dict = referrer_dict,
        window_dict = window_dict,
        spider_conf = spider_conf,
    }

    return setmetatable(self, mt)
end


function _M:check_spider_by_ip()
    local spider_conf = self.spider_conf['ip_spider']
    if not spider_conf['enable'] then
        return false
    end

    local ip = utils.get_client_ip()
    local host = ngx.var.host
    local key = ip .. host

    -- FIXME we really need dict:incr_or_init() to avoid race conditions here.
    local new_count, err = self.ip_dict:incr(key, 1)
    if not new_count then
        if err == "not found" then
            self.ip_dict:add(key, 1, spider_conf['exptime'])
            new_count = 1
        else
            ngx.log(ngx.ERR, err)
            return false
        end
    else
        if new_count > spider_conf['max'] then
            ngx.log(ngx.WARN, string.format("Current IP: %s, host: %s, judged as Spider, return 403.", ip, host))
            ngx.exit(ngx.HTTP_FORBIDDEN)
            return true
        end
    end

    return false
end


function _M:check_spider_by_ua()
    local spider_conf = self.spider_conf['ua_spider']
    if not spider_conf['enable'] then
        return false
    end

    local ua = ngx.var.http_user_agent
    if ua == nil or ua == "" then
        return false
    end

    local application = utils.get_application(true)
    local ua_rules = utils.load_rule(application, "useragent.rule")

    for _, rule in pairs(ua_rules) do
        if rule ~= "" and ngx.re.find(ua, rule, "isjo") then
            local host = ngx.var.host
            ngx.log(ngx.WARN, string.format("Current UserAgent: %s, host: %s, match UA rule: %s, judged as Spider", ua, host, rule))
            ngx.exit(ngx.HTTP_FORBIDDEN)
            return true
        end
    end

    return false
end


function _M:check_spider_by_referrer()
    local spider_conf = self.spider_conf['referrer_spider']
    if not spider_conf['enable'] then
        return false
    end

    local referrer = ngx.var.http_referer or "noreferer"
    local ip = utils.get_client_ip()
    local host = ngx.var.host
    local referrer_key = {
        referrer,
        ip,
        host,
    }

    local key = cjson.encode(referrer_key)
    local referrer_count, err = self.referrer_dict:incr(key, 1)
    if not referrer_count then
        if err == "not found" then
            self.referrer_dict:add(key, 1, spider_conf['exptime'])
            referrer_count = 1
        else
            ngx.log(ngx.ERR, err)
            return false
        end
    end

    if referrer_count > spider_conf['max'] then
        ngx.log(ngx.WARN, string.format("Current IP: %s, host: %s, referer: %s, judged as Spider, return 403", ip, host, referer))
        ngx.exit(ngx.HTTP_FORBIDDEN)
        return true
    end

    return false
end


function _M:check_spider_by_time_window()
    local spider_conf = self.spider_conf['time_window_spider']
    if not spider_conf['enable'] then
        return false
    end
    -- TODO
    return false
end


function _M:filter()
    if self:check_spider_by_ip() then
        return true
    end
    if self:check_spider_by_ua() then
        return true
    end
    if self:check_spider_by_referrer() then
        return true
    end
    return self:check_spider_by_time_window()
end


return _M
