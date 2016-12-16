local utils = require "utils.utils"
local cjson = require "cjson.safe"
local whitelist_module = require "filter.whitelist"
local blacklist_module = require "filter.blacklist"
local waf_module = require "filter.waf"
local antispider_module = require "filter.antispider"
local traffic_module = require "filter.traffic"
local sig_module = require "filter.sig"
local ngx_shared = ngx.shared
local global_conf_dict = ngx_shared['global']

function load_app_conf()
    local application = utils.get_application(true)
    local app_conf, err = global_conf_dict:get(application .. "_conf")
    if not app_conf then
        ngx.log(ngx.WARN, string.format("get config of %s failed. err: %s", application, err))
        return nil
    end
    app_conf = cjson.decode(app_conf)
    return app_conf
end


local function filter()
    if ngx.req.is_internal() then 
        return
    end
    
    local app_conf = load_app_conf()
    if not app_conf then
        return
    end
	
    local whitelist_enable = app_conf['whitelist_enable']
    local blacklist_enable = app_conf['blacklist_enable']
    local sig_enable = app_conf['sig_conf']['enable']
    local waf_enable = app_conf['waf_conf']['enable']
    local spider_enable = app_conf['spider_conf']['enable']
    local traffic_enable = app_conf['traffic_conf']['enable']

    if whitelist_enable then 
        local whitelist = whitelist_module:new()
        if whitelist:filter() then
            return
        end
    end

    if blacklist_enable then
        local blacklist = blacklist_module:new()
        if blacklist:filter() then
            return
        end
    end

    if sig_enable then
        local sig = sig_module:new(app_conf['sig_conf'])
        if sig:filter() then
            return
        end 
    end

    if waf_enable then
        local waf = waf_module:new(app_conf['waf_conf'])
        if waf:WAF() then
            return
        end
    end

    if spider_enable then
        local spider = antispider_module:new("ip_spider", "referrer_spider", "time_window_spider", app_conf['spider_conf'])
        if spider:filter() then
            return
        end
    end

    if traffic_enable then
        local traffic = traffic_module:new("req_store", "conn_store", app_conf['traffic_conf'])
        traffic:traffic_limit()
    end

end


filter()

