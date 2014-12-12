# Copyright
# =========
# Copyright (C) 2012 Trustwave Holdings, Inc.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>
#
#
# writeConfig.rb by Josh Grunzweig 9-30-2012
#
# =Synopsis
#
# This is a simple Ruby script that is designed to write a new APK file based 
# on the configuration supplied. Must supply a valid FinSpy Android sample as
# the first argument.
#
# The new file is written as <supplied_file>_new. This of course can be changed
# in the subsequent code. Simply modify the 'new_file' variable.
#
# Example: ruby writeConfig.rb finSpy.apk config.dat
#
# Produces finSpy.apk_new in the same directory as finSpy.apk
#
# Side Note: Not the cleanest code, I admit. However, it reliably works and 
# does the job.

require 'base64'

file = ARGV.shift
config = ARGV.shift

unless file && config
  puts "Usage: writeConfig.rb <finspy_sample> <config>"
  exit
end

new_file = file.chomp+"_new"

fil = File.open(file, "rb")
f = fil.read
f2 = f.dup

conf = File.open(config, "rb")
c = conf.read

nfile = File.open(new_file, "wb")
orig_config = ""

f.scan(/PK\x01\x02.{32}(.{6})(.{4}assets\/Configurations\/dumms\d+\.dat)/m).each do |x| 
  orig_config << x[0].to_s
end

orig_config.gsub!("\u0000",'')

new_config = Base64.encode64(c.chomp)
new_chomped = new_config.scan(/..?.?.?.?.?/m)

count = 0
f.scan(/PK\x01\x02.{32}((.{6})(.{4}assets\/Configurations\/dumms\d+\.dat))/m) do |x| 
  offset = Regexp.last_match.offset(0)[0]
  range = new_chomped[count]
  if !range.nil?
    if range.size < 6
      range = range + ("\x00"*(6-range.size))
    end
    f2[offset+36..offset+41] = range
  end
  count+=1
end

nfile.write(f2)
[nfile, fil, conf].each{|x| x.close}
puts "Done. #{new_file} written."

