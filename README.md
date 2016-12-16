# openresty-gateway


### Features

- 非法请求过滤(利用签名校验过滤山寨客户端等非法请求)
- 反爬虫
- 流量控制(过载保护)
- WAF(防止 SQL 注入, XSS, SSRF 等 web 攻击)
- 实时统计
- 监控

### Prerequisites

- LuaJIT 2.0+
- ngx_lua module

### Usage

nginx 配置见 nginx.conf

### 签名鉴权

Gateway 可以配置具体某个 Application 是否需要签名鉴权，若不需要，无需做任何修改。

- 在每个请求的 url query string 需要带上参数： **timestamp**(时间戳，Int 类型) 和 **nonce**(随机数，String 类型) 
- 所有请求使用同样的算法来生成(signature base string)签名字符基串和签名
- base string由http方法名，之后是&，接着是过url编码(url-encoded)之后的url和访问路径及&。接下来，把所有的请求参数包括POST方法体中的参数(Content-Type 为 application/x-www-form-urlencoded)，经过排序(按参数名进行文本排序，如果参数名有重复则再安参数值进行重复项目排序)，使用%3D替代=号，并且使用%26作为每个参数之间的分隔符，拼接成一个字符串

    这个算法可以简单表示为

	```
	httpMethod + "&" +
   url_encode( base_uri ) + "&" +
   sorted_query_params.each  { | k, v |
       url_encode ( k ) + "%3D" +
       url_encode ( v )
   }.join("%26")
	```
- 如果是 POST 方法，且 Content-Type 不为 application/x-www-form-urlencoded (如：application/json)，将请求的 body 内容作为一个字符串，拼接到 base string，用%26作为原 base string 和 body 的分隔符
- 接入签名鉴权的 Application 由 Gateway 分配 **secret_key** (没有分配将使用全局默认 **secret_key**) 
- 所有请求都使用HMAC-SHA1算法生成签名
- 在每个请求的 url query string 附加 **sig** 参数
