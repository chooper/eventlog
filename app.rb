
require 'sinatra'
require 'sequel'

def env(key)
  ENV[key]
end

def env!(key)
  v = env(key) 
  return v unless v.nil?
  raise ArgumentError, "Missing key '#{key}' from environment"
end

configure do
  DATABASE_URL = env!("DATABASE_URL")
  DB = Sequel.connect(DATABASE_URL,
    test:             true,
    pool_timeout:     env('PG_POOL_TIMEOUT') || 2,
    connect_timeout:  env('PG_CONN_TIMEOUT') || 2,
    sslmode:          'require'
  )
  DB.extension :pg_json
  require './models'
end

get '/' do
  "Ops Changelog"
end

get '/events' do
  DB[:events].all.inspect
end

post '/events' do
  request.body.rewind # in case it's already been read

  # Validate the payload
  begin
    event = JSON.parse request.body.read
    unless event.is_a? Hash
      halt 400, "Received payload is not a hash"
    end
  rescue
    halt 400, "Received payload is not valid JSON"
  end

  # Re-generate the JSON. Although... no good reason to not just pass the
  # original payload through that I can think of.
  event_json = JSON.generate event
  DB[:events].insert(:when => Time.now, :attrs => event_json)
end

