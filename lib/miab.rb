#!/usr/bin/env ruby

# file: miab.rb

# Desc: Message in a bottle (MIAB) is designed to execute remote commands 
#       through SSH for system maintenance purposes.
#
#       Note: Intended for a Debian based distro

require 'net/ssh'
require 'c32'
require 'resolv'


# available commands:
#
# * date - returns the system date and time
# * directory_exists? - returns true if the directory exists
# * disk_space - returns the available disk space
# * echo - returns whatever string is passed in
# * file_exists? - returns true if the file exists
# * file_write - writes contents to a file
# * installable? - returns true if the package name exists in apt-cache search
# * installed? - returns true if a package is already installed
# * internet? - returns true if a ping request to an external IP address succeeds
# * memory - returns the amount of free RAM available etc
# * ping - returns the latency of a ping request to the node
# * pwd - returns the working directory
# * temperature - returns the temperature of the CPU

# usage: puts Miab.new("temperature", domain: 'home', target: 'angelo', 
#                       user: 'pi', password: 'secret').cast
# nearest SSH equivalent `ssh pi@angelo.home exec \
#                                 "cat /sys/class/thermal/thermal_zone0/temp"`

class Miab
  using ColouredText
  
  class Session
    
    def initialize( host, ssh=nil, debug: false, dns: '1.1.1.1')
      
      @ssh, @host, @debug, @dns = ssh, host, debug, dns
      
      puts 'Session dns: ' + dns.inspect if @debug
      @results = {}
    end
    
    def exec(s)
      eval s
      @results
    end
    
    protected
    
    # return the local date and time
    #
    def date()

      instructions = 'date'
      r = @ssh ? @ssh.exec!(instructions) : `#{instructions}`
      puts 'r: ' + r.inspect if @debug
      @results[:date] = r.chomp

    end
    
    def directory_exists?(file)
      
      instructions = "test -d #{file}; echo $?"
      r = @ssh ? @ssh.exec!(instructions) : `#{instructions}`
      puts 'r: ' + r.inspect if @debug
      
      @results[:directory_exists?] = r.chomp == '0'

    end
    
    alias dir_exists? directory_exists?

    # query the available disk space etc.
    #
    def disk_space()

      instructions = 'df -h'
      r = @ssh ? @ssh.exec!(instructions) : `#{instructions}`

      @results[:disk_usage] = {}

      a = r.lines.grep(/\/dev\/root/)

      puts ('a: ' + a.inspect).debug if @debug

      if a.any? then
        size, used, avail = a[0].split(/ +/).values_at(1,2,3)

        @results[:disk_usage][:root] = {size: size, used: used, 
          avail: avail}
      end

      a2 = r.lines.grep(/\/dev\/sda1/)

      puts ('a2: ' + a2.inspect).debug if @debug

      if a2.any? then
        size, used, avail = a2[0].split(/ +/).values_at(1,2,3)

        @results[:disk_usage][:sda1] = {size: size, used: used, 
          avail: avail}
      end

    end

    alias df disk_space
    
    # return the string supplied
    #
    def echo(s)

      instructions = 'echo ' + s
      r = @ssh ? @ssh.exec!(instructions) : `#{instructions}`
      puts 'r: ' + r.inspect if @debug
      @results[:echo] = r.chomp

    end
    
    def file_exists?(file)
      
      instructions = "test -f #{file}; echo $?"
      r = @ssh ? @ssh.exec!(instructions) : `#{instructions}`
      puts 'r: ' + r.inspect if @debug
      
      @results[:file_exists?] = r == 0 

    end     
    
    # e.g. file_write 'desc.txt', 'Controls the door entry system.'
    #
    def file_write(file, content)
      
      instructions = "echo #{content.inspect} >> #{file}"
      r = @ssh ? @ssh.exec!(instructions) : `#{instructions}`
      puts 'r: ' + r.inspect if @debug
      
      @results[:file_write] = r

    end        
    
    # return the string supplied
    #
    def install(package)

      return @results[:install] = 'no route to internet' unless internet?
      return @results[:install] = 'already installed' if installed? package
      
      instructions = "apt-get update && apt-get install  #{package} -y"
      r = @ssh ? @ssh.exec!(instructions) : `#{instructions}`
      puts 'r: ' + r.inspect if @debug
      @results[:install] = r.chomp

    end    
    
    def installable?(package)
      
      instructions = "apt-cache search --names-only ^#{package}$"
      results = @ssh ? @ssh.exec!(instructions) : `#{instructions}`
      puts 'results: ' + results.inspect if @debug
      
      @results[:installable?] = !results.empty? 

    end    
    
    def installed?(package)
      
      instructions = 'dpkg --get-selections | grep -i ' + package
      results = @ssh ? @ssh.exec!(instructions) : `#{instructions}`
      puts 'results: ' + results.inspect if @debug
      
      return @results[:installed?] = nil if results.empty?
      r = results.lines.grep /^#{package}/
      
      @results[:installed?] = r.any?
    end

    def internet?()
      
      instructions = "ping #{@dns} -W 1 -c 1"
      r = @ssh ? @ssh.exec!(instructions) : `#{instructions}`
      puts 'r: ' + r.inspect if @debug
      
      @results[:internet?] = r.lines[1][/icmp_seq/] ? true : false

    end    

    # find out available memory etc
    #
    def memory()

      instructions = 'free -h'

      puts ('instructions: ' + instructions.inspect).debug if @debug
      r = @ssh ? @ssh.exec!(instructions) : `#{instructions}`
      puts ('memory: ' + r.inspect).debug if @debug
      a = r.lines
      total, used, avail = a[1].split.values_at(1,2,-1)    
      @results[:memory] = {total: total, used: used, available: avail}

    end
    
    # query the ping time
    #
    def ping()

      ip = Resolv.getaddress(@host)
      puts ('ip: ' + ip.inspect).debug if @debug
      valid = pingecho(ip)
      puts ('valid: ' + valid.inspect).debug if @debug    
      
      @results[:ping] = if valid then
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
      r = @ssh ? @ssh.exec!(instructions) : `#{instructions}`
      @results[:pwd] = r.chomp
    end

    # query the CPU temperature
    #
    def temperature()
      instructions = 'cat /sys/class/thermal/thermal_zone0/temp'
      r = @ssh ? @ssh.exec!(instructions) : `#{instructions}`
      @results[:temperature] = r.chomp
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

  def initialize(scroll, domain: nil, target: nil, pwlist: {}, password: nil, 
    user: nil, debug: false, dns: '208.67.222.222')

    @results = {}

    @scroll, @debug, @dns = scroll, debug, dns
    
    puts '@dns: ' + @dns.inspect if @debug

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
      
      threads = []
      dns = @dns

      @nodes.each do |raw_host, password|
        
        host, user = raw_host.split(/@/,2).reverse
        @results[host] = {}
        
        threads << Thread.new do
          begin
            puts ('host: ' + host.inspect).debug if @debug
            ssh = Net::SSH.start( host, user, password: password)
            @results[host] = Session.new(host, ssh, dns: dns, debug: @debug).exec @scroll
            ssh.close
            puts (host + ' result: ' + @results[host].inspect).debug if @debug
          rescue
            @results[host] = nil
          end
        end
        
      end      

      threads.each(&:join)

    else
      
      if @scroll then
        host = `hostname`.chomp
        @results[host] = Session.new(host, dns: @dns, debug: @debug).exec(@scroll)
      end
      
    end

    @scroll = nil
    @results
  end

end
