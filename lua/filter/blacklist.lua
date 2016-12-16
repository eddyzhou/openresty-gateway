local utils = require "utils.utils"
local iputils = require "utils.ip"


local _M = {
    _VERSION = '0.0.1'
}

local mt = {
    __index = _M
}


function _M:new()
    local self = {}
    return setmetatable(self, mt)
end


function _M:filter()
    local application = utils.get_application(true)
    local ips = utils.load_rule(application, "blacklist.rule")
    if table.getn(ips) == 0 then
        return false
    end

    local blacklist = iputils.parse_cidrs(ips)
    local ip = utils.get_client_ip()
    if iputils.ip_in_cidrs(ip, blacklist) then
        ngx.log(ngx.WARN, "Current IP: " .. ip .. " in blacklist, forbidden!")
        ngx.exit(ngx.HTTP_FORBIDDEN)
        return true
    end

    return false
end


return _M
