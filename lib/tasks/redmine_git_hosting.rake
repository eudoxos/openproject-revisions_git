#
# Tasks in this namespace (openproject_git_hosting) are for administrative tasks
#
# TOP-LEVEL TARGETS:
#
# 1) Repopulate settings in the database with defaults from init.rb
#
# rake openproject_git_hosting:restore_defaults RAILS_ENV=xxx
#
# 2) Resynchronize/repair gitolite configuration (fix keys directory and configuration).
#    Also, expire repositories in the recycle_bin if necessary.
#
# rake openproject_git_hosting:update_repositories RAILS_ENV=xxx
#
# 3) Fetch all changesets for repositories and then rescynronize gitolite configuration (as in #1)
#
# rake openproject_git_hosting:fetch_changsets RAILS_ENV=xxx
#
# 4) Install custom scripts to the script directory.  The optional argument
#    'READ_ONLY=true' requests that the resulting scripts and script directory
#    be made read-only to the web server.  The optional argument WEB_USER=xxx
#    states that scripts should be owned by user "xxx".  If omitted, the
#    script attempts to figure out the web user by using "ps" and looking
#    for httpd.
#
# rake openproject_git_hosting:install_scripts [READ_ONLY=true] [WEB_USER=xxx] RAILS_ENV=yyy
#
# 5) Remove the custom scripts directory (and the enclosed scripts)
#
# rake openproject_git_hosting:remove_scripts RAILS_ENV=xxxx
#

namespace :openproject_git_hosting do

  desc "Reload defaults from init.rb into the openproject_git_hosting settings."
  task :restore_defaults => [:environment] do
    puts "Reloading defaults from init.rb..."
    RedmineGitolite::GitHosting.logger.warn { "Reloading defaults from init.rb from command line" }

    default_hash = Redmine::Plugin.find("openproject_git_hosting").settings[:default]

    if default_hash.nil? || default_hash.empty?
      puts "No defaults specified in init.rb!"
    else
      changes = 0
      valuehash = (Setting.plugin_openproject_git_hosting).clone
      default_hash.each do |key,value|
        if valuehash[key] != value
          puts "Changing '#{key}' : '#{valuehash[key]}' => '#{value}'\n"
          valuehash[key] = value
          changes += 1
        end
      end
      if changes == 0
        puts "No changes necessary.\n"
      else
        puts "Committing changes ... "
        begin
          Setting.plugin_openproject_git_hosting = valuehash
          puts "Success!\n"
        rescue => e
          puts "Failure.\n"
        end
      end
    end
    puts "Done!"
  end


  desc "Update/repair Gitolite configuration"
  task :update_repositories => [:environment] do
    puts "Performing manual update_repositories operation..."
    RedmineGitolite::GitHosting.logger.warn { "Performing manual update_repositories operation from command line" }

    projects = Project.active_or_archived.find(:all, :include => :repositories)
    if projects.length > 0
      RedmineGitolite::GitHosting.logger.info { "Resync all projects (#{projects.length})..." }
      RedmineGitolite::GitHosting.resync_gitolite({ :command => :update_all_projects, :object => projects.length })
    end

    puts "Done!"
  end


  desc "Fetch commits from gitolite repositories/update gitolite configuration"
  task :fetch_changesets => [:environment] do
    puts "Performing manual fetch_changesets operation..."
    RedmineGitolite::GitHosting.logger.warn { "Performing manual fetch_changesets operation from command line" }
    Repository.fetch_changesets
    puts "Done!"
  end


  desc "Check repositories identifier uniqueness"
  task :check_repository_uniqueness => [:environment] do
    puts "Checking repositories identifier uniqueness..."
    if Repository::Git.have_duplicated_identifier?
      # Oops -- have duplication.
      RedmineGitolite::GitHosting.logger.error { "Detected non-unique repository identifiers!" }
      puts "Detected non-unique repository identifiers!"
    else
      puts "pass!"
    end
    puts "Done!"
  end


  desc "Install openproject_git_hosting scripts"
  task :install_scripts do |t,args|
    if !ENV["READ_ONLY"]
      ENV["READ_ONLY"] = "false"
    end
    Rake::Task["selinux:openproject_git_hosting:install_scripts"].invoke
  end


  desc "Remove openproject_git_hosting scripts"
  task :remove_scripts do
    Rake::Task["selinux:openproject_git_hosting:remove_scripts"].invoke
  end

end

# Produce date string of form used by redmine logs
def my_date
  Time.now.strftime("%Y-%m-%d %H:%M:%S")
end
