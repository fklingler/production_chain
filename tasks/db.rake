namespace :db do
  desc "Dump schema and data to a bzip file"
  task :backup => :environment do
    adapter, database, user, password, host = retrieve_db_info
    send("backup_#{adapter}_database", database, user, password, host)
  end

  desc "Load schema and data from a bzip file"
  task :restore => :environment do
    Rake::Task['db:drop'].invoke
    Rake::Task['db:create'].invoke
    adapter, database, user, password, host = retrieve_db_info
    send("restore_#{adapter}_database", database, user, password, host)
    Rake::Task['db:migrate'].invoke unless adapter == "mongodb"
  end
end

private
  
  def retrieve_db_info
    result = File.read "#{Rails.root}/config/database.yml"
    # result.strip!
    config_file = YAML::load(ERB.new(result).result)
    return [
      config_file[Rails.env]['adapter'],
      config_file[Rails.env]['database'],
      config_file[Rails.env]['username'],
      config_file[Rails.env]['password'],
      config_file[Rails.env]['host'] || "127.0.0.1"
    ]
  end
  
  def archive_name
    archive = "#{Rails.root}/db/dump.tar.gz"
  end

  def backup_mysql_database database, user, password, host
    cmd = "/usr/bin/env mysqldump --opt --skip-add-locks -h #{host} -u #{user} "
    puts cmd + "... [password filtered]"
    cmd += " -p'#{password}' " unless password.nil?
    cmd += " #{database} > dump.sql && tar czfh #{archive_name} dump.sql"
    system(cmd)
  end

  def restore_mysql_database database, user, password, host
    cmd = "tar xvzf #{archive_name} && "
    cmd += "/usr/bin/env mysql -h #{host} -u #{user} #{database}"
    puts cmd + "... [password filtered]"
    cmd += " -p'#{password}'" unless password.nil?
    cmd += " < dump.sql"
    system(cmd)
  end

  def backup_postgresql_database database, user, password, host
    cmd = "/usr/bin/env pg_dump -h #{host} -U #{user} "
    # puts cmd + "... [password filtered]"
    #cmd += " < '#{password}' " unless password.nil?
    cmd += " #{database} > dump.sql && tar czfh #{archive_name} dump.sql"
    system(cmd)
  end

  def restore_postgresql_database database, user, password, host
    cmd = "tar xvzf #{archive_name} && "
    cmd += "/usr/bin/env pg_restore -h #{host} -U #{user} #{database} < dump.sql"
    # puts cmd + "... [password filtered]"
    # cmd += " < '#{password}'" unless password.nil?
    system(cmd)
  end

  def backup_mongodb_database database, user, password, host
    cmd = "rm -rf dump/ 2>/dev/null && /opt/mongodb/bin/mongodump -h #{host} -d #{database}"
    cmd += " && tar czfh #{archive_name} dump/"
    system(cmd)
  end

  def restore_mongodb_database database, user, password, host
    cmd = "rm -rf dump/ 2>/dev/null && tar xvzf #{archive_name}"
    cmd += " && sudo /opt/mongodb/bin/mongorestore -h #{host} -d #{database} --dir dump/*_*"
    print cmd
    system(cmd)
  end
