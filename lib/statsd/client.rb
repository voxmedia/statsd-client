# @author Tom Taylor
require 'socket'
require 'yaml'

class Statsd
  class << self 
    def increment(metric, options={})
      if options.is_a?(Fixnum)
        value = options
        sample_rate = 1
      else
        value = (options[:by] || 1)
        sample_rate = (options[:sample_rate] || 1)
      end
      client.update_stats(metric, value*factor, sample_rate)
    end
    alias_method :inc, :increment
  
    def decrement(metric, options={})
      if options.is_a?(Fixnum)
        value = options
        sample_rate = 1
      else
        value = (options[:by] || 1)
        sample_rate = (options[:sample_rate] || 1)
      end
      client.update_stats(metric, value*factor*(-1), sample_rate)
    end
    alias_method :dec, :decrement

    def timing(metric, value)
      client.timing(metric, value)
    end
    alias_method :time, :timing
    
    def client
      return Statsd::DummyClient if deactivated?
      @client ||= Statsd::Client.new(host, port, tcp?)
    end
  
    def config
      home = File.expand_path('~')
      files = ["#{home}/.statsd-client.yml", '/etc/statsd-client.yml']
      files.each do |file|
        return YAML.load(File.read(file)) if File.exist?(file)
      end
      raise "No config found: #{files.join(' or ')}"
    end
  
    def host
      config['host'] || 'localhost'
    end
  
    def port
      config['port'] || 8125
    end

    def tcp?
      config['tcp']
    end
  
    # statds reports with default configs 1/10 of actual value
    def factor
      config['factor'] || 1
    end
  
    def deactivated?
      config['deactivated'] || false
    end
  end
  
  class DummyClient
    def self.timing(*args)
    end
    
    def self.update_stats(*args)
    end
  end
  
  
  class Client
    VERSION = File.read( File.join(File.dirname(__FILE__),'..', '..', 'VERSION') ).strip
    attr_reader :host, :port, :tcp

    # Initializes a Statsd client.
    #
    # @param [String] host
    # @param [Integer] port
    # @param [Boolean] tcp
    def initialize(host = 'localhost', port = 8125, tcp = false,namespace='')
      @host, @port, @tcp,@namespace = host, port, tcp, namespace
    end

    # Sends timing statistics.
    #
    # @param [Array, String] stats name of statistic(s) being updated
    # @param [Integer] time in miliseconds
    # @param [Integer, Float] sample_rate
    def timing(stats, time, sample_rate = 1)
      data = "#{time}|ms"
      update_stats(stats, data, sample_rate)
    end

    # Increments a counter
    #
    # @param [Array, String] stats name of statistic(s) being updated
    # @param [Integer, Float] sample_rate
    def increment(stats, sample_rate = 1)
      update_stats(stats, 1, sample_rate)
    end

    # Decrements a counter
    #
    # @param [Array, String] stats name of statistic(s) being updated
    # @param [Integer, Float] sample_rate
    def decrement(stats, sample_rate = 1)
      update_stats(stats, -1, sample_rate)
    end

    # Updates one or more counters by an arbitrary amount
    #
    # @param [Array, String] stats name of statistic(s) being updated
    # @param [Integer, Float] delta
    # @param [Integer, Float] sample_rate
    def update_stats(stats, delta = 1, sample_rate = 1)
      stats = [stats] unless stats.kind_of?(Array)

      data = {}

      delta = delta.to_s
      stats.each do |stat|
        # if it's got a |ms in it, we know it's a timing stat, so don't append
        # the |c.
        data[prefix(stat)] = delta.include?('|ms') ? delta : "#{delta}|c"
      end

      send(data, sample_rate)
    end

    private

    def prefix(stats) 
      "#{@namespace}.#{stats}"
    end

    def send(data, sample_rate = 1)
      #puts "sending #{data} with sample #{sample_rate}"
      sampled_data = {}
      
      if sample_rate < 1
        if Kernel.rand <= sample_rate
          data.each do |k,v|
            sampled_data[k] = "#{v}|@#{sample_rate}"
          end
        end
      else
        sampled_data = data
      end

      if self.tcp
        socket = TCPSocket.new( self.host, self.port)
      else
        socket = UDPSocket.new
      end
      
      begin
        sampled_data.each do |k,v|
          message = [k,v].join(':')
          if self.tcp
            socket.send(message, 0)
          else
            socket.send(message, 0, self.host, self.port)            
          end
        end
      rescue Exception => e
        puts "Unexpected error: #{e}"
      ensure
        socket.close
      end
    end

  end
end
