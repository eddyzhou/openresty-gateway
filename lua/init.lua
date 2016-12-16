local config = require "config.config"
local db_setting = require "config.db_setting"
local monitor = require "monitor.monitor"
local ngx_shared = ngx.shared
local global_conf_dict = ngx_shared['global']


local function init()
    db_setting.delete_mark_key()
    global_conf_dict:flush_all()

    if config.monitor_enable then
    	monitor.init()
    end
end

init()

