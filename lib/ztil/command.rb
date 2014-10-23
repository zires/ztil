# encoding: utf-8
require 'thor'

module Ztil
  class Command < Thor
    include Thor::Actions

    desc 'geocoder ADDRESS', '根据百度API, 将地址转换成经纬度'
    method_option :city, desc: '地址所在的城市', required: false
    def geocoder(address)
      require 'ztil/baidu'
      say Baidu.geocoder(address, options)
    end

    desc 'coordcoder LOCATION', '根据百度API, 将经纬度转换成地址, 纬度(小)在前, 经度在后, 逗号分隔'
    method_option :coordtype, desc: '坐标的类型', default: 'wgs84ll', required: false, aliases: 't',
      desc: '目前支持的坐标类型包括：bd09ll（百度经纬度坐标）、gcj02ll（国测局经纬度坐标）、wgs84ll（ GPS经纬度）'
    def coordcoder(location)
      require 'ztil/baidu'
      say Baidu.coordcoder(location, options)
    end

    # 备份数据库 | https://github.com/meskyanichi/backup

    # 关心的是数据库，存储以及执行时间和邮件通知
    #
    # @example
    #   ztil backup --databases="mysql,mongodb" --storages="qi_niu" --email="xxx@xxx.com" --schedule="1.day&4:30 am" --run_prefix="bundle exec"
    desc 'backup DATABASE_NAME', '备份数据库, DATABASE_NAME最好为数据库名称(可修改)'
    method_option :databases,  desc: '需要备份的数据库类型, 支持(mongodb, mysql, openldap, postgresql, redis, riak)', required: true, aliases: 'd'
    method_option :storages,   desc: '备份数据的存储方式, 支持存储到七牛(qi_niu), 本地(local)', aliases: 's'
    method_option :email,      desc: '备份成功后通知的邮箱', aliases: 'e'
    method_option :schedule,   desc: '按计划执行, 默认只执行一次, eq: `1.day&4:30 am`', aliases: 'S'
    method_option :run_prefix, desc: '运行任务命令的前缀, 例如`bundle exec`', aliases: 'r'
    def backup(name)
      storages = options[:storages] || 'local'

      run "backup_zh generate:model \
          --trigger #{name} \
          --databases=#{options[:databases]} \
          --compressor=gzip \
          --storages='#{storages}'"

      file = File.join( File.expand_path('~/Backup'), 'models', "#{name}.rb" )

      # 数据库名称
      database_name = options[:name] || name
      gsub_file file, /my_database_name/, database_name

      # 注释掉一些没用的
      options[:databases].split(',').map(&:strip).each do |database|
        case database
        when 'mysql'
          comment_lines file, 'skip_tables'
          comment_lines file, 'only_tables'
        when 'mongodb'
          comment_lines file, 'only_collections'
        end
      end

      # 邮箱设置
      if options[:email] && File.read(file) !~ /system@aukudu.com/
        insert_into_file file, after: "compress_with Gzip\n" do
          <<-MAIL
  ##
  # Mail [Notifier]
  notify_by Mail do |mail|
    mail.on_success           = true
    mail.on_warning           = false
    mail.on_failure           = true
    mail.from                 = 'system@aukudu.com'
    mail.address              = 'smtp.exmail.qq.com'
    mail.port                 = 465
    mail.domain               = 'aukudu.com'
    mail.user_name            = 'system@aukudu.com'
    mail.password             = 'Zsb170523402'
    mail.authentication       = 'plain'
    mail.encryption           = :ssl
    mail.to                   = '#{options[:email]}'
  end
          MAIL
        end
      end

      run "vi #{file}"

      # 周期执行
      if options[:schedule]
        schedule_path = File.join( File.expand_path('~/Backup'), 'schedule')
        schedule_config_path = File.join(schedule_path, 'config')
        FileUtils.mkdir_p(schedule_config_path) unless File.directory?(schedule_config_path)
        run "wheneverize #{schedule_path}"
        time, at = options[:schedule].split('&').map(&:strip)
        append_to_file( File.join(schedule_config_path, 'schedule.rb') ) do
          <<-SCH
  every #{time}, :at => '#{at}' do
    command "#{options[:run_prefix]} backup_zh perform -t #{name}"
  end
          SCH
        end
        run "whenever -f #{File.join(schedule_config_path, 'schedule.rb')} --update-crontab"
      else
        run "backup_zh perform -t #{name}"
      end

    end

    # 静态文件服务
    desc 'static_me', '在当前目录下开启静态文件服务, Ruby 1.9.2+'
    method_option :port, desc: '端口', required: false, default: 8000, aliases: 'p'
    def static_me
      run "ruby -run -ehttpd . -p#{options[:port]}"
    end

    # 在当前rails目录下安装capistrano
    # https://github.com/zires/capistrano-3-rails-template
    desc 'cap_me[PATH]', "在当前目录下安装capistrano的支持"
    def cap_me(path = nil)
      path ||= '.'
      gemfile = File.expand_path("#{path}/Gemfile")

      raise "Can't find Gemfile #{gemfile}" unless File.exists?(gemfile)

      append_to_file gemfile do
        <<-GEMS

### Add by cap me
gem 'unicorn'
group :development do
  gem 'capistrano', '>= 3.1.0'
  gem 'capistrano-rails', '>= 1.1.0'
  gem 'capistrano-bundler'
  gem 'capistrano-rbenv', '>= 2.0'
end

        GEMS
      end

      run "cd #{path} && bundle install && bundle exec cap install"

      tmp_dir = Dir.mktmpdir
      run "git clone https://github.com/zires/capistrano-3-rails-template.git #{tmp_dir}"
      run "cp -R #{tmp_dir}/config #{path}/"
      run "cp -R #{tmp_dir}/lib #{path}/"

      uncomment_lines File.join(path, 'Capfile'), /require.+rbenv/
      uncomment_lines File.join(path, 'Capfile'), /require.+bundler/
      uncomment_lines File.join(path, 'Capfile'), /require.+rails/

      run "cd #{path} && bundle exec cap production deploy --dry-run"

    end

  end
end
