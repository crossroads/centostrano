# Copyright 2006-2008 by Mike Bailey. All rights reserved.
Capistrano::Configuration.instance(:must_exist).load do 
  namespace :centos do
    namespace :apache do
      
      set :apache_user, 'www-data'
      set :apache_vhost_dir, '/etc/httpd/sites-available'
      set :apache_ssl_enabled, false
      set :apache_ssl_ip, nil
      set :apache_ssl_forward_all, apache_ssl_enabled
      set :apache_ssl_chainfile, false
      set :apache_modules_enabled, %w(rewrite ssl proxy_balancer proxy_http deflate expires headers)
      set :apache_log_dir, '/var/log/httpd'
       
      desc "Install apache"
      task :install do
        install_deps
        enable_modules
        reload
      end
      
      # install dependencies for apache
      task :install_deps do
        apt.install( {:base => %w(openssl openssl-devel zlib zlib-devel)}, :stable )
      end
      
      SYSTEM_CONFIG_FILES[:apache] = [
        
        { :template => 'apache2.conf.erb',
          :path => '/etc/httpd/conf/httpd.conf',
          :mode => 0644,
          :owner => 'root:root'},

        { :template => 'namevirtualhosts.conf',
          :path => '/etc/httpd/conf.d/namevirtualhosts.conf',
          :mode => 0644,
          :owner => 'root:root'},
          
        { :template => 'ports.conf.erb',
          :path => '/etc/httpd/ports.conf',
          :mode => 0644,
          :owner => 'root:root'},

        { :template => 'status.conf.erb',
          :path => '/etc/httpd/mods-available/status.conf',
          :mode => 0644,
          :owner => 'root:root'}
          
      ]

      PROJECT_CONFIG_FILES[:apache] = [
        # Not required
      ]

      desc "Generate configuration file(s) for apache from template(s)"
      task :config_gen do
        config_gen_system
      end

      task :config_gen_system do
        SYSTEM_CONFIG_FILES[:apache].each do |file|
          deprec2.render_template(:apache, file)
        end
      end

      task :config_gen_project do
        PROJECT_CONFIG_FILES[:apache].each do |file|
          deprec2.render_template(:apache, file)
        end
        # XXX Need to flesh out generation of custom certs
        # In the meantime we'll just use the snakeoil cert
        #
        # top.deprec.ssl.config_gen if apache_ssl_enabled
        top.deprec.ssl.config_gen if apache_ssl_enabled
      end
      
      desc "Push apache config files to server"
      task :config, :roles => :web do
        config_system
        reload
      end
      
      desc "Generate initial configs and copy direct to server."
      task :initial_config, :roles => :web do
        SYSTEM_CONFIG_FILES[:apache].each do |file|
          deprec2.render_template(:apache, file.merge(:remote => true))
        end
      end
      
      desc "Push apache config files to server"
      task :config_system, :roles => :web do
        deprec2.push_configs(:apache, SYSTEM_CONFIG_FILES[:apache])
      end
      
      # Stub so generic tasks don't fail (e.g. deprec:web:config_project)
      task :config_project do
        # XXX Need to flesh out generation of custom certs
        # In the meantime we'll just use the snakeoil cert
        #
        top.deprec.ssl.config if apache_ssl_enabled
      end
      
      task :enable_modules, :roles => :web do
        apache_modules_enabled.each { |mod| sudo "a2enmod #{mod}" }
        reload
      end
      
      desc "Start Apache"
      task :start, :roles => :web do
        send(run_method, "/etc/init.d/httpd start")
      end

      desc "Stop Apache"
      task :stop, :roles => :web do
        send(run_method, "/etc/init.d/httpd stop")
      end

      desc "Restart Apache"
      task :restart, :roles => :web do
        send(run_method, "/etc/init.d/httpd restart")
      end

      desc "Reload Apache"
      task :reload, :roles => :web do
        send(run_method, "/etc/init.d/httpd reload")
      end

      desc "Set apache to start on boot"
      task :activate, :roles => :web do
        send(run_method, "sed -i '2i# chkconfig: 2345 10 90' /etc/init.d/httpd")
        send(run_method, "sed -i '3i# description: Activates/Deactivates Apache Web Server' /etc/init.d/httpd")
        send(run_method, "/sbin/chkconfig --add httpd")
        send(run_method, "/sbin/chkconfig --level 345 httpd on")
      end
      
      desc "Set apache to not start on boot"
      task :deactivate, :roles => :web do
        send(run_method, "/sbin/chkconfig --del httpd")
      end
      
      task :backup, :roles => :web do
        # not yet implemented
      end
      
      task :restore, :roles => :web do
        # not yet implemented
      end

    end
  end
end
