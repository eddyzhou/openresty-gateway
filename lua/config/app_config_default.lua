
local blacklist_enable = false

local whitelist_enable = false

local waf_conf = {
    enable        = true,
    url_enable    = true,
    cookie_enable = true,
    get_enable    = true,
    post_enable   = true,
}

local spider_conf = {
    enable = false,
    ip_spider = {
        enable  = true,
        max     = 200,
        exptime = 10,
    },
    ua_spider = {
        enable = true,
    },
    referrer_spider = {
        enable  = true,
        max     = 100,
        exptime = 10,
    },
    time_window_spider = {
        enable = false,
    },
}

local traffic_conf = {
    enable        = false,
    req_ip_max    = 5000,
    req_ip_burst  = 2000,
    req_app_max   = 30000,
    req_app_burst = 10000,
    conn_ip_max   = 50000,
    conn_ip_burst = 20000,
}

local sig_conf = {
    enable     = true,
    --secret_key = "hey~m.xunlei!",
}


local _M = {}

_M.all_conf = {
    ['blacklist_enable'] = blacklist_enable,
    ['whitelist_enable'] = whitelist_enable,
    ['sig_conf']         = sig_conf,
    ['waf_conf']         = waf_conf,
    ['spider_conf']      = spider_conf,
    ['traffic_conf']     = traffic_conf,
}

return _M
