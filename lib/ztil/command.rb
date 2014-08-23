# encoding: utf-8
require 'thor'
require 'rest-client'
require 'json'

module Ztil
  class Command < Thor
    include Thor::Actions

    def self.source_root
      File.expand_path File.join( File.dirname(__FILE__), '../../', 'Backup' )
    end

    BAIDU_AK  = 'A0f00186ba072b824d88d6300c9f7f86'
    BAIDU_URL = 'http://api.map.baidu.com'

    # 百度的地理位置API | http://developer.baidu.com/map/index.php?title=webapi/guide/webservice-geocoding

    desc 'geocoder ADDRESS', '根据百度API, 将地址转换成经纬度'
    method_option :city, desc: '地址所在的城市', required: false
    def geocoder(address)
      r = JSON.parse RestClient.get("#{BAIDU_URL}/geocoder/v2/", { params: {address: address, output: :json, ak: BAIDU_AK, city: options[:city]} })
      say JSON.pretty_generate(r)
    end

    desc 'coordcoder LOCATION', '根据百度API, 将经纬度转换成地址, 纬度(小)在前, 经度在后, 逗号分隔'
    method_option :coordtype, desc: '坐标的类型', default: 'wgs84ll', required: false, aliases: 't',
      desc: '目前支持的坐标类型包括：bd09ll（百度经纬度坐标）、gcj02ll（国测局经纬度坐标）、wgs84ll（ GPS经纬度）'
    def coordcoder(location)
      r = JSON.parse RestClient.get("#{BAIDU_URL}/geocoder/v2/", { params: {location: location, output: :json, ak: BAIDU_AK, coordtype: options[:coordtype]} })
      say JSON.pretty_generate(r)
    end

    # 备份数据库 | https://github.com/meskyanichi/backup

    # 关心的是数据库，存储以及执行时间和邮件通知
    #
    # @example
    #   ztil backup --databases="mysql,mongodb" --storages="qi_niu" --email="xxx@xxx.com" --schedule="1.day&4:30 am"
    desc 'backup DATABASE_NAME', '备份数据库, 传入all表示所有databases'
    method_option :databases, desc: '需要备份的数据库类型, 支持mysql以及mongodb', required: true
    method_option :storages,  desc: '备份数据的存储方式, 支持存储到七牛'
    method_option :email,     desc: '备份成功后通知的邮箱'
    method_option :schedule,  desc: '按计划执行, 默认只执行一次'
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
    command "backup_zh perform -t #{name}"
  end
          SCH
        end
        run "whenever -f #{File.join(schedule_config_path, 'schedule.rb')}"
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

  end
end
