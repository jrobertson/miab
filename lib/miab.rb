#!/usr/bin/env ruby

# file: miab.rb

# Desc: Message in a bottle (MIAB) is designed to execute remote commands 
#       through SSH for system maintenance purposes.

require 'net/ssh'
require 'c32'


class Miab
  using ColouredText

  def initialize(scroll, domain: nil, target: nil, pwlist: {}, password: nil, 
    user: nil, debug: false)

    @results = {}

    @scroll, @debug = scroll, debug

    @nodes = if target then

      target = [target] if target.is_a? String

      target.inject({}) do |r,x|
        host = domain ? x + '.' + domain : x
        passwd = pwlist[x] || password
        userhost = user ? user + '@' + host : host
        r.merge({userhost => passwd})
      end

    else
      {}
    end
  end

  def cast()

    if @nodes.any? then

      @nodes.each do |raw_host, password|

        host, user = raw_host.split(/@/,2).reverse
        @host = host
        @results[host] = {}

        @ssh = Net::SSH.start( host, user, password: password)
        eval @scroll
        @ssh.close
        
      end

    else
      @results[`hostname`.chomp] = {}
      eval @scroll if @scroll
    end

    @scroll = nil
    @results
  end

  def date()

    instructions = 'date'
    r = @ssh ? @ssh.exec!(instructions) : system(instructions)
    @results[@host][:date] = r.chomp

  end

  def disk_space()

    instructions = 'df -h'
    s = @ssh ? @ssh.exec!(instructions) : system(instructions)

    @results[@host][:disk_usage] = {}

    a = s.lines.grep(/\/dev\/root/)

    puts ('a: ' + a.inspect).debug if @debug

    if a.any? then
      size, used, avail = a[0].split(/ +/).values_at(1,2,3)

      @results[@host][:disk_usage][:root] = {size: size, used: used, 
        avail: avail}
    end

    a2 = s.lines.grep(/\/dev\/sda1/)

    puts ('a2: ' + a2.inspect).debug if @debug

    if a2.any? then
      size, used, avail = a2[0].split(/ +/).values_at(1,2,3)

      @results[@host][:disk_usage][:sda1] = {size: size, used: used, 
        avail: avail}
    end

  end

  alias df disk_space


  def pwd()
    instructions = 'pwd'
    r = @ssh ? @ssh.exec!(instructions) : system(instructions)
    @results[@host][:pwd] = r.chomp
  end

  def temperature()
    instructions = 'cat /sys/class/thermal/thermal_zone0/temp'
    r = @ssh ? @ssh.exec!(instructions) : system(instructions)
    @results[@host][:temperature] = r.chomp
  end

end
