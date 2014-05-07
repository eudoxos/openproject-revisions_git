class AddSettingsToPlugin2 < ActiveRecord::Migration
  def self.up
    begin
      # Add some new settings to settings page, if they don't exist
      valuehash = (Setting.plugin_openproject_git_hosting).clone
      valuehash['httpServerSubdir'] ||= ''
      valuehash['gitRedmineSubdir'] ||= ''
      valuehash['gitRepositoryHierarchy'] ||= 'true'

      # Fix httpServer by removing directory components
      valuehash['httpServer'] = (valuehash['httpServer'][/^[^\/]*/])

      if (Setting.plugin_openproject_git_hosting != valuehash)
        say "Added openproject_git_hosting settings: 'httpServerSubdir', 'gitRedmineSubdir', 'gitRepositoryHierarchy'"
        if (Setting.plugin_openproject_git_hosting['httpServer'] != valuehash['httpServer'])
          say "Updated 'httpServer' from '#{Setting.plugin_openproject_git_hosting['httpServer']}' to '#{valuehash['httpServer']}'."
        end
        Setting.plugin_openproject_git_hosting = valuehash
      end
    rescue => e
      puts e.message
    end
  end

  def self.down
    begin
      # Remove above settings from plugin page
      valuehash = (Setting.plugin_openproject_git_hosting).clone
      valuehash.delete('httpServerSubdir')
      valuehash.delete('gitRedmineSubdir')
      valuehash.delete('gitRepositoryHierarchy')

      # Restore redmine root directory to httpServer (remove trailing '/')
      valuehash['httpServer'] = RedmineGitolite::Config.my_root_url

      if (Setting.plugin_openproject_git_hosting != valuehash)
        say "Removed openproject_git_hosting settings: 'httpServerSubdir', 'gitRedmineSubdir', 'gitRepositoryHierarchy'"
        if (Setting.plugin_openproject_git_hosting['httpServer'] != valuehash['httpServer'])
          say "Updated 'httpServer' from '#{Setting.plugin_openproject_git_hosting['httpServer']}' to '#{valuehash['httpServer']}'."
        end
        Setting.plugin_openproject_git_hosting = valuehash
      end
    rescue => e
      puts e.message
    end
  end
end
