require File.dirname(__FILE__) + '/test_helper'

Expectations do
  expect Tag do
    Post.new.tags.build
  end

  expect Tagging do
    Post.new.taggings.build
  end
  
  expect ["is_taggable", "has 'tags' by default"] do
    n = Comment.new :tag_list => "is_taggable, has 'tags' by default"
    n.tag_list
  end
  
  expect ["one", "two"] do
    IsTaggable::TagList.delimiter = " "
    n = Comment.new :tag_list => "one two"
    IsTaggable::TagList.delimiter = "," # puts things back to avoid breaking following tests
    n.tag_list
  end

  expect ["something cool", "something else cool"] do
    p = Post.new :tag_list => "something cool, something else cool"
    p.tag_list
  end

  expect ["something cool", "something new"] do
    p = Post.new :tag_list => "something cool, something else cool"
    p.save!
    p.tag_list = "something cool, something new"
    p.save!
    p.tags.reload
    p.instance_variable_set("@tag_list", nil)
    p.tag_list
  end

  expect ["english", "french"] do
    p = Post.new :language_list => "english, french"
    p.save!
    p.tags.reload
    p.instance_variable_set("@language_list", nil)
    p.language_list
  end

  expect ["english", "french"] do
    p = Post.new :language_list => "english, french"
    p.language_list
  end

  expect "english,french" do
    p = Post.new :language_list => "english, french"
    p.language_list.to_s
  end
  
  # added - should clean up strings with arbitrary spaces around commas
  expect ["spaces","should","not","matter"] do
    p = Post.new
    p.tag_list = "spaces,should,  not,matter"
    p.save!
    p.tags.reload
    p.tag_list
  end

  expect ["blank","topics","should be ignored"] do
    p = Post.new
    p.tag_list = "blank, topics, should be ignored, "
    p.save!
    p.tags.reload
    p.tag_list
  end

  expect 2 do
    p = Post.new :language_list => "english, french"
    p.save!
    p.tags.length
  end

  expect ["foo", "bar"] do
    Tag.create(:name => 'foo', :kind => 'category')
    Tag.create(:name => 'bar', :kind => 'category')

    p = Page.new
    p.category_list = "foo, bar, baz"
    p.save!
    p.tags.reload
    p.category_list
  end
end


class IsTaggableTest < Test::Unit::TestCase
  should "tag things as a specified user" do
    u = User.create
    p = Post.new
    
    p.tag_as_user(u) do
      p.tag_list = "foo, bar"
      p.save
    end
    
    assert_equal 2, p.taggings.size
    
    p.taggings.each do |tagging|
      assert_equal u, tagging.user
    end
  end
  
  should "only effect things that happen within the block" do
    u = User.create
    p = Post.new
    
    p.tag_as_user(u) do
      p.tag_list = "foo, bar"
      p.save
    end

    p.tag_list = "baz, quux"
    p.save
    
    assert_equal 4, p.taggings.size

    taggings = p.tags.inject({}) do |h,t| 
      h[t.name] = t.taggings.find(:first, :conditions => {:taggable_id => p, :taggable_type => "Post"})
      h
    end

    assert_equal u,   taggings["foo"].user
    assert_equal u,   taggings["bar"].user
    assert_equal nil, taggings["baz"].user
    assert_equal nil, taggings["quux"].user
  end
  
  should "allow different users to tag things the same" do
    u1 = User.create
    u2 = User.create
    p = Post.new
    
    p.tag_as_user(u1) do
      p.tag_list = "foo, bar"
      p.save
    end
    
    p.tag_as_user(u2) do
      p.tag_list = "bar, baz"
      p.save
    end
    
    assert_equal 4, p.taggings.size
  end

  should "return the current user's tag_list" do
    u1 = User.create
    u2 = User.create
    p = Post.new
    
    p.tag_as_user(u1) do
      p.tag_list = "foo, bar"
      p.save
    end
    
    p.tag_as_user(u2) do
      p.tag_list = "bar, baz"
      p.save
    end

    p.tag_as_user(u1) do
      assert_equal ["foo", "bar"], p.tag_list
    end

    p.tag_as_user(u2) do
      assert_equal ["bar", "baz"], p.tag_list
    end

    assert_equal [], p.tag_list
  end
  
  should "return the tag list inside a block after calling outside a block" do
    u = User.create
    p = Post.new
    
    p.tag_list = "baz, quux"
    p.save
    
    p.tag_as_user(u) do
      p.tag_list = "foo, bar"
      p.save
    end

    assert_equal ["baz", "quux"], p.tag_list
    
    p.tag_as_user(u) do
      assert_equal ["foo", "bar"], p.tag_list
    end
    
    assert_equal 4, p.taggings.size
  end
end
