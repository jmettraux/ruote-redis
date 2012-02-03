
$:.unshift(File.expand_path('../../../../ruote/lib', __FILE__))
$:.unshift(File.expand_path('../../../lib', __FILE__))

require 'rubygems'

require 'pp'

require 'redis'

N = 10_000

redis = ::Redis.new('db' => 12, 'thread_safe' => true)

p redis.del('put_gun')

N.times do
  msg = (Time.now.to_f.to_s + '__') * 50
  redis.rpush('put_gun', msg)
end

p redis.llen('put_gun')

results = []

loop do
  x = redis.lpop('put_gun')
  break unless x
  results << x
end

p results.size
p results.sort.uniq.size

# it's always N, redis is great

