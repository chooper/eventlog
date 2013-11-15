$stdout.sync = true

require 'sinatra'
require 'sequel'
require 'logger'

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
    sslmode:          'require',
    loggers:          [Logger.new($stdout)]
  )
  DB.sql_log_level = :info
  DB.extension :pg_json
  require './models'
end

get '/' do
  "Ops Changelog"
end

get '/events' do
  content_type :json

  ds = DB[:events]

  # Allow filtering by date
  if params[:since]
    # TODO: Catch parsing errors
    start_date = Time.parse(params[:since]).strftime("%Y-%m-%d")
    end_date = Time.now.strftime("%Y-%m-%d")
    ds = ds.where(date(:when) => (start_date .. end_date).to_a)
  end

  events = ds.order(:when).reverse.all
  JSON.generate(events)
end

post '/events' do
  content_type :json
  request.body.rewind # in case it's already been read

  # Validate the payload
  begin
    event = JSON.parse(request.body.read)
    unless event.is_a? Hash
      halt 400, {"status" => "error", "message" => "Received payload is not a hash"}.to_json
    end
  rescue
    halt 400, {"status" => "error", "message" => "Received payload is not valid JSON"}.to_json
  end

  # Re-generate the JSON. Although... no good reason to not just pass the
  # original payload through that I can think of.
  begin
    event_json = JSON.generate(event)
  rescue
    halt 400, {"status" => "error", "message" => "Could not coerce payload to valid JSON"}.to_json
  end

  begin
    DB[:events].insert(:when => Time.now, :attrs => event_json)
  rescue
    halt 503, {"status" => "error", "message" => "Could not save the event"}.to_json
  end

  {"status" => "ok"}.to_json
end

