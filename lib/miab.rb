#!/usr/bin/env ruby

# file: miab.rb

# Desc: Message in a bottle (MIAB) is designed to execute remote commands 
#       through SSH for system maintenance purposes.

require 'net/ssh'
require 'c32'
require 'resolve/hostname'


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

  # cast out the thing and hope for the best
  #
  def cast()

    if @nodes.any? then

      @nodes.each do |raw_host, password|

        host, user = raw_host.split(/@/,2).reverse
        @host = host
        @results[host] = {}
        
        begin
          @ssh = Net::SSH.start( host, user, password: password)
          eval @scroll
          @ssh.close
        rescue
          @results[host] = nil
        end
        
      end

    else
      @results[`hostname`.chomp] = {}
      eval @scroll if @scroll
    end

    @scroll = nil
    @results
  end

  # return the local date and time
  #
  def date()

    instructions = 'date'
    r = @ssh ? @ssh.exec!(instructions) : system(instructions)
    @results[@host][:date] = r.chomp

  end

  # query the available disk space etc.
  #
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

  # find out available memory etc
  #
  def memory()

    instructions = 'free -h'

    puts ('instructions: ' + instructions.inspect).debug if @debug
    r = @ssh ? @ssh.exec!(instructions) : system(instructions)
    puts ('memory: ' + r.inspect).debug if @debug
    a = r.lines
    total, used, avail = a[1].split.values_at(1,2,-1)    
    @results[@host][:memory] = {total: total, used: used, available: avail}

  end
  
  # query the ping time
  #
  def ping()

    resolver = Resolve::Hostname.new
    ip = resolver.getaddress(@host)
    puts ('ip: ' + ip.inspect).debug if @debug
    valid = pingecho(ip)
    puts ('valid: ' + valid.inspect).debug if @debug    
    
    @results[@host][:ping] = if valid then
      a = [valid]
      4.times {sleep 0.01; a << pingecho(ip)}
      (a.min * 1000).round(3)
    else
      nil
    end

  end

  # query the path of the current working directory
  #
  def pwd()
    instructions = 'pwd'
    r = @ssh ? @ssh.exec!(instructions) : system(instructions)
    @results[@host][:pwd] = r.chomp
  end

  # query the CPU temperature
  #
  def temperature()
    instructions = 'cat /sys/class/thermal/thermal_zone0/temp'
    r = @ssh ? @ssh.exec!(instructions) : system(instructions)
    @results[@host][:temperature] = r.chomp
  end
  
  private
  
  
  def pingecho(host, timeout=5, service="echo")

    elapsed = nil
    time = Time.new

    begin

      Timeout.timeout(timeout) do
        s = TCPSocket.new(host, service)
        s.close
      end

    rescue Errno::ECONNREFUSED
      return Time.now - time
    rescue Timeout::Error, StandardError
      return false
    end
    
    # it should not reach this far
    return true
  end  

end
