module GitHostingHelper

  include Redmine::I18n

  def checked_image2(checked=true)
    if checked
      image_tag 'toggle_check.png'
    else
      image_tag 'exclamation.png'
    end
  end


  def user_allowed_to(permission, project)
    if project.active?
      return User.current.allowed_to?(permission, project)
    else
      return User.current.allowed_to?(permission, nil, :global => true)
    end
  end


  # Post-receive Mode
  def post_receive_mode(prurl)
    if prurl.active == 0
      l(:label_mirror_inactive)
    elsif prurl.mode == :github
      l(:label_github_post)
    else
      l(:label_empty_get)
    end
  end


  # Mirror Mode
  def mirror_mode(mirror)
    if mirror.active == 0
      l(:label_mirror_inactive)
    else
      [l(:label_mirror), l(:label_forced), l(:label_unforced)][mirror.push_mode]
    end
  end


  # Refspec for mirrors
  def refspec(mirror, max_refspec = 0)
    if mirror.push_mode == RepositoryMirror::PUSHMODE_MIRROR
      l(:all_references)
    else
      result = []
      result << l(:all_branches) if mirror.include_all_branches
      result << l(:all_tags) if mirror.include_all_tags
      result << mirror.explicit_refspec if (max_refspec == 0) || ((1..max_refspec) === mirror.explicit_refspec.length)
      result << l(:explicit) if (max_refspec > 0) && (mirror.explicit_refspec.length > max_refspec)
      result.join(",<br />")
    end
  end


  def plugin_asset_link(asset_name)
    File.join(Redmine::Utils.relative_url_root, 'plugin_assets', 'openproject_git_hosting', 'images', asset_name)
  end


  # Generic helper functions
  def reldir_add_dotslash(path)
    # Is this a relative path?
    stripped = (path || "").lstrip.rstrip
    norm = File.expand_path(stripped, "/")
    ((stripped[0, 1] != "/") ? '.' : '') + norm + ((norm[-1, 1] != "/") ? "/" : "")
  end

end
