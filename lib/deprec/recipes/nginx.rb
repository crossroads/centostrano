# Copyright 2006-2008 by Mike Bailey. All rights reserved.
Capistrano::Configuration.instance(:must_exist).load do 
  namespace :deprec do 
    namespace :nginx do

      set :nginx_server_name, nil
      set :nginx_user,  'nginx'
      set :nginx_group, 'nginx'
      set :nginx_vhost_dir, '/usr/local/nginx/conf/vhosts'

      SRC_PACKAGES[:nginx] = {
        :filename => 'nginx-0.5.34.tar.gz',   
        :md5sum => "8f7d3efcd7caaf1f06e4d95dfaeac238  nginx-0.5.34.tar.gz", 
        :dir => 'nginx-0.5.34',  
        :url => "http://sysoev.ru/nginx/nginx-0.5.34.tar.gz",
        :unpack => "tar zxf nginx-0.5.34.tar.gz;",
        :configure => %w(
        ./configure
        --sbin-path=/usr/local/sbin
        --with-http_ssl_module
        ;
        ).reject{|arg| arg.match '#'}.join(' '),
        :make => 'make;',
        :install => 'make install;'
      }

      desc "Install nginx"
      task :install do
        install_deps
        deprec2.download_src(SRC_PACKAGES[:nginx], src_dir)
        deprec2.install_from_src(SRC_PACKAGES[:nginx], src_dir)
        create_nginx_user
        # setup_vhost_dir     # XXX not done yet
        # install_index_page  # XXX not done yet
      end

      # install dependencies for nginx
      task :install_deps do
        apt.install( {:base => %w(libpcre3 libpcre3-dev libpcrecpp0 libssl-dev zlib1g-dev)}, :stable )
        # do we need libgcrypt11-dev?
      end

      task :create_nginx_user do
        deprec2.groupadd(nginx_group)
        deprec2.useradd(nginx_user, :group => nginx_group, :homedir => false)
      end

      SYSTEM_CONFIG_FILES[:nginx] = [

        {:template => 'nginx-init-script',
          :path => '/etc/init.d/nginx',
          :mode => '0755',
          :owner => 'root:root'},

        {:template => 'nginx.conf.erb',
          :path => "/usr/local/nginx/conf/nginx.conf",
          :mode => '0644',
          :owner => 'root:root'},

        {:template => 'mime.types.erb',
          :path => "/usr/local/nginx/conf/mime.types",
          :mode => '0644',
          :owner => 'root:root'},

        {:template => 'nothing.conf',
          :path => "/usr/local/nginx/conf/vhosts/nothing.conf",
          :mode => '0644',
          :owner => 'root:root'}
      ]

      desc <<-DESC
      Generate nginx config from template. Note that this does not
      push the config to the server, it merely generates required
      configuration files. These should be kept under source control.            
      The can be pushed to the server with the :config task.
      DESC
      task :config_gen do
        SYSTEM_CONFIG_FILES[:nginx].each do |file|
          deprec2.render_template(:nginx, file)
        end
      end

      desc "Push trac config files to server"
      task :config, :roles => :web do
        deprec2.push_configs(:nginx, SYSTEM_CONFIG_FILES[:nginx])
      end

      desc <<-DESC
      Activate nginx start scripts on server.
      Setup server to start nginx on boot.
      DESC
      task :activate, :roles => :web do
        activate_system
      end

      task :activate_system, :roles => :web do
        send(run_method, "update-rc.d nginx defaults")
      end

      desc <<-DESC
      Dectivate nginx start scripts on server.
      Setup server to start nginx on boot.
      DESC
      task :deactivate, :roles => :web do
        send(run_method, "update-rc.d -f nginx remove")
      end


      # Control

      desc "Start Nginx"
      task :start, :roles => :web do
        send(run_method, "/etc/init.d/nginx start")
      end

      desc "Stop Nginx"
      task :stop, :roles => :web do
        send(run_method, "/etc/init.d/nginx stop")
      end

      desc "Restart Nginx"
      task :restart, :roles => :web do
        send(run_method, "/etc/init.d/nginx restart")
      end

      desc "Reload Nginx"
      task :reload, :roles => :web do
        send(run_method, "/etc/init.d/nginx reload")
      end

      task :backup, :roles => :web do
        # there's nothing to backup for nginx
      end

      task :restore, :roles => :web do
        # there's nothing to store for nginx
      end

    end 
  end
end