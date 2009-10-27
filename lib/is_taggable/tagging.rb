class Tagging < ActiveRecord::Base
  belongs_to :tag
  belongs_to :taggable, :polymorphic => true
  belongs_to :user, :polymorphic => true
  
  before_create :set_tagging_user
  
  def set_tagging_user
    self.user = Thread.current[:is_taggable_user] if Thread.current[:is_taggable_user]
    nil # prevent stopping callback chains
  end
end
