local limit_conn = require "limit.conn"
local limit_req = require "limit.req"
local limit_traffic = require "limit.traffic"
local utils = require "utils.utils"


local _M = {
    _VERSION = '0.0.1'
}

local mt = {
    __index = _M
}


function _M:new(req_dict_name, conn_dict_name, traffic_conf)
    local self = {
    	req_dict_name = req_dict_name,
    	conn_dict_name = conn_dict_name, 
        traffic_conf = traffic_conf,
    }

    return setmetatable(self, mt)
end


function _M:traffic_limit()
    local lim_app, err = limit_req.new(self.req_dict_name, self.traffic_conf['req_app_max'], self.traffic_conf['req_app_burst'])
    local lim_ip, err = limit_req.new(self.req_dict_name, self.traffic_conf['req_ip_max'], self.traffic_conf['req_ip_burst'])
    local lim_conn, err = limit_conn.new(self.conn_dict_name, self.traffic_conf['conn_ip_max'], self.traffic_conf['conn_ip_burst'], 0.5)

    local limiters = {lim_app, lim_ip, lim_conn}

    local ip = utils.get_client_ip()
    local app = utils.get_application(true)
    local key = ip .. app
    local keys = {app, key, app}

    local states = {}

    local delay, err = limit_traffic.combine(limiters, keys, states)
    if not delay then
        if err == "rejected" then
            ngx.log(ngx.ERR, "Current req over the request limit. app: ", app)
            return ngx.exit(ngx.HTTP_SERVICE_UNAVAILABLE)
        end
        ngx.log(ngx.ERR, "Failed to limit traffic: ", err)
        return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end

    if lim_conn:is_committed() then
        local ctx = ngx.ctx
        ctx.limit_conn = lim_conn
        ctx.limit_conn_key = keys[3]
    end

    if delay > 0 then
        ngx.sleep(delay)
    end
end


return _M
