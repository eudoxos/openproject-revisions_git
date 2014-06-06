module ArchivedRepositoriesHelper

  def link_to_revision2(revision, repository, options={})
    if repository.is_a?(Project)
      repository = repository.repository
    end
    text = options.delete(:text) || format_revision(revision)
    rev = revision.respond_to?(:identifier) ? revision.identifier : revision
    link_to(
        h(text),
        {:controller => 'archived_repositories', :action => 'revision', :id => repository.project, :repository_id => repository.id, :rev => rev},
        :title => l(:label_revision_id, format_revision(revision))
      )
  end

end
