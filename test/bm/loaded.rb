
$: << File.expand_path('../../../lib', __FILE__)

require 'test/unit'

require 'rufus-json/automatic'
require 'ruote'
require 'ruote-redis'

ruote =
  Ruote::Dashboard.new(
    Ruote::Worker.new(
      Ruote::Redis::Storage.new('db' => 15, 'thread_safe' => true)))

ruote.storage.purge!
#ruote.noisy = true

ruote.register 'toto' do |workitem|
  workitem.fields['seen'] = Time.now.to_s
end

t = Time.now

50.times do
  wfid = ruote.launch(Ruote.define do
    toto; toto; toto; toto; toto
  end)
  p wfid
end

loop do
  count = ruote.storage.get_many('expressions', nil, :count => true)
  p count
  break if count < 1
end

p Time.now - t

