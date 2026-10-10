class CreateVaultTables < ActiveRecord::Migration[8.1]
  def change
    create_table :environments do |t|
      t.string :name, null: false
      t.timestamps
    end
    add_index :environments, :name, unique: true

    create_table :secrets do |t|
      t.references :environment, null: false, foreign_key: { on_delete: :cascade }
      t.string :name, null: false
      t.string :description, null: false, default: ""
      t.string :tags, null: false, default: ""
      # The value, encrypted with a key of its own.
      t.binary :ciphertext, null: false
      # That key, encrypted with the master key.
      t.binary :wrapped_key, null: false
      t.timestamps
    end
    add_index :secrets, [ :environment_id, :name ], unique: true

    create_table :api_keys do |t|
      t.string :name, null: false
      t.string :prefix, null: false
      t.string :token_digest, null: false
      t.boolean :read_only, null: false, default: false
      # False limits the key to the environments granted to it.
      t.boolean :all_environments, null: false, default: false
      t.datetime :last_used_at
      t.datetime :revoked_at
      t.timestamps
    end
    add_index :api_keys, :prefix, unique: true

    create_table :api_key_grants do |t|
      t.references :api_key, null: false, foreign_key: { on_delete: :cascade }
      t.references :environment, null: false, foreign_key: { on_delete: :cascade }
    end
    add_index :api_key_grants, [ :api_key_id, :environment_id ], unique: true

    create_table :audit_entries do |t|
      t.string :key_prefix, null: false, default: ""
      t.string :action, null: false
      t.string :environment_name, null: false, default: ""
      t.string :secret_name, null: false, default: ""
      t.string :outcome, null: false, default: "ok"
      t.string :ip_address, null: false, default: ""
      t.datetime :created_at, null: false
    end
    add_index :audit_entries, :created_at
  end
end
