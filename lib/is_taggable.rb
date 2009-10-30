path = File.expand_path(File.dirname(__FILE__))
$LOAD_PATH << path unless $LOAD_PATH.include?(path)

begin
  Tag
rescue NameError
  require 'is_taggable/tag'
end

begin
  Tagging
rescue NameError
  require 'is_taggable/tagging'
end

module IsTaggable
  class TagList < Array
    cattr_accessor :delimiter
    @@delimiter = ','
    
    def initialize(list)
      list = list.is_a?(Array) ? list : list.split(@@delimiter).collect(&:strip).reject(&:blank?)
      super
    end
    
    def to_s
      join(@@delimiter)
    end
  end

  module ActiveRecordExtension
    def is_taggable(*kinds)
      class_inheritable_accessor :tag_kinds, :tag_options
      default_options = { :fixed => false }
      self.tag_options = if kinds[-1].is_a?(Hash)
                           default_options.merge(kinds.delete_at(-1))
                         else
                           default_options
                         end
      self.tag_kinds = kinds.map(&:to_s).map(&:singularize)
      self.tag_kinds << :tag if kinds.empty?

      include IsTaggable::TaggableMethods
    end
  end

  module TaggableMethods
    def self.included(klass)
      klass.class_eval do
        include IsTaggable::TaggableMethods::InstanceMethods

        has_many   :taggings, :as      => :taggable, :dependent => :destroy
        has_many   :tags,     :through => :taggings
        attr_accessor :tag_user
        after_save :save_tags

        tag_kinds.each do |k|
          define_method("#{k}_list")  { get_tag_list(k) }
          define_method("#{k}_list=") { |new_list| set_tag_list(k, new_list) }
        end
      end
    end

    module InstanceMethods
      def set_tag_list(kind, list)
        tag_list = TagList.new(list)
        instance_variable_set(tag_list_name_for_kind(kind), tag_list)
      end

      def get_tag_list(kind)
        set_tag_list(kind, tags_of_kind_and_user(kind, tag_user).map(&:name)) if tag_list_instance_variable(kind).nil?

        tag_list_instance_variable(kind)
      end

      def tag_as_user(user)
        self.tag_user = user

        yield

        self.tag_user = nil
        reset_tag_lists
      end

      protected
      def tag_list_name_for_kind(kind)
        "@#{kind}_list"
      end
      
      def tag_list_instance_variable(kind)
        instance_variable_get(tag_list_name_for_kind(kind))
      end

      def save_tags
        tag_kinds.each do |tag_kind|
          delete_unused_tags(tag_kind)
          add_new_tags(tag_kind)
          set_tag_list(tag_kind, tags_of_kind_and_user(tag_kind, tag_user).map(&:name))
        end

        taggings.each(&:save)
      end
      
      def delete_unused_tags(tag_kind)
        tags_of_kind_and_user(tag_kind, tag_user).each { |t| tags.delete(t) unless get_tag_list(tag_kind).include?(t.name) }
      end

      def add_new_tags(tag_kind)
        tag_names = tags_of_kind_and_user(tag_kind, tag_user).map(&:name)
        
        get_tag_list(tag_kind).each do |tag_name|
          if tag_options[:fixed]
            tag = Tag.with_name_like_and_kind(tag_name, tag_kind).first unless tag_names.include?(tag_name)
          else
            tag = Tag.find_or_initialize_with_name_like_and_kind(tag_name, tag_kind) unless tag_names.include?(tag_name)
          end

          if tag
            tagging = Tagging.new(:user => tag_user, :taggable => self, :tag => tag)
            taggings << tagging
          end
        end
      end
      
      def tags_of_kind_and_user(kind, user)
        tags.of_kind(kind).by_user(user)
      end
      
      def reset_tag_lists
        tag_kinds.each do |tag_kind|
          instance_variable_set(tag_list_name_for_kind(tag_kind), nil)
        end
      end
    end
  end
end

ActiveRecord::Base.send(:extend, IsTaggable::ActiveRecordExtension)
