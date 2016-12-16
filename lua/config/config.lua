local _M = {}

_M.monitor_enable = true

_M.dev_setting_db_conf = {
     host     = "127.0.0.1",
     port     = 3306,
     database = "gateway",
     user     = "root",
     password = "chou1103",
}

_M.setting_db_conf = {
     host     = "10.33.1.132",
     port     = 3306,
     database = "gateway",
     user     = "admin",
     password = "gateway_0815",
}

_M.test_setting_db_conf = {
     host     = "127.0.0.1",
     port     = 3306,
     database = "gateway",
     user     = "admin",
     password = "gateway_0815",
}

return _M
