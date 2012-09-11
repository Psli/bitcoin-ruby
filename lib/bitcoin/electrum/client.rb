require 'eventmachine'
require 'json'

class ElectrumClient < EM::Connection

  DEFAULT_SERVERS = [
    ['ecdsa.org', 50001],
    ['electrum.novit.ro', 50001],
    ['uncle-enzo.info', 50001],
    ['electrum.bytesized-hosting.com', 50001],
    ['electrum.bitfoo.org', 50001],
  ]
  DEFAULT_TIMEOUT = 5

  attr_reader :requests
  def initialize
    @buf = BufferedTokenizer.new("\n")
    @requests = {}
    @callbacks = {}
    @id_seq = 0
    @connected = false
  end

  def self.connect
    host, port = *DEFAULT_SERVERS.sample
    puts "Connecting to electrum server #{host}:#{port}"
    EM.connect(host, port, self)
  end

  def connected?; @connected; end

  def request method, *params, &block
    id = @id_seq += 1
    @requests[id] = [method, block]
    send_data({id: id, method: method, params: params}.to_json + "\n")
    EM.add_timer(DEFAULT_TIMEOUT) { (@connected = false; close_connection)  if @requests[id]}
  end

  def on method, *params, &block
    @callbacks[method] ||= []
    @callbacks[method] << block
    request(method, *params)
  end

  def connected &block
    @callbacks[:connected] = block
  end

  def connection_completed
    @callbacks[:connected].call(self)  if @callbacks[:connected]
    @connected = true
  end

  def receive_data(data)
    @buf.extract(data).each do |packet|
      pkt = JSON.load(packet)
      if pkt['id']
        method, cb = @requests.delete(pkt['id'])
        cb.call(pkt['result'])  if cb
      else
        method = pkt['method']
        params = pkt['params']
        @callbacks[method].each {|cb| cb.call(params)}
      end
    end
  end

  def unbind
    unless connected?
      host, port = *DEFAULT_SERVERS.sample
      puts "Connecting to electrum server #{host}:#{port}"
      reconnect(host, port)
    end
  end
end
