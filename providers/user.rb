#
# LWPR for Oracle DB user management
#


def close
  @db.close rescue nil
  @db = nil
end

def db
  @db ||= begin
    connection = OCI8.new(
      @new_resource.connection[:username],
      @new_resource.connection[:password],
      "//#{new_resource.connection[:host]}:#{new_resource.connection[:port]}/#{new_resource.connection[:sid]}"
    )
    connection
  end
end

def exists?
  data = db.exec("SELECT USERNAME FROM DBA_USERS WHERE USERNAME=\'#{@new_resource.username.upcase}\'")
  data.fetch
  data.row_count!=0
end

action :create do
  require 'oci8'
  unless exists?
    begin
      Chef::Log.info("Createing Oracle database user [#{@new_resource.username}]")
      db.exec("CREATE USER #{@new_resource.username} identified by \"#{@new_resource.password}\"")
      Chef::Log.info("oracle_database_user[#{@new_resource.username}]: created")
      @new_resource.updated_by_last_action(true)
    ensure
      close
    end
  else
   Chef::Log.warn("Oracle database user [#{@new_resource.username}] already exists")
  end
end

action :drop do
  require 'oci8'
  if exists?
    begin
      Chef::Log.info("Droping Oracle database user [#{@new_resource.username}]")
      db.exec("DROP USER #{@new_resource.username} CASCADE")
      Chef::Log.info("Oracle database user [#{@new_resource.username}]: dropped")
      @new_resource.updated_by_last_action(true)
    ensure
      close
    end
  end
end

action :grant do
  require 'oci8'
  begin
    if (/(\A\*[0-9A-F]{40}\z)/i).match(@new_resource.password) then
      password = filtered = "PASSWORD '#{$1}'"
    else
      password = "'#{@new_resource.password}'"
      filtered = '[FILTERED]'
    end
    grant_statement = "GRANT #{@new_resource.privileges.join(', ')} PRIVILEGES TO #{@new_resource.username}"
    Chef::Log.info("#{@new_resource}: granting access with statement [#{grant_statement}#{filtered}]")
    db.exec(grant_statement)
    @new_resource.updated_by_last_action(true)
  ensure
    close
  end
end

