$LOAD_PATH.unshift(File.join(File.dirname(File.realpath(__FILE__)), 'lib'))

require 'rubygems'
require 'bundler/setup'
require 'sinatra/base'
require 'sinatra/partial'
require 'json'
require 'sass'
require 'compass'
require 'yaml'
require 'sassmeister'

# require 'pry-remote'

class SassMeisterApp < Sinatra::Base
  register Sinatra::Partial

  helpers SassMeister

  configure do
    APP_VERSION = '2.0.1'
  end

  set :partial_template_engine, :erb

  configure :production do
    APP_DOMAIN = 'sassmeister.com'
    require 'newrelic_rpm'
  end

  configure :development do
    APP_DOMAIN = 'sassmeister.dev'
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
