
#
# testing ruote-redis
#
# Thu Apr  1 21:35:07 JST 2010
#

require 'yajl' rescue require 'json'
require 'rufus-json'
Rufus::Json.detect_backend

require 'ruote-redis'


def new_storage (opts)

  Ruote::Redis::RedisStorage.new(
    ::Redis.new(:db => 14, :thread_safe => true),
    opts)
end

