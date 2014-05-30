module OpenProject::GitHosting
  module Patches
    module RolesControllerPatch

      def self.included(base)
        base.class_eval do
          unloadable

          include InstanceMethods
          
          alias_method_chain :create,      :git_hosting
          alias_method_chain :update,      :git_hosting
          alias_method_chain :destroy,     :git_hosting
          # TODO
          # alias_method_chain :permissions, :git_hosting
        end
      end


      module InstanceMethods

        def create_with_git_hosting(&block)
          # Do actual update
          create_without_git_hosting(&block)
          resync_gitolite('created')
        end


        def update_with_git_hosting(&block)
          # Do actual update
          update_without_git_hosting(&block)
          resync_gitolite('modified')
        end


        def destroy_with_git_hosting(&block)
          # Do actual update
          destroy_without_git_hosting(&block)
          resync_gitolite('deleted')
        end


        def permissions_with_git_hosting(&block)
          # Do actual update
          permissions_without_git_hosting(&block)

          if request.post?
            resync_gitolite('modified')
          end
        end


        private


        def resync_gitolite(message)
          projects = Project.active_or_archived.includes(:repositories).all
          if projects.length > 0
            OpenProject::GitHosting::GitHosting.logger.info("Role has been #{message}, resync all projects...")
            OpenProject::GitHosting::GitoliteWrapper.update(:update_all_projects, projects.length)
          end
        end

      end

    end
  end
end

RolesController.send(:include, OpenProject::GitHosting::Patches::RolesControllerPatch)
