require "fog"
require "log4r"

module VagrantPlugins
  module VCloud
    module Action
      class ConnectVCloud
        def initialize(app, env)
          @app = app
          @logger = Log4r::Logger.new("vagrant_vcloud::action::connect_vcloud")
        end

        def call(env)
          config = env[:machine].provider_config

#          begin
            # Avoid recreating a new session each time.
            if config.vcloud_cnx.nil?
              @logger.info("Connecting to vCloud Director...")

              @logger.debug("config.hostname    : #{config.hostname}")
              @logger.debug("config.username    : #{config.username}")
              @logger.debug("config.password    : #{config.password}")
              @logger.debug("config.org_name    : #{config.org_name}")

              # Create the vcloud-rest connection object with the configuration 
              # information.

              # FIXME: this should be parametrized...
              Excon.defaults[:ssl_verify_peer] = false

              config.vcloud_cnx = Fog::Compute::VcloudDirector.new(
                :vcloud_director_username => "#{config.username}@#{config.org_name}",
                :vcloud_director_password => config.password,
                :vcloud_director_host => config.hostname,
                :vcloud_director_show_progress => true, # task progress bar on/off
              )

              @logger.info("Logging into vCloud Director...")
              # config.vcloud_cnx.login
              

              # Check for the vCloud Director authentication token
              if config.vcloud_cnx.vcloud_token
                @logger.info("Logged in successfully!")
                @logger.debug(
                  "x-vcloud-authorization=#{config.vcloud_cnx.vcloud_token}"
                )
              else
                @logger.info("Login failed in to #{config.hostname}.")
                env[:ui].error("Login failed in to #{config.hostname}.")
                raise
              end
            else
              @logger.info("Already logged in, using current session")
              @logger.debug(
                  "x-vcloud-authorization=#{config.vcloud_cnx.vcloud_token}"
              )
            end

            @app.call env

#          rescue Exception => e
#            ### When bad credentials, we get here.
#            @logger.debug("Couldn't connect to vCloud Director: #{e.inspect}")
#            raise VagrantPlugins::VCloud::Errors::VCloudError, :message => e.message
#          end

        end
      end
    end
  end
end
