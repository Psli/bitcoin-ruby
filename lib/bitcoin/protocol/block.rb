module Bitcoin
  module Protocol

    class Block

      BLOCK_VERSION_DEFAULT     = (1 << 0)
      BLOCK_VERSION_AUXPOW      = (1 << 8)
      BLOCK_VERSION_CHAIN_START = (1 << 16)
      BLOCK_VERSION_CHAIN_END   = (1 << 30)

      # block hash
      attr_accessor :hash

      # previous block hash
      attr_accessor :prev_block

      # transactions (Array of Tx)
      attr_accessor :tx

      # merkle root
      attr_accessor :mrkl_root

      # block generation time
      attr_accessor :time

      # difficulty target bits
      attr_accessor :bits

      # nonce (number counted when searching for block hash matching target)
      attr_accessor :nonce

      # version (usually 1)
      attr_accessor :ver

      # raw protocol payload
      attr_accessor :payload

      alias :transactions :tx

      # compare to another block
      def ==(other)
        @hash == other.hash
      end

      def binary_hash
        [@hash].pack("H*")
      end

      # create block from raw binary +data+
      def initialize(data)
        @tx = []
        parse_data(data) if data
      end

      # parse raw binary data
      def parse_data(data)
        @ver, @prev_block, @mrkl_root, @time, @bits, @nonce, payload = data.unpack("Ia32a32IIIa*")
        recalc_block_hash

        if (@ver & BLOCK_VERSION_AUXPOW) > 0
          aux_pow = AuxPow.new(nil)
          payload = aux_pow.parse_data(payload)
        end

        return  unless payload.size > 0

        tx_size, payload = Protocol.unpack_var_int(payload)
        (0...tx_size).each{  break if payload == true
          t = Tx.new(nil)
          payload = t.parse_data(payload)
          @tx << t
        }

        @payload = to_payload
        payload
      end

      # recalculate the block hash
      def recalc_block_hash
        @hash = Bitcoin.block_hash(@prev_block.reverse_hth, @mrkl_root.reverse_hth, @time, @bits, @nonce, @ver)
      end

      # verify mrkl tree
      def verify_mrkl_root
        @mrkl_root.reverse_hth == Bitcoin.hash_mrkl_tree( @tx.map(&:hash) ).last
      end

      # get the block header info
      # [<version>, <prev_block>, <merkle_root>, <time>, <bits>, <nonce>, <txcount>, <size>]
      def header_info
        [@ver, @prev_block.reverse_hth, @mrkl_root.reverse_hth, Time.at(@time), @bits, @nonce, @tx.size, @payload.size]
      end

      # convert to raw binary format
      def to_payload
        head = [@ver, @prev_block, @mrkl_root, @time, @bits, @nonce].pack("Ia32a32III")
        [head, Protocol.pack_var_int(@tx.size), @tx.map(&:to_payload).join].join
      end

      # convert to ruby hash (see also #from_hash)
      def to_hash
        {
          'hash' => @hash, 'ver' => @ver,
          'prev_block' => @prev_block.reverse_hth, 'mrkl_root' => @mrkl_root.reverse_hth,
          'time' => @time, 'bits' => @bits, 'nonce' => @nonce,
          'n_tx' => @tx.size, 'size' => (@payload||to_payload).bytesize,
          'tx' => @tx.map{|i| i.to_hash },
          'mrkl_tree' => Bitcoin.hash_mrkl_tree( @tx.map{|i| i.hash } )
        }
      end

      def hextarget
        Bitcoin.decode_compact_bits(@bits)
      end

      def decimaltarget
        Bitcoin.decode_compact_bits(@bits).to_i(16)
      end

      def difficulty
        Bitcoin.block_difficulty(@bits)
      end

      # introduced in block version 2 by BIP_0034
      # blockchain height as seen by the block itself.
      # do not trust this value, instead verify with chain storage.
      def bip34_block_height
        return nil unless @ver >= 2
        coinbase = @tx.first.inputs.first.script_sig
        coinbase.unpack("xH#{ coinbase.unpack("C")[0]*2 }")[0].to_i(16)
      rescue
        nil
      end

      # convert to json representation as seen in the block explorer.
      # (see also #from_json)
      def to_json(options = {:space => ''}, *a)
        JSON.pretty_generate( to_hash, options )
      end

      # write json representation to a file
      # (see also #to_json)
      def to_json_file(path)
        File.open(path, 'wb'){|f| f.print to_json; }
      end

      # parse ruby hash (see also #to_hash)
      def self.from_hash(h)
        blk = new(nil)
        blk.instance_eval{
          @ver, @time, @bits, @nonce = h.values_at('ver', 'time', 'bits', 'nonce')
          @prev_block, @mrkl_root = h.values_at('prev_block', 'mrkl_root').map{|i| i.htb_reverse }
          recalc_block_hash
          h['tx'].each{|tx| @tx << Tx.from_hash(tx) }
        }
        blk
      end

      # convert ruby hash to raw binary
      def self.binary_from_hash(h); from_hash(h).to_payload; end

      # parse json representation (see also #to_json)
      def self.from_json(json_string); from_hash( JSON.load(json_string) ); end

      # convert json representation to raw binary
      def self.binary_from_json(json_string); from_json(json_string).to_payload; end

      # convert header to json representation.
      def header_to_json(options = {:space => ''})
        h = to_hash
        %w[tx mrkl_tree].each{|k| h.delete(k) }
        JSON.pretty_generate( h, options )
      end

      # read binary block from a file
      def self.from_file(path); new( Bitcoin::Protocol.read_binary_file(path) ); end

      # read json block from a file
      def self.from_json_file(path); from_json( Bitcoin::Protocol.read_binary_file(path) ); end

      def validator(store, prev_block = nil)
        @validator ||= Bitcoin::Validation::Block.new(self, store, prev_block)
      end
    end

  end
end
