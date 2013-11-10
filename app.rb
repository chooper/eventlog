
require 'sinatra'
require 'sequel'

if ENV['DATABASE_URL'].nil?
  raise ArgumentError, "Missing DATABASE_URL from environment!"
end

DATABASE_URL = ENV["DATABASE_URL"]

DB = Sequel.connect(DATABASE_URL,
  test: true,
  pool_timeout: 2,
  connect_timeout: 2,
  sslmode: 'require')
DB.extension :pg_json

require './models'

get '/' do
  "Ops Changelog"
end

get '/events' do
  DB[:events].inspect
end

