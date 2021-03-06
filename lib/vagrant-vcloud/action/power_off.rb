module VagrantPlugins
  module VCloud
    module Action
      class PowerOff
        def initialize(app, env)
          @app = app
          @logger = Log4r::Logger.new('vagrant_vcloud::action::poweroff')
        end

        def call(env)
          cfg = env[:machine].provider_config
          cnx = cfg.vcloud_cnx.driver

          vapp_id = env[:machine].get_vapp_id
          vm_id = env[:machine].id

          test_vapp = cnx.get_vapp(vapp_id)

          @logger.debug(
            "Number of VMs in the vApp: #{test_vapp[:vms_hash].count}"
          )

          # Poweroff VM
          env[:ui].info('Powering off VM...')
          task_id = cnx.poweroff_vm(vm_id)
          cnx.wait_task_completion(task_id)

          @app.call env
        end
      end
    end
  end
end
