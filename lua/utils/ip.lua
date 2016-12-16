local bit      = require("bit")
local tobit    = bit.tobit
local lshift   = bit.lshift
local band     = bit.band
local bor      = bit.bor
local xor      = bit.bxor
local byte     = string.byte
local str_find = string.find
local str_sub  = string.sub

-- local lrucache = require("resty.lrucache").new(4000)


local bin_masks = {}
for i = 1, 32 do
    bin_masks[tostring(i)] = lshift(tobit((2^i)-1), 32-i)
end

local bin_inverted_masks = {}
for i = 1, 32 do
    local i = tostring(i)
    bin_inverted_masks[i] = xor(bin_masks[i], bin_masks["32"])
end


local function split_octets(input)
    local pos = 0
    local prev = 0
    local octs = {}

    for i = 1, 4 do
        pos = str_find(input, ".", prev, true)
        if pos then
            if i == 4 then
                local err = "Invalid IP: " .. input
                ngx.log(ngx.ERR, err)
                return nil, err
            end
            octs[i] = str_sub(input, prev, pos-1)
        elseif i == 4 then
            octs[i] = str_sub(input, prev, -1)
            break
        else
            local err = "Invalid IP: " .. input
            ngx.log(ngx.ERR, err)
            return nil, err
        end
        prev = pos + 1
    end

    return octs
end


local function ip2bin(ip)
    --local v = lrucache:get(ip)
    --if v then
    --    return v[1], v[2]
    --end

    if type(ip) ~= "string" then
        local err = "IP must be a string: " .. input
        ngx.log(ngx.ERR, err)
        return nil, err
    end

    local octets = split_octets(ip)
    if not octets or #octets ~= 4 then
        local err = "Invalid ip: " .. input
        ngx.log(ngx.ERR, err)
        return nil, err
    end

    local bin_octets = {}
    local bin_ip = 0

    for i,octet in ipairs(octets) do
        local bin_octet = tonumber(octet)
        if not bin_octet or bin_octet > 255 then
            local err = "Invalid octet: " .. tostring(octet)
            ngx.log(ngx.ERR, err)
            return nil, err
        end
        bin_octet = tobit(bin_octet)
        bin_octets[i] = bin_octet
        bin_ip = bor(lshift(bin_octet, 8*(4-i) ), bin_ip)
    end

    --lrucache:set(ip, {bin_ip, bin_octets})
    return bin_ip, bin_octets
end


local function split_cidr(input)
    local pos = str_find(input, "/", 0, true)
    if not pos then
        return {input}
    end
    return {str_sub(input, 1, pos-1), str_sub(input, pos+1, -1)}
end


local function parse_cidr(cidr)
    local mask_split = split_cidr(cidr, '/')
    local net        = mask_split[1]
    local mask       = mask_split[2] or "32"
    local mask_num   = tonumber(mask)
    if not mask_num or (mask_num > 32 or mask_num < 1) then
        local err = "Invalid prefix: /"..tostring(mask)
        ngx.log(ngx.ERR, err)
        return nil, err
    end

    local bin_net, err = ip2bin(net) -- convert IP to binary
    if not bin_net then
        return nil, err
    end
    local bin_mask     = bin_masks[mask] -- get masks
    local bin_inv_mask = bin_inverted_masks[mask]

    local lower = band(bin_net, bin_mask) -- network address
    local upper = bor(lower, bin_inv_mask) -- broadcast address
    return lower, upper
end


local function parse_cidrs(cidrs)
    local out = {}
    local i = 1
    for _, cidr in ipairs(cidrs) do
        local lower, upper = parse_cidr(cidr)
        if not lower then
            ngx.log(ngx.Err, "Error parsing '" .. cidr .. "': " .. upper)
        else
            out[i] = {lower, upper}
            i = i + 1
        end
    end
    return out
end


local function ip_in_cidrs(ip, cidrs)
    local bin_ip, bin_octets = ip2bin(ip)
    if not bin_ip then
        return false
    end

    for _, cidr in ipairs(cidrs) do
        if bin_ip >= cidr[1] and bin_ip <= cidr[2] then
            return true
        end
    end
    return false
end


local function binip_in_cidrs(bin_ip_ngx, cidrs)
    if 4 ~= #bin_ip_ngx then
        return false
    end

    local bin_ip = 0
    for i = 1, 4 do
        bin_ip = bor(lshift(bin_ip, 8), tobit(byte(bin_ip_ngx, i)))
    end

    for _, cidr in ipairs(cidrs) do
        if bin_ip >= cidr[1] and bin_ip <= cidr[2] then
            return true
        end
    end
    return false
end


local _M = {
    _VERSION = '0.0.1',
}

local mt = { __index = _M }

_M.ip2bin = ip2bin
_M.parse_cidr = parse_cidr
_M.parse_cidrs = parse_cidrs
_M.ip_in_cidrs = ip_in_cidrs
_M.binip_in_cidrs = binip_in_cidrs

return _M
