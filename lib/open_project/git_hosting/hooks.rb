require 'digest/md5'

module OpenProject::GitHosting
  class Hook < Redmine::Hook::Listener

    GITOLITE_HOOKS_DIR       = '~/.gitolite/hooks/common'
    GITOLITE_HOOKS_NAMESPACE = 'redminegitolite'

    POST_RECEIVE_HOOK_DIR    = File.join(GITOLITE_HOOKS_DIR, 'post-receive.d')
    PACKAGE_HOOKS_DIR        = File.join(File.dirname(File.dirname(File.dirname(__FILE__))), 'contrib', 'hooks')

    POST_RECEIVE_HOOKS    = {
      'post-receive.redmine_gitolite.rb'   => { :source => 'post-receive.redmine_gitolite.rb',   :destination => 'post-receive',                      :executable => true },
      'post-receive.git_multimail.py'      => { :source => 'post-receive.git_multimail.py',      :destination => 'post-receive.d/git_multimail.py',   :executable => false },
      'post-receive.mail_notifications.py' => { :source => 'post-receive.mail_notifications.py', :destination => 'post-receive.d/mail_notifications', :executable => true }
    }


    attr_accessor :gitolite_hooks_url
    attr_accessor :gitolite_hooks_namespace


    def initialize
      @gitolite_command   = RedmineGitolite::Config.gitolite_command
      @gitolite_hooks_url = RedmineGitolite::Config.gitolite_hooks_url
      @debug_mode         = RedmineGitolite::ConfigRedmine.get_setting(:gitolite_hooks_debug, true)
      @async_mode         = RedmineGitolite::ConfigRedmine.get_setting(:gitolite_hooks_are_asynchronous, true)
      @force_hooks_update = RedmineGitolite::ConfigRedmine.get_setting(:gitolite_force_hooks_update, true)

      @global_hook_params = get_global_hooks_params
      @gitolite_hooks_namespace = GITOLITE_HOOKS_NAMESPACE
    end


    def check_install
      return [ hooks_installed?, hook_params_installed? ]
    end


    def hooks_installed?
      installed = {}

      installed['post-receive.d'] = check_hook_dir_installed

      POST_RECEIVE_HOOKS.each do |hook|
        installed[hook[0]] = check_hook_file_installed(hook)
      end

      return installed
    end


    def hook_params_installed?
      installed = {}

      if @global_hook_params["redmineurl"] != @gitolite_hooks_url
        installed['redmineurl'] = set_hook_param("redmineurl", @gitolite_hooks_url)
      else
        installed['redmineurl'] = true
      end

      if @global_hook_params["debugmode"] != @debug_mode.to_s
        installed['debugmode'] = set_hook_param("debugmode", @debug_mode)
      else
        installed['debugmode'] = true
      end

      if @global_hook_params["asyncmode"] != @async_mode.to_s
        installed['asyncmode'] = set_hook_param("asyncmode", @async_mode)
      else
        installed['asyncmode'] = true
      end

      return installed
    end


    private


    def logger
      RedmineGitolite::Log.get_logger(:global)
    end


    ###############################
    ##                           ##
    ##         HOOKS DIR         ##
    ##                           ##
    ###############################


    @@check_hooks_dir_installed_cached = nil
    @@check_hooks_dir_installed_stamp = nil


    def check_hook_dir_installed
      if !@@check_hooks_dir_installed_cached.nil? && (Time.new - @@check_hooks_dir_installed_stamp <= 1)
        return @@check_hooks_dir_installed_cached
      end

      hook_dir_exists = RedmineGitolite::GitHosting.execute_command(:shell_cmd, "test -r '#{POST_RECEIVE_HOOK_DIR}' && echo 'yes' || echo 'no'").match(/yes/)

      if !hook_dir_exists
        logger.info { "Global hook directory '#{POST_RECEIVE_HOOK_DIR}' not created yet, installing it..." }

        if install_hooks_dir(POST_RECEIVE_HOOK_DIR)
          logger.info { "Global hook directory '#{POST_RECEIVE_HOOK_DIR}' installed" }
          @@check_hooks_dir_installed_cached = true
        else
          @@check_hooks_dir_installed_cached = false
        end

        @@check_hooks_dir_installed_stamp = Time.new
      else
        logger.info { "Global hook directory '#{POST_RECEIVE_HOOK_DIR}' is already present, will not touch it !" }
        @@check_hooks_dir_installed_cached = true
        @@check_hooks_dir_installed_stamp = Time.new
      end

      return @@check_hooks_dir_installed_cached
    end


    def install_hooks_dir(hook_dir)
      logger.info { "Installing hook directory '#{hook_dir}'" }

      begin
        RedmineGitolite::GitHosting.execute_command(:shell_cmd, "mkdir -p '#{hook_dir}'")
        RedmineGitolite::GitHosting.execute_command(:shell_cmd, "chmod 755 '#{hook_dir}'")
        return true
      rescue => e
        logger.error { "Problems installing hook directory '#{hook_dir}'" }
        return false
      end
    end


    ###############################
    ##                           ##
    ##         HOOK FILES        ##
    ##                           ##
    ###############################


    @@check_hooks_installed_stamp = {}
    @@check_hooks_installed_cached = {}
    @@post_receive_hook_path = {}


    def check_hook_file_installed(hook)

      hook_name = hook[0]
      hook_data = hook[1]

      if !@@check_hooks_installed_cached[hook_name].nil? && (Time.new - @@check_hooks_installed_stamp[hook_name] <= 1)
        return @@check_hooks_installed_cached[hook_name]
      end

      if @gitolite_command.nil?
        logger.error { "Unable to find Gitolite version, cannot install '#{hook_name}' hook file !" }
        @@check_hooks_installed_stamp[hook_name] = Time.new
        @@check_hooks_installed_cached[hook_name] = false
        return @@check_hooks_installed_cached[hook_name]
      end

      @@post_receive_hook_path[hook_name] ||= File.join(GITOLITE_HOOKS_DIR, hook_data[:destination])

      if !hook_exists?(@@post_receive_hook_path[hook_name])

        logger.info { "Hook '#{hook_name}' does not exist, installing it ..." }

        if install_hook_file(hook_data)
          logger.info { "Hook '#{hook_name}' installed" }
          logger.info { "Running '#{@gitolite_command}' on the Gitolite install ..." }

          if update_gitolite
            @@check_hooks_installed_cached[hook_name] = true
          else
            @@check_hooks_installed_cached[hook_name] = false
          end
        else
          @@check_hooks_installed_cached[hook_name] = false
        end

        @@check_hooks_installed_stamp[hook_name] = Time.new
        return @@check_hooks_installed_cached[hook_name]

      else

        content = RedmineGitolite::GitHosting.execute_command(:shell_cmd, "cat '#{@@post_receive_hook_path[hook_name]}'") rescue ''
        digest = Digest::MD5.hexdigest(content)

        if hook_digest(hook_data) == digest
          logger.info { "Our '#{hook_name}' hook is already installed" }
          @@check_hooks_installed_stamp[hook_name] = Time.new
          @@check_hooks_installed_cached[hook_name] = true
          return @@check_hooks_installed_cached[hook_name]

        else

          error_msg = "Hook '#{hook_name}' is already present but it's not ours!"
          logger.warn { error_msg }
          @@check_hooks_installed_cached[hook_name] = error_msg

          if @force_hooks_update
            logger.info { "Restoring '#{hook_name}' hook since forceInstallHook == true" }

            if install_hook_file(hook_data)
              logger.info { "Hook '#{hook_name}' installed" }
              logger.info { "Running '#{@gitolite_command}' on the Gitolite install..." }

              if update_gitolite
                @@check_hooks_installed_cached[hook_name] = true
              else
                @@check_hooks_installed_cached[hook_name] = false
              end
            else
              @@check_hooks_installed_cached[hook_name] = false
            end
          end

          @@check_hooks_installed_stamp[hook_name] = Time.new
          return @@check_hooks_installed_cached[hook_name]
        end

      end
    end


    def install_hook_file(hook_data)
      source_path      = File.join(PACKAGE_HOOKS_DIR, hook_data[:source])
      destination_path = File.join(GITOLITE_HOOKS_DIR, hook_data[:destination])

      if hook_data[:executable]
        filemode = 755
      else
        filemode = 644
      end

      logger.info { "Installing hook '#{source_path}' in '#{destination_path}'" }

      begin
        RedmineGitolite::GitHosting.execute_command(:shell_cmd, "'cat - > #{destination_path}'", :pipe_data => "'#{source_path}'", :pipe_command => 'cat')
        RedmineGitolite::GitHosting.execute_command(:shell_cmd, "chmod #{filemode} '#{destination_path}'")
        return true
      rescue => e
        logger.error { "Problems installing hook from '#{source_path}' in '#{destination_path}'" }
        return false
      end
    end


    def hook_digest(hook_data)
      hook_name   = hook_data[:source]
      source_path = File.join(PACKAGE_HOOKS_DIR, hook_data[:source])

      digest = Digest::MD5.hexdigest(File.read(source_path))
      logger.debug "Digest for '#{hook_name}' hook : #{digest}"

      return digest
    end


    def update_gitolite
      begin
        RedmineGitolite::GitHosting.execute_command(:shell_cmd, @gitolite_command)
        return true
      rescue RedmineGitolite::GitHosting::GitHostingException => e
        return false
      end
    end


    def hook_exists?(hook_path)
      begin
        RedmineGitolite::GitHosting.execute_command(:shell_cmd, "test -s '#{hook_path}' && echo 'yes' || echo 'no'").match(/yes/) ? true : false
      rescue RedmineGitolite::GitHosting::GitHostingException => e
        return false
      end
    end


    # Return a hash with global config parameters.
    def get_global_hooks_params
      begin
        hooks_params = RedmineGitolite::GitHosting.execute_command(:git_cmd, "config -f .gitconfig --get-regexp #{GITOLITE_HOOKS_NAMESPACE}").split("\n")
      rescue RedmineGitolite::GitHosting::GitHostingException => e
        logger.error { "Problems to retrieve Gitolite hook parameters in Gitolite config" }
        hooks_params = []
      end

      value_hash = {}

      hooks_params.each do |value_pair|
        global_key = value_pair.split(' ')[0]
        namespace  = global_key.split('.')[0]
        key        = global_key.split('.')[1]
        value      = value_pair.split(' ')[1]

        if namespace == GITOLITE_HOOKS_NAMESPACE
          value_hash[key] = value
        end
      end

      return value_hash
    end


    def set_hook_param(name, value)
      logger.info { "Set Git hooks global parameter : #{name} (#{value})" }

      begin
        RedmineGitolite::GitHosting.execute_command(:git_cmd, "config --global #{GITOLITE_HOOKS_NAMESPACE}.#{name} '#{value}'")
        return true
      rescue RedmineGitolite::GitHosting::GitHostingException => e
        logger.error { "Error while setting Git hooks global parameter : #{name} (#{value})" }
        return false
      end

    end

  end
end
