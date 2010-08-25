#--
# Copyright(c) 2005-2010, John Mettraux, jmettraux@gmail.com
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files(the "Software"), to deal
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

#require 'redis'
  # now letting the end-user doing this require

require 'rufus-json'
require 'ruote/storage/base'
require 'ruote/redis/version'


module Ruote
module Redis

  #
  # A Redis storage for ruote.
  #
  # The constructor accepts two arguments, the first one is a Redis instance
  #( see http://github.com/ezmobius/redis-rb ), the second one is the classic
  # ruote engine options( see
  # http://ruote.rubyforge.org/configuration.html#engine )
  #
  #   require 'redis' # gem install redis
  #   require 'ruote' # gem install ruote
  #   require 'ruote-redis' # gem install ruote-redis
  #
  #   engine = Ruote::Engine.new(
  #     Ruote::Worker.new(
  #       Ruote::Redis::RedisStorage.new(
  #         ::Redis.new(:db => 14, :thread_safe => true), {})))
  #
  #
  # == em-redis
  #
  # Not tried, but I guess, that substituting an instance of em-redis for
  # the redis instance passed to the constructor might work.
  # http://github.com/madsimian/em-redis
  #
  # If you try and it works, feedback is welcome
  # http://groups.google.com/group/openwferu-users
  #
  class RedisStorage

    include Ruote::StorageBase

    attr_reader :redis

    # A Redis storage for ruote.
    #
    def initialize(redis, options={})

      @redis = redis
      @options = options

      def @redis.keys_to_a(opt)
        r = keys(opt)
        r.is_a?(Array) ? r : r.split(' ')
      end

      put_configuration
    end

    def reserve(doc)

      @redis.del(key_for(doc))
    end

    def put_msg(action, options)

      doc = prepare_msg_doc(action, options)

      @redis.set(key_for(doc), to_json(doc))

      nil
    end

    def put_schedule(flavour, owner_fei, s, msg)

      doc = prepare_schedule_doc(flavour, owner_fei, s, msg)

      return nil unless doc

      @redis.set(key_for(doc), to_json(doc))

      doc['_id']
    end

    def delete_schedule(schedule_id)

      @redis.del(key_for('schedules', schedule_id))
    end

    # 'msgs' and 'schedules'
    #
    MAS = %w[ msgs schedules ]

    def put(doc, opts={})

      if MAS.include?(doc['type'])
        #
        # msgs and schedules are only put here in case of 'copy'
        # they are a special case though
        #
        @redis.set(key_for(doc), to_json(doc))
        return nil
      end

      # regular put

      key = key_for(doc)
      rev = doc['_rev']

      lock(key) do

        current_doc = do_get(key)
        current_rev = current_doc ? current_doc['_rev'] : nil

        if current_rev && rev != current_rev
          #
          # version in storage is newer than version being put,
          # (eturn version in storage)
          #
          current_doc

        elsif rev && current_rev.nil?
          #
          # document deleted, put fails (return true)
          #
          true

        else
          #
          # put is successful (return nil)
          #
          nrev = (rev.to_i + 1).to_s
          @redis.set(key, to_json(doc.merge('_rev' => nrev)))
          doc['_rev'] = nrev if opts[:update_rev]

          nil
        end
      end
    end

    def get(type, key)

      do_get(key_for(type, key))
    end

    def delete(doc)

      rev = doc['_rev']

      raise ArgumentError.new("can't delete doc without _rev") unless rev

      key = key_for(doc)

      lock(key) do

        current_doc = do_get(key)

        if current_doc.nil?
          #
          # document is [already] gone, delete fails (return true)
          #
          true

        elsif current_doc['_rev'] != rev
          #
          # version in storage doesn't match version to delete
          # (return version in storage)
          #
          current_doc

        else
          #
          # delete is successful (return nil)
          #
          @redis.del(key)

          nil
        end
      end
    end

    def get_many(type, key=nil, opts={})

      keys = key ? Array(key) : nil

      #ids = if type == 'msgs' || type == 'schedules'
      #  @redis.keys_to_a("#{type}/*")

      ids = if keys == nil

        @redis.keys_to_a("#{type}/*")

      elsif keys.first.is_a?(String)

        keys.collect { |k| @redis.keys_to_a("#{type}/*!#{k}") }.flatten

      else #if keys.first.is_a?(Regexp)

        @redis.keys_to_a("#{type}/*").select { |i|

          i = i[type.length + 1..-1]
            # removing "^type/"

          keys.find { |k| k.match(i) }
        }
      end

      ids = ids.reject { |i| i.match(LOCK_KEY) }
      ids = ids.sort
      ids = ids.reverse if opts[:descending]

      skip = opts[:skip] || 0
      limit = opts[:limit] || ids.length
      ids = ids[skip, limit]

      docs = ids.length > 0 ? @redis.mget(*ids) : []
      docs = docs.inject({}) do |h, doc|
        if doc
          doc = Rufus::Json.decode(doc)
          h[doc['_id']] = doc
        end
        h
      end

      opts[:count] ? docs.size : docs.values
    end

    def ids(type)

      @redis.keys_to_a("#{type}/*").reject { |i|
        i.match(LOCK_KEY)
      }.collect { |i|
        i.split('/').last
      }.sort
    end

    def purge!

      @redis.keys_to_a('*').each { |k| @redis.del(k) }
    end

    # Returns a String containing a representation of the current content of
    # in this Redis storage.
    #
    def dump(type)

      @redis.keys_to_a("#{type}/*").sort.join("\n")
    end

    def close

      @redis.quit
      @redis = nil
    end

    # Mainly used by ruote's test/unit/ut_17_storage.rb
    #
    def add_type(type)
    end

    # Nukes a db type and reputs it(losing all the documents that were in it).
    #
    def purge_type!(type)

      @redis.keys_to_a("#{type}/*").each { |k| @redis.del(k) }
    end

    protected

    LOCK_KEY = /-lock$/

    def lock(key, &block)

      kl = "#{key}-lock"

      #p [ kl, :locking, Thread.current.object_id, Time.now.to_f ]

      #while @redis.setnx(kl, 'null') == false; sleep(0.007); end
      loop do
        r = @redis.setnx(kl, Time.now.to_f.to_s)
        #p [ :setnx, r ]
        if r == false
          sleep 0.007
        else
          break
        end
      end

      #p [ kl, :locked, Thread.current.object_id, Time.now.to_f ]

      #@redis.expire(kl, 2)

      result = block.call

      @redis.del(kl)

      #p [ kl, :unlocked, Thread.current.object_id, Time.now.to_f ]

      result
    end

    #   key_for(doc)
    #   key_for(type, key)
    #
    def key_for(*args)

      a = args.first

     (a.is_a?(Hash) ? [ a['type'], a['_id'] ] : args[0, 2]).join('/')
    end

    def do_get(key)

      from_json(@redis.get(key))
    end

    def from_json(s)

      s ? Rufus::Json.decode(s) : nil
    end

    def to_json(doc, opts={})

      Rufus::Json.encode(
        opts[:delete] ? nil : doc.merge('put_at' => Ruote.now_to_utc_s))
    end

    # Don't put configuration if it's already in
    #
    # (prevent storages from trashing configuration...)
    #
    def put_configuration

      return if get('configurations', 'engine')

      put({ '_id' => 'engine', 'type' => 'configurations' }.merge(@options))
    end
  end
end
end

