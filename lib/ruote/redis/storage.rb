#--
# Copyright (c) 2005-2010, John Mettraux, jmettraux@gmail.com
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
# Made in Japan.
#++

require 'redis'
require 'rufus-json'
require 'ruote/storage/base'
require 'ruote/redis/version'


module Ruote
module Redis

  #
  # A Redis storage for ruote.
  #
  class RedisStorage

    include Ruote::StorageBase

    attr_reader :redis

    def initialize (redis, options={})

      @redis = redis
      @options = options

      put_configuration
    end

    def put (doc, opts={})

      rev = doc['_rev'].to_i
      key = key_for(doc)

      current_rev = redis.get(key).to_i

      return true if current_rev == 0 && rev > 0
      return do_get(doc, current_rev) if rev != current_rev

      nrev = rev + 1

      json = Rufus::Json.encode(
        doc.merge('_rev' => nrev, 'put_at' => Ruote.now_to_utc_s))

      r = redis.setnx(key_rev_for(doc, nrev), json)
      return true if r == 0

      redis.set(key, nrev)
      redis.del(key_rev_for(doc, rev))

      doc['_rev'] = nrev if opts[:update_rev]

      nil
    end

    def get (type, key)

      do_get(type, key, redis.get(key_for(type, key)))
    end

    def delete (doc)

      raise ArgumentError.new('no _rev for doc') unless doc['_rev']

      rev = doc['_rev'].to_i
      key = key_for(doc)

      current_rev = redis.get(key).to_i

      return true if rev != current_rev

      redis.del(key)
      redis.del(key_rev_for(doc, current_rev))

      # NOTE : redis returns 0 if none of the specified keys got deleted

      nil
    end

    def get_many (type, key=nil, opts={})

      keys = "#{type}/*"

      ids = redis.keys(keys).inject({}) { |h, k|

        if m = k.match(/^[^\/]+\/([^\/]+)\/(\d+)$/)

          if ( ! key) || m[1].match(key)

            o = h[m[1]]
            n = [ m[2].to_i, k ]
            h[m[1]] = [ m[2].to_i, k ] if ( ! o) || o.first < n.first
          end
        end

        h
      }.values

      if l = opts[:limit]
        ids = ids[0, l]
      end

      ids.collect { |i| i[1] }.collect do |i|
        Rufus::Json.decode(redis.get(i))
      end
    end

    def ids (type)

      redis.keys("#{type}/*").inject([]) { |a, k|

        if m = k.match(/^[^\/]+\/([^\/]+)$/)
          a << m[1]
        end

        a
      }
    end

    def purge!

      redis.keys('*').each { |k| redis.del(k) }
    end

    #def dump (type)
    #  @dbs[type].dump
    #end

    def shutdown
    end

    # Mainly used by ruote's test/unit/ut_17_storage.rb
    #
    def add_type (type)
    end

    # Nukes a db type and reputs it (losing all the documents that were in it).
    #
    def purge_type! (type)

      redis.keys("#{type}/*").each { |k| redis.del(k) }
    end

    protected

    #   key_for(doc)
    #   key_for(type, key)
    #
    def key_for (*args)

      a = args.first

      (a.is_a?(Hash) ? [ a['type'], a['_id'] ] : args[0, 2]).join('/')
    end

    #   key_rev_for(doc)
    #   key_rev_for(doc, rev)
    #   key_rev_for(type, key, rev)
    #
    def key_rev_for (*args)

      as = nil
      a = args.first

      if a.is_a?(Hash)
        as = [ a['type'], a['_id'], a['_rev'] ] if a.is_a?(Hash)
        as[2] = args[1] if args[1]
      else
        as = args[0, 3]
      end

      as.join('/')
    end

    def do_get (*args)

      d = redis.get(key_rev_for(*args))

      d ? Rufus::Json.decode(d) : nil
    end

    # Don't put configuration if it's already in
    #
    # (avoid storages from trashing configuration...)
    #
    def put_configuration

      return if get('configurations', 'engine')

      put({ '_id' => 'engine', 'type' => 'configurations' }.merge(@options))
    end
  end
end
end

