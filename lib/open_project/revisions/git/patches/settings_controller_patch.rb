module OpenProject::Revisions::Git
  module Patches
    module SettingsControllerPatch
      def self.included(base)
        base.class_eval do
          unloadable

          include InstanceMethods

          helper :revisions_git
          helper :gitolite_plugin_settings
        end
      end
      
      module InstanceMethods
        def install_gitolite_hooks
          @plugin = Redmine::Plugin.find(params[:id])
          return render_404 unless @plugin.id == :openproject_revisions_git
          #@gitolite_checks = OpenProject::Revisions::Git::Config.install_hooks!
          @gitolite_checks = OpenProject::Revisions::Git::Config.check_hooks_install!
        end
      end
      
    end
  end
end

SettingsController.send(:include, OpenProject::Revisions::Git::Patches::SettingsControllerPatch)
