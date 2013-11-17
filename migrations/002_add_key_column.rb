require 'sequel'

Sequel.migration do
  change do
    add_column :events, :key, String
    from(:events).update(:key => '')
  end
end
