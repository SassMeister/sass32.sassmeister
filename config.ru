require "bundler/setup"

require 'rack/contrib'

require './sassmeister'

## There is no need to set directories here anymore;
## Just run the application

# Run the application
run SassMeisterApp
