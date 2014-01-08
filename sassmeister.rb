$LOAD_PATH.unshift(File.join(File.dirname(File.realpath(__FILE__)), 'lib'))

require 'rubygems'
require 'bundler/setup'
require 'sinatra/base'
require 'sinatra/partial'
require 'chairman'
require 'json'
require 'sass'
require 'compass'
require 'yaml'
require 'sassmeister'
require 'array'

# require 'pry-remote'

class SassMeisterApp < Sinatra::Base
  register Sinatra::Partial

  use Chairman::Routes

  helpers SassMeister

  configure do
    APP_VERSION = '2.0.1'
  end

  # implement redirects
  class Chairman::Routes
    configure :production do
      helpers do
        use Rack::Session::Cookie, :key => 'sassmeister.com',
                                   :domain => '.sassmeister.com',
                                   :path => '/',
                                   :expire_after => 7776000, # 90 days, in seconds
                                   :secret => ENV['COOKIE_SECRET']
       end
    end

    configure :development do
      helpers do
        use Rack::Session::Cookie, :key => 'sassmeister.dev',
                                   :path => '/',
                                   :expire_after => 7776000, # 90 days, in seconds
                                   :secret => 'local'
      end
    end

    after '/authorize/return' do
      session[:version] == SassMeisterApp::APP_VERSION

      redirect to('/')
    end

    after '/logout' do
      redirect to('/')
    end
  end

  set :partial_template_engine, :erb

  configure :production do
    APP_DOMAIN = 'sassmeister.com'
    SANDBOX_DOMAIN = 'sandbox.sassmeister.com'
    require 'newrelic_rpm'

    Chairman.config(ENV['GITHUB_ID'], ENV['GITHUB_SECRET'], ['gist'])
  end

  configure :development do
    APP_DOMAIN = 'sassmeister.dev'
    SANDBOX_DOMAIN = 'sandbox.sassmeister.dev'
    yml = YAML.load_file("config/github.yml")
    Chairman.config(yml["client_id"], yml["client_secret"], ['gist'])
  end

  helpers do
    def origin
      return request.env["HTTP_ORIGIN"] if origin_allowed? request.env["HTTP_ORIGIN"]

      return false
    end

    def origin_allowed?(uri)
      return false if uri.nil?

      return uri.match(/^http:\/\/(.+\.){0,1}sassmeister\.(com|dev|([\d+\.]{4}xip\.io))/)
    end
  end


  before do
    @github = Chairman.session(session[:github_token])
    @gist = nil
    @plugins = plugins

    params[:syntax].downcase! unless params[:syntax].nil?
    params[:original_syntax].downcase! unless params[:original_syntax].nil?

    headers 'Access-Control-Allow-Origin' => origin if origin
  end

  before /^(?!\/(authorize))/ do
    if session[:version].nil? || session[:version] != APP_VERSION
      session[:github_token] = nil
      session[:github_id] = nil
      @force_invalidate = true
      session[:version] = APP_VERSION
    end
  end

  post '/compile' do
    content_type 'application/json'

    {
      css: sass_compile(params[:input], params[:syntax], params[:output_style]),
      dependencies: get_build_dependencies(params[:input])
    }.to_json.to_s
  end


  post '/convert' do
    content_type 'application/json'

    {
      css: sass_convert(params[:original_syntax], params[:syntax], params[:input]),
      dependencies: get_build_dependencies(params[:input])
    }.to_json.to_s    
  end


  get '/extensions' do
    erb :extensions, layout: false
  end
  
  run! if app_file == $0
end
