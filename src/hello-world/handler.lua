local BasePlugin = require "kong.plugins.base_plugin"
local HelloWorldHandler = BasePlugin:extend()
    
HelloWorldHandler.PRIORITY = 2000
    
function HelloWorldHandler:new()
  HelloWorldHandler.super.new(self, "hello-world")
end
    
function HelloWorldHandler:access(conf)
  HelloWorldHandler.super.access(self)
    
  if conf.say_hello then
    kong.log.debug(ngx.ERR, "############ Hello World! ############")
    ngx.header["X-Hello-World"] = "Hello World!!!"
  else
    kong.log.debug(ngx.ERR, "############ Bye World! ############")
    ngx.header["X-Hello-World"] = "Bye World!!!"
  end
    
end
    
return HelloWorldHandler
