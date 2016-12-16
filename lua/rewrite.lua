local cjson = require "cjson.safe"
local utils = require "utils.utils"
local application_config = "config.app_config_"
local ngx_shared = ngx.shared
local global_conf_dict = ngx_shared['global']


local function set_conf_to_ngx_shared()
    local application = utils.get_application(true)
    local mark = global_conf_dict:get(application .. "_mark") or 0
    if mark == 0 then
        ngx.log(ngx.INFO, "set conf to ngx shared for ", application)
    	local res, err = global_conf_dict:set(application .. "_mark", 1)
    	if not res then
            ngx.log(ngx.WARN, "set shared_dict failed. err: " .. err)
            return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    	end

        local config_path = application_config .. application
        local absolute_path = utils.lua_path
                              .. "/config/app_config_" .. application .. ".lua"
        ngx.log(ngx.DEBUG, "absolute_path:", absolute_path)
        if not utils.file_exists(absolute_path) then
            config_path = application_config .. "default"
        end
        ngx.log(ngx.DEBUG, "config_path:", config_path)
        local app_conf = require(config_path)

    	res, err = global_conf_dict:set(application .. "_conf", cjson.encode(app_conf.all_conf))
    	if not res then
            ngx.log(ngx.WARN, "set shared_dict failed. err: " .. err)
            return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    	end
    end
end

set_conf_to_ngx_shared()
