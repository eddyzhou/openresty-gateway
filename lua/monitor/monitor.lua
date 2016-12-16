utils = require "utils.utils"

local Monitor = {}
Monitor.__index = Monitor
Monitor.initialized = false

local _M = setmetatable({}, Monitor)

function Monitor.init()
    if _M.initialized then
    	ngx.log(ngx.ERR, "Monitor module has been initialized")
    	return
    end

    prometheus = require("monitor.prometheus").init("prometheus_metrics")
    _M.metric_requests = prometheus:counter("nginx_requests_total", 
		"Number of HTTP requests", {"application", "status"})
    _M.metric_latency = prometheus:histogram("nginx_request_duration_millisecond", 
		"HTTP request latency", {"application"})
    _M.initialized = true
end

function Monitor:log_response()
    if not _M.initialized then
    	ngx.log(ngx.ERR, "Monitor module has not been initialized")
    	return
    end

    local app = utils.get_application(false)
    _M.metric_requests:inc(1, {app, ngx.var.status})
    _M.metric_latency:observe((ngx.now() - ngx.req.start_time())*1000, {app})
end

return _M
