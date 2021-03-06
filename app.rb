require 'rubygems'
require 'sinatra'
require 'haml'
require 'builder'
require 'csv_map'
require 'logger'
require 'rack_hoptoad'
require 'compass'

use Rack::HoptoadNotifier, ENV['hoptoad_key']

configure do
  LOG = Logger.new(ENV['RACK_ENV'] == 'production' ?
    (File.dirname(__FILE__) + '/log/sinatra.log') : $stderr)

  %w{ hoptoad_key base_url yahoo_key GOOGLE_ANALYTICS }.each do |key|
    raise "Missing environment variable: #{key}" unless ENV.include?(key)
  end

  Yahoo.apikey = ENV['yahoo_key']

  Compass.configuration do |config|
    config.project_path = File.dirname(__FILE__)
    config.sass_dir = 'views'
  end
    
  set :haml, { :format => :html5 }
  set :sass, Compass.sass_engine_options
end

get '/screen.css' do
  content_type 'text/css', :charset => 'utf-8'
  sass :screen
end

# Upload the files
get '/' do
  haml :upload
end

post '/' do
  map = CsvMap.new(params[:map])

  if map.import
    if params[:next] == 'redirect' && ENV['base_url'] !~ /localhost/
      redirect("http://maps.google.com/?q=" + ENV['base_url'] + map.slug)
    else
      ENV['base_url'] + map.slug
    end
  else
    @error_msg = "We were unable to load your map, sorry."
    haml :upload
  end
end

# Get the map for google maps
get '/:key' do
  if (@csv_map = CsvMap.get(params['key'])).nil?
    @error_msg = "That map doesn't exist, sorry"
    throw :halt, [404, haml(:upload)]
  end

  content_type 'application/xml', :charset => 'utf-8'
  builder :rss
end
