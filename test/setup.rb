require "bundler"
Bundler.setup
require "minitest/autorun"
require "rack/test"
require "shoulda"
require "timecop"
require "ap"
require "json"
require "logger"
$: << File.dirname(__FILE__) + "/../lib"
$: << File.expand_path(File.dirname(__FILE__) + "/..")
require "rack/oauth2/server"
require "rack/oauth2/server/admin"
require 'moped'

ENV["RACK_ENV"] = "test"
ENV["DB"] = "rack_oauth2_server_test"
DATABASE = Moped::Session.new([ '127.0.0.1:27017' ])
DATABASE.use(ENV["DB"])
FRAMEWORK = ENV["FRAMEWORK"] || "sinatra"


$logger = Logger.new("test.log")
$logger.level = Logger::DEBUG
Rack::OAuth2::Server::Admin.configure do |config|
  config.set :logger, $logger
  config.set :logging, true
  config.set :raise_errors, true
  config.set :dump_errors, true
  config.oauth.expires_in = 86400 # a day
  config.oauth.logger = $logger
end


case FRAMEWORK
when "sinatra", nil

  require "sinatra/base"
  puts "Testing with Sinatra #{Sinatra::VERSION}"
  require File.dirname(__FILE__) + "/sinatra/my_app"
  
  class Test::Unit::TestCase
    def app
      Rack::Builder.new do
        map("/oauth/admin") { run Server::Admin }
        map("/") { run MyApp }
      end
    end

    def config
      MyApp.oauth
    end
  end

when "rails"
  ver = Bundler.definition.specs['rails'][0].version.version.split('.')[0].to_i
  RAILS_ENV = "test"
  RAILS_ROOT = File.dirname(__FILE__) + "/rails#{ver}"
  begin
    require "rails"
  rescue LoadError
  end

  if defined?(Rails::Railtie)
    # Rails 3.x+
    require "rack/oauth2/server/railtie"
    require File.dirname(__FILE__) + "/rails#{ver}/config/environment"
    puts "Testing with Rails #{Rails.version}"
  
    class Minitest::Test
      def app
        ::Rails.application
      end

      def config
        ::Rails.configuration.oauth
      end
    end

  else
    # Rails 2.x
    require "initializer"
    require "action_controller"
    require File.dirname(__FILE__) + "/rails2/config/environment"
    puts "Testing with Rails #{Rails.version}"
  
    class Test::Unit::TestCase
      def app
        ActionController::Dispatcher.new
      end

      def config
        ::Rails.configuration.oauth
      end
    end
  end

else
  puts "Unknown framework #{FRAMEWORK}"
  exit -1
end


class Minitest::Test
  include Rack::Test::Methods
  include Rack::OAuth2

  def setup
    Server::Admin.scope = %{read write}
    @client = Server.register(:display_name=>"UberClient", :redirect_uri=>"http://uberclient.dot/callback", :scope=>%w{read write oauth-admin})
  end

  attr_reader :client, :end_user

  def teardown
    Server::Client.collection.drop
    Server::AuthRequest.collection.drop
    Server::AccessGrant.collection.drop
    Server::AccessToken.collection.drop
  end
end
