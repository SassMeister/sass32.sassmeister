require "bundler/setup"

require 'rack/contrib'

require 'sassmeister'

# Gzip responses
use Rack::Deflater

## There is no need to set directories here anymore;
## Just run the application

SassMeisterApp.set :host_public_folder, File.join(File.dirname(File.realpath(__FILE__)), 'public')

# Run the application
run SassMeisterApp
