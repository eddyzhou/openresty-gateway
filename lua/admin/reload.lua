local db_setting = require "config.db_setting"
local ngx_shared = ngx.shared
local global_conf_dict = ngx_shared['global']


local function handle()
	ngx.log(ngx.WARN, "admin reload")
	db_setting.delete_mark_key()
	global_conf_dict:flush_all()

	ngx.status = ngx.HTTP_OK  
    ngx.say("reload success")
end

handle()

