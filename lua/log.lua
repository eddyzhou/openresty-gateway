local monitor = require "monitor.monitor"
local config = require "config.config"


local function conn_leaving()
    local ctx = ngx.ctx
    local lim = ctx.limit_conn
    if lim then
        local latency = tonumber(ngx.var.request_time)
        local key = ctx.limit_conn_key
        if not key then
        	return
        end
        local conn, err = lim:leaving(key, latency)
        if not conn then
            ngx.log(ngx.ERR, "failed to record the connection leaving ", "err: ", err)
            return
        end
    end
end


local function log()
    conn_leaving()
    if config.monitor_enable then
        monitor:log_response()
    end
end

log()
