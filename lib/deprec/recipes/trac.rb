Capistrano::Configuration.instance(:must_exist).load do 
  namespace :deprec do namespace :trac do
        
  # Master tracd process for server
  set :tracd_cmd, '/usr/local/bin/tracd'
  set :tracd_port, '9000'
  set :tracd_pidfile, '/var/run/tracd.pid'
  
  # Settings for this projects trac instance
  set(:trac_backup_dir) { "#{backup_dir}/trac" }
  set(:trac_path) { exists?(:deploy_to) ? "#{deploy_to}/trac" : Capistrano::CLI.ui.ask('path to trac config') }
  set(:tracd_parent_dir) { "#{trac_path}/projects" }
  set(:trac_password_file)  { "#{trac_path}/conf/users.htdigest" }
  set(:trac_account) { Capistrano::CLI.prompt('enter new trac user account name') }
  set :trac_passwordfile_exists, true # hack - should check on remote system instead
  set(:trac_header_logo_link) { trac_home_url }
  # We will symlink each projects trac dir into this dir for tracd to find

  # project
  set(:trac_home_url) { 'http://' + domain.sub(/^.*?\./, 'trac.') + '/' }
  set(:trac_desc) { application } 
  
  # Settings only used for generating trac.ini for this project
  # - notification
  set :trac_always_notify_owner, false
  set :trac_always_notify_reporter, false
  set :trac_always_notify_updater, true
  set :trac_smtp_always_bcc, ''
  set :trac_smtp_always_cc, ''
  set :trac_smtp_default_domain, ''
  set :trac_smtp_enabled, true
  set :trac_smtp_from, 'trac@localhost'
  set :trac_smtp_password, ''
  set :trac_smtp_port, 25
  set :trac_smtp_replyto, 'trac@localhost'
  set :trac_smtp_server, 'localhost'
  set :trac_smtp_subject_prefix, '__default__'
  set :trac_smtp_user, ''
  set :trac_use_public_cc, false
  set :trac_use_short_addr, false
  set :trac_use_tls, false  
  # - other
  set(:trac_base_url) { trac_home_url }
  
  desc "Install trac on server"
  task :install, :roles => :scm do
    version = 'trac-0.10.4'
    set :src_package, {
      :file => version + '.tar.gz',   
      :md5sum => '52a3a21ad9faafc3b59cbeb87d5a69d2  trac-0.10.4.tar.gz', 
      :dir => version,  
      :url => "http://ftp.edgewall.com/pub/trac/#{version}.tar.gz",
      :unpack => "tar zxf #{version}.tar.gz;",
      :install => 'python ./setup.py install --prefix=/usr/local;'
    }
    enable_universe
    apt.install( {:base => %w(build-essential wget python-sqlite sqlite python-clearsilver)}, :stable )
    deprec2.download_src(src_package, src_dir)
    deprec2.install_from_src(src_package, src_dir)
  end
  
  # desc "Remove trac from server"
  task :uninstall, :roles => :web do
    # not implemented
  end
  
  SYSTEM_CONFIG_FILES[:trac] = [
    {:template => 'tracd-init.erb',
     :path => '/etc/init.d/tracd',
     :mode => '0755',
     :owner => 'root:root'}
   ]
  
  PROJECT_CONFIG_FILES[:trac] = [
    {:template => 'trac.ini.erb',
     :path => "conf/trac.ini",
     :mode => '0644',
     :owner => 'root:root'}
  ]
  
  desc "Generate config files for trac"
  task :config_gen, :roles => :scm do
    config_gen_system
    config_gen_project
  end
  
  task :config_gen_system, :roles => :scm do
    SYSTEM_CONFIG_FILES[:trac].each do |file|
      deprec2.render('trac', file[:template], file[:path])
    end
  end
  
  task :config_gen_project, :roles => :scm do
    PROJECT_CONFIG_FILES[:trac].each do |file|
      deprec2.render('trac', file[:template], file[:path])
    end
  end
  
  desc "Push trac config files to server"
  task :config, :roles => :scm do
    config_system
    config_project
  end
  
  task :config_system, :roles => :scm do
    deprec2.push_configs(:trac, SYSTEM_CONFIG_FILES[:trac])
  end
  
  task :config_project, :roles => :scm do
    deprec2.push_configs(:trac, PROJECT_CONFIG_FILES[:trac])
  end

  desc "Initialize the trac db for this project"
  task :setup, :roles => :scm do
    config_gen_project
    config_project
    init
    set_default_permissions 
    # create trac account for current user 
    set :trac_account, user
    set :trac_passwordfile_exists, false # hack - should check on remote system instead
    user_add
    create_pid_dir
  end
  
  task :init, :roles => :scm do
    sudo "trac-admin #{trac_path} initenv #{application} sqlite:db/trac.db svn #{repos_root} /usr/local/share/trac/templates"
  end
  
  task :set_default_permissions, :roles => :scm do
    anonymous_disable
    authenticated_enable
  end
  
  task :start, :roles => :scm do
    sudo "/etc/init.d/tracd start"
    sudo "/etc/init.d/httpd restart"
  end

  task :stop, :roles => :scm do
    sudo "/etc/init.d/tracd stop"
  end

  task :activate, :roles => :scm do
    activate_system
    activate_project
  end
  
  task :activate_system, :roles => :scm do
    sudo "update-rc.d tracd defaults"
  end
  
  task :activate_project, :roles => :scm do
    sudo "update-rc.d tracd defaults"
  end
  
  task :deactivate, :roles => :scm do
    deactivate_system
    unlink_project
  end
  
  task :deactivate_system, :roles => :scm do
    sudo "update-rc.d -f tracd remove"
  end
  
  desc "Create backup of trac repository"
  task :backup, :roles => :web do
    # http://trac.edgewall.org/wiki/TracBackup
    timestamp = Time.now.utc.strftime("%Y%m%d%H%M%S")
    dest_dir = File.join(trac_backup_dir, "trac_#{application}_#{timestamp}")
    sudo "trac-admin #{trac_path} hotcopy #{dest_dir}"
  end
  
  desc "Restore trac repository from backup"
  task :restore, :roles => :web do
    # prompt user to select from list of locally stored backups
    # tracd_stop
    # copy out backup
  end
  
  #
  # Service specific tasks for end users
  #
  desc "create a trac user"
  task :user_add, :roles => :scm do
    create_file = trac_passwordfile_exists ? '' : ' -c '
    htdigest = '/usr/local/apache2/bin/htdigest'
    # XXX check if htdigest file exists and add '-c' option if not
    # sudo "test -f #{trac_path/conf/users.htdigest}
    create_file = trac_passwordfile_exists ? '' : ' -c '
    sudo_with_input("#{htdigest} #{create_file} #{trac_path}/conf/users.htdigest #{application} #{trac_account}", /password:/) 
  end
  
  desc "list trac users"
  task :list_users, :roles => :scm do
    sudo "cat #{trac_path}/conf/users.htdigest"
  end
  
  # desc "disable anonymous access to everything"
  task :anonymous_disable, :roles => :scm do
    sudo "trac-admin #{trac_path} permission remove anonymous '*'"
  end
  
  # desc "enable authenticated users access to everything"
  task :authenticated_enable, :roles => :scm do
    sudo "trac-admin #{trac_path} permission add authenticated TRAC_ADMIN"
  end
  
  #
  # Helper tasks used by other tasks
  #
  task :symlink_project, :roles => :scm do
    link = File.join(tracd_parent_dir, application)
    sudo "ln -sf #{link}"
  end
  
  task :unlink_project, :roles => :scm do
    link = File.join(tracd_parent_dir, application)
    sudo "test -h #{link} && unlink #{link} || true"
  end

  task :create_pid_dir, :roles => :scm do
    deprec.mkdir(File.dirname(tracd_pidfile))
  end
  
end end
  
end