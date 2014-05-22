class RepositoryGitNotification < ActiveRecord::Base
  unloadable

  belongs_to :repository

  serialize :include_list, Array
  serialize :exclude_list, Array

  validate :validate_mailing_list

  validates_format_of :sender_address, :with => /^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i, :allow_blank => true

  after_commit ->(obj) { obj.update_repository }, on: :create
  after_commit ->(obj) { obj.update_repository }, on: :update
  after_commit ->(obj) { obj.update_repository }, on: :destroy


  protected


  def update_repository
    OpenProject::GitHosting::GitHosting.logger.info("Rebuild mailing list for respository : '#{repository.gitolite_repository_name}'")
    OpenProject::GitHosting::GitoliteWrapper.update(:update_repository, repository.id)
  end


  private


  def validate_mailing_list
    include_list.each do |item|
      errors.add(:include_list, 'not a valid email') unless item =~ /^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i
    end

    exclude_list.each do |item|
      errors.add(:exclude_list, 'not a valid email') unless item =~ /^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i
    end

    intersection = include_list & exclude_list
    if intersection.length.to_i > 0
      errors.add(:repository_git_notification, 'the same address is defined twice')
    end
  end


end
