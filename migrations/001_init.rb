require 'sequel'

Sequel.migration do
  change do
    create_table :events do
      primary_key :id
      Time :when
      json :attrs
    end
  end
end
