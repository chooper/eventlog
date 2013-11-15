require 'sequel'

Sequel.migration do
  change do
    create_table :events do
      primary_key :id
      Time :created_at
      json :attrs
    end
  end
end
