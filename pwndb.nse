author = "Dr Claw"
license = "Same as Nmap--See https://nmap.org/book/man-legal.html"
categories = {"discovery"}

description = [[
  Find leaked creds using pwndb or scylla.
]]

--
-- @output
-- X creds found:
-- email:password//hash
-- email:password//hash
--
-- No creds found
--

local nmap = require "nmap"
local shortport = require "shortport"
local stdnse = require "stdnse"
local string = require "string"

function check(v)
    return string.match(v, '^[%d%a_.]+$') ~= nil and
           string.sub(v, 0, 1) ~= '.' and
           string.sub(v, -1) ~= '.' and
           string.find(v, '%.%.') == nil
end

function fsize (file)
        local current = file:seek()
        local size = file:seek("end")
        file:seek("set", current)
        return size
end

hostrule = function(host)
    if host.targetname  then
      if check(host.targetname) then
          return true
      end
    else
        return false
    end
end

  
action = function(host)
   local scylla = stdnse.get_script_args("pwndb.scylla")
   if scylla then
      scylla = " -S"
   else
      scylla = ""
   end
   local filename = host.targetname .. ".PASS.TXT"
   local cmd = "pwndb" .. scylla .." -E -o " .. filename .. " -d " .. host.targetname  
   output = "\n" .. io.popen(cmd, "r"):read("*a")
   local file = io.open(filename, "rb")
   if not file then
     content = "No creds found"
     return content
   end
   local content = file:read "*a"
   file:close()
   local _, count = content:gsub('\n', '\n')
   os.remove(filename)
   return count .. " creds found:\n" .. content .. "\n"
end
