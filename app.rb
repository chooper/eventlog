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

helpers do
  # protect some endpoints with a preshared key
  def protected!
    return if authorized?
    headers['WWW-Authenticate'] = 'Basic realm="Restricted Area"'
    # TODO: I probably want to return a JSON response, actually
    halt 401, "Not authorized\n"
  end

  def authorized?
    @auth ||=  Rack::Auth::Basic::Request.new(request.env)

    # i don't actually care if the secret key is the username or the password, as long as its provided
    # feels like there's some weird attack here where someone could test two possible passwords at once
    @auth.provided? \
      and @auth.basic? \
      and @auth.credentials \
      and SECRET_KEY \
      and @auth.credentials.include?(SECRET_KEY)
  end
end

configure do
  # pull in the not-required secret key
  SECRET_KEY = env("SECRET_KEY")

  # configure the db connection
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
  protected!
  content_type :json

  ds = DB[:events]

  # filter by key
  if params[:key]
    key = params[:key]
    ds = ds.where(key: key)
  end

  # filter by date
  if params[:since]
    begin
      start_date = Time.parse(params[:since]).strftime("%Y-%m-%d")
    rescue
       halt 400, {"status" => "error", "message" => "Could not parse `since` param: #{params[:since]}"}.to_json
    end
    ds = ds.where { created_at >= start_date }
  end

  events = ds.order(:created_at).reverse.all
  JSON.generate(events)
end

post '/events' do
  protected!
  content_type :json
  request.body.rewind # in case it's already been read

  # validate the payload
  begin
    event = JSON.parse(request.body.read)
  rescue
    halt 400, {"status" => "error", "message" => "Received payload is not valid JSON"}.to_json
  end
  unless event.is_a? Hash
    halt 400, {"status" => "error", "message" => "Received payload is not a hash"}.to_json
  end
  key = event.delete('key')
  if key.nil?
    halt 400, {"status" => "error", "message" => "Received payload has no `key` attr"}.to_json
  end

  # Re-generate the JSON
  begin
    event_json = JSON.generate(event)
  rescue
    halt 400, {"status" => "error", "message" => "Could not coerce payload to valid JSON"}.to_json
  end

  # Insert event into DB
  begin
    DB[:events].insert(:created_at => Time.now, :key => key, :attrs => event_json)
  rescue
    halt 503, {"status" => "error", "message" => "Could not save the event"}.to_json
  end

  {"status" => "ok"}.to_json
end

