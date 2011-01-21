
#
# testing ruote-redis
#
# Thu Apr  1 21:35:07 JST 2010
#

require 'yajl' rescue require 'json'
require 'rufus-json'
Rufus::Json.detect_backend

require 'redis'
require 'ruote-redis'


class RrLogger
  def method_missing (m, *args)
    super if args.length != 1
    puts ". #{Time.now.to_f} #{Thread.current.object_id} #{args.first}"
  end
end


def new_storage (opts)

  Ruote::Redis::Storage.new(
    ::Redis.new(:db => 14, :thread_safe => true),
    #::Redis.new(:db => 14, :thread_safe => true, :logger => RrLogger.new),
    opts)
end

