require "etc"
require "log4r"

module VagrantPlugins
  module VCloud
    module Action
      class InventoryCheck

        def initialize(app, env)
          @app = app
          @logger = Log4r::Logger.new("vagrant_vcloud::action::inventory_check")
        end

        def call(env)
          vcloud_check_inventory(env)
            
          @app.call env
        end

        def vcloud_upload_box(env)

          config = env[:machine].provider_config
          config.vcloud_cnx = config.vcloud_config.vcloud_cnx.driver

          boxDir = env[:machine].box.directory.to_s
          boxFile = env[:machine].box.name.to_s

          boxOVF = "#{boxDir}/#{boxFile}.ovf"

          # Still relying on ruby-progressbar because report_progress basically sucks.

          @logger.debug("OVF File: #{boxOVF}")
          uploadOVF = config.vcloud_cnx.upload_ovf(
            config.vdc_id,
            env[:machine].box.name.to_s,
            "Vagrant Box",
            boxOVF,
            config.catalog_id,
            {
              :progressbar_enable => true
              # FIXME: export chunksize as a parameter and lower the default to 1M.
              #:chunksize => 262144
            }
          )

          env[:ui].info("Adding [#{env[:machine].box.name.to_s}] to Catalog [#{config.catalog_name}]")
          addOVFtoCatalog = config.vcloud_cnx.wait_task_completion(uploadOVF)

          if !addOVFtoCatalog[:errormsg].nil?
            raise Errors::CatalogAddError, :message => addOVFtoCatalog[:errormsg]
          end

          # Retrieve catalog_item ID
          config.catalog_item = config.vcloud_cnx.get_catalog_item_by_name(config.catalog_id, env[:machine].box.name.to_s)

        end

        def vcloud_check_inventory(env)
          # Will check each mandatory config value against the vCloud Director
          # Instance and will setup the global environment config values
          config = env[:machine].provider_config

          # FIXME: Make sure it fails if it can't find the organization!!!
          config.org = config.vcloud_cnx.organizations.get_by_name(config.org_name)

          @logger.debug("What we got back from org? #{config.org}")

          # Probably not needed...
          # config.org_id = config.vcloud_cnx.get_organization_id_by_name(config.org_name)

          @logger.debug("Looking for VDC called #{config.vdc_name}")

          config.vdc = config.org.vdcs.get_by_name(config.vdc_name)
          
          # Probably not needed...
          # config.vdc_id = config.vcloud_cnx.get_vdc_id_by_name(config.org, config.vdc_name)

          @logger.debug("Looking for Catalog called #{config.catalog_name}")

          config.catalog = config.org.catalogs.get_by_name(config.catalog_name)
          
          # Probably not needed...
          # config.catalog_id = config.vcloud_cnx.get_catalog_id_by_name(config.org, config.catalog_name)

          if config.catalog.nil?
            env[:ui].warn("Catalog [#{config.catalog_name}] does not exist!")

            user_input = env[:ui].ask(
              "Would you like to create the [#{config.catalog_name}] catalog?\nChoice (yes/no): "
            )

            if user_input.downcase == "yes" || user_input.downcase == "y" 

              catalog_attrs = { 
                :name => config.catalog_name, 
                :description => "Created by #{Etc.getlogin} running on #{Socket.gethostname.downcase} using vagrant-vcloud on #{Time.now.strftime("%B %d, %Y")}" 
              }

              config.org.catalogs.create(catalog_attrs)

              @logger.debug("Catalog Creation result: ???")

              env[:ui].info("Catalog [#{config.catalog_name}] successfully created.")

            else
              env[:ui].error("Catalog not created, exiting...")

              # FIXME: wrong error message
              raise VagrantPlugins::VCloud::Errors::VCloudError, 
                    :message => "Catalog not available, exiting..."
            end
          end

          @logger.debug("Looking for Catalog called #{config.catalog_name}")

          config.catalog = config.org.catalogs.get_by_name(config.catalog_name)

          @logger.debug("Getting catalog item with config.catalog: [#{config.catalog}] and machine name [#{env[:machine].box.name.to_s}]")


          config.catalog_item = config.catalog.catalog_items.get_by_name(env[:machine].box.name.to_s)

          @logger.debug("Catalog item is now #{config.catalog_item}")
          # config.vdc_network_id = config.org[:networks][config.vdc_network_name]

          if !config.catalog_item
            env[:ui].warn("Catalog item [#{env[:machine].box.name.to_s}] in Catalog [#{config.catalog_name}] does not exist!")

            user_input = env[:ui].ask(
              "Would you like to upload the [#{env[:machine].box.name.to_s}] box to "\
              "[#{config.catalog_name}] Catalog?\nChoice (yes/no): "
            )

            if user_input.downcase == "yes" || user_input.downcase == "y" 
              env[:ui].info("Uploading [#{env[:machine].box.name.to_s}]...")
              vcloud_upload_box(env)
            else
              env[:ui].error("Catalog item not available, exiting...")

              # FIXME: wrong error message
              raise VagrantPlugins::VCloud::Errors::VCloudError, 
                    :message => "Catalog item not available, exiting..."

            end

          else
            @logger.info("Using catalog item [#{env[:machine].box.name.to_s}] in Catalog [#{config.catalog_name}]...")
          end
        end

      end
    end
  end
end
