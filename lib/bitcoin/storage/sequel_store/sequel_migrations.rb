module Bitcoin::Storage::Backends::SequelMigrations

  def migrate
    unless @db.tables.include?(:blk)
      @db.create_table :blk do
        primary_key :id
        column :hash, :bytea, :null => false, :unique => true, :index => true
        column :depth, :int, :null => false, :index => true
        column :version, :bigint, :null => false
        column :prev_hash, :bytea, :null => false, :index => true
        column :mrkl_root, :bytea, :null => false
        column :time, :bigint, :null => false
        column :bits, :bigint, :null => false
        column :nonce, :bigint, :null => false
        column :blk_size, :int, :null => false
        column :chain, :int, :null => false
      end
    end

    unless @db.tables.include?(:tx)
      @db.create_table :tx do
        primary_key :id
        column :hash, :bytea, :null => false, :unique => true, :index => true
        column :version, :bigint, :null => false
        column :lock_time, :bigint, :null => false
        column :coinbase, :bool, :null => false
        column :tx_size, :int, :null => false
      end
    end

    unless @db.tables.include?(:blk_tx)
      @db.create_table :blk_tx do
        column :blk_id, :int, :null => false, :index => true
        column :tx_id, :int, :null => false, :index => true
        column :idx, :int, :null => false
      end
    end

    unless @db.tables.include?(:txin)
      @db.create_table :txin do
        primary_key :id
        column :tx_id, :int, :null => false, :index => true
        column :tx_idx, :int, :null => false
        column :script_sig, :bytea, :null => false
        column :prev_out, :bytea, :null => false, :index => true
        column :prev_out_index, :bigint, :null => false
        column :sequence, :bigint, :null => false
      end
    end

    unless @db.tables.include?(:txout)
      @db.create_table :txout do
        primary_key :id
        column :tx_id, :int, :null => false, :index => true
        column :tx_idx, :int, :null => false
        column :pk_script, :bytea, :null => false
        column :value, :bigint
        column :type, :int, :null => false, :index => true
      end
    end

    unless @db.tables.include?(:addr)
      @db.create_table :addr do
        primary_key :id
        column :hash160, String, :null => false, :index => true
      end
    end

    unless @db.tables.include?(:addr_txout)
      @db.create_table :addr_txout do
        column :addr_id, :int, :null => false, :index => true
        column :txout_id, :int, :null => false, :index => true
      end
    end

    unless @db.views.include?(:unconfirmed)
      @db.create_view(:unconfirmed,
        "SELECT * FROM tx WHERE NOT EXISTS " +
        "(SELECT 1 FROM blk_tx WHERE blk_tx.tx_id = tx.id)" +
        "ORDER BY tx.id DESC")
    end

    if Bitcoin.namecoin?
      unless @db.tables.include?(:names)
        @db.create_table :names do
          column :txout_id, :int, :null => false, :index => true
          column :hash, :bytea, :index => true
          column :name, :bytea, :index => true
          column :value, :bytea
        end
      end
    end
  end

end
