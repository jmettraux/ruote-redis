
#
# testing ruote-redis
#
# Started in Narita, finished in Santa Barbara
#
# Fri Feb  3 14:47:04 JST 2012
#

$:.unshift(File.expand_path('../../../../ruote/lib', __FILE__))
$:.unshift(File.expand_path('../../../lib', __FILE__))

require 'rubygems'

require 'pp'

require 'rufus-json/automatic'
require 'redis'

require 'ruote'
#require 'ruote/storage/fs_storage'
require 'ruote-redis'

N = 1000

$dash = Ruote::Dashboard.new(
  Ruote::Worker.new(
    Ruote::Redis::Storage.new(
      'db' => 13, 'thread_safe' => true)))
    #Ruote::HashStorage.new))
    #Ruote::FsStorage.new('work')))

p $dash.storage_participant.size
$dash.storage.purge!
#p $dash.processes.size
p $dash.storage_participant.size

#exit 0

$dash.register 'toto', Ruote::StorageParticipant

$pdef = Ruote.define do
  sequence do
    sequence do
      toto
    end
  end
end

$wfids = []

N.times do |i|
  $wfids << $dash.launch($pdef)
  print (i % 10 == 0) ? i : '.'; STDOUT.flush
  #sleep 0.001 # jams...
  #sleep 0.005
end

puts
puts 'launch done'

t = Time.now

while (n = $dash.storage_participant.size) < N
  sleep 0.050
  p n if (Time.now - t) > 60.0
  break if (Time.now - t) > 2 * 60.0
end

puts "took #{Time.now - t}s"
p $dash.storage_participant.size

$dash.shutdown
$dash.storage.purge!

