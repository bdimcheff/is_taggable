class Tag < ActiveRecord::Base
  class << self
    def find_or_initialize_with_name_like_and_kind(name, kind)
      with_name_like_and_kind(name, kind).first || new(:name => name, :kind => kind)
    end
  end

  has_many :taggings, :dependent => :destroy

  validates_presence_of :name
  validates_uniqueness_of :name, :scope => :kind

  named_scope :with_name_like_and_kind, lambda { |name, kind| { :conditions => ["name like ? AND kind = ?", name, kind] } }
  named_scope :of_kind,                 lambda { |kind| { :conditions => {:kind => kind} } }
  named_scope :by_user, lambda { |user|
    if user
      {:include => :taggings, :conditions => ["taggings.user_id = ? AND taggings.user_type = ?", user.id, user.class.to_s]}
    else
      {:include => :taggings, :conditions => ["taggings.user_id IS NULL"]}
    end
  }
  named_scope :no_user, :include => :taggings, :conditions => ["taggings.user_id IS NULL"]
end
