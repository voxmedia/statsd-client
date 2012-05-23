statsd-client
=============

A Ruby client for [StatsD](https://github.com/etsy/statsd), Etsy's daemon for easy stats aggregation.

Usage
-----
    require 'vox/statsd/client'
    
    Vox::Statsd.timing('example.stat.1', 350)
    
    records = Vox::Statsd.timing('example.stat.1') do
      get_some_records
    end
    
    Vox::Statsd.increment('example.stat.2')
    
    Vox::Statsd.decrement('example.stat.2')


