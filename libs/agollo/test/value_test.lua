local value = require "libs.agollo.value"

local v = value.new("-344.990")
print(v:Int())

local v = value.new("false")
print(v:String())