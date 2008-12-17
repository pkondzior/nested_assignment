# NestedAssignment
module NestedAssignment
  include NestedAssignment::RecursionControl

  def self.included(base)
    base.class_eval do
      extend ClassMethods
      
      alias_method_chain :create_or_update, :associated
      alias_method_chain :valid?, :associated
      #      alias_method_chain :changed?, :associated
    end
  end

  module ClassMethods
    # Parallels attr_accessible. Could easily trigger from an association option (e.g. :accessible => true)
    # or even from attr_accessible itself (cool!).
    def accessible_associations(*associations)
      associations.each do |name|
        if association_reflection = self.reflect_on_association(name)
          self.reflect_on_accessible_associations << association_reflection
          # singular associations
          if [:belongs_to, :has_one].include?(association_reflection.macro)
            define_method("#{name}_params=") do |attributes|
              if row[:_destroy].to_s == "1" && associated_record = self.send(name)
                associated_record.destroy
              else
                associated_record = self.send(name) || self.send("build_#{name}")
                associated_record.attributes = attributes.except(:id, :_destroy)
              end
            end
            # plural collections
          else
            define_method("#{name}_params=") do |hash|

#              puts hash.inspect
#              assoc = self.send(name)
#
#              hash.values.each do |row|
#                if row[:_delete].to_s == "1"
#                  assoc.detect{|r| r.id == row[:id].to_i}._delete = true if row[:id]
#                else
#                  record = row[:id].blank? ? assoc.build : assoc.detect{|r| r.id == row[:id].to_i}
#                  record.attributes = row.except(:id, :_delete)
#                end
#              end
            end
          end
        end
      end
    end
  
    def association_names
      @association_names ||= reflect_on_all_associations.map(&:name)
    end

    def reflect_on_accessible_associations
      @accessible_associations ||= []
    end
  end
  
  # marks the (associated) record to be deleted in the next deep save
  attr_accessor :_delete
  
  # deep validation of any changed (existing) records.
  # makes sure that any single invalid record will not halt the
  # validation process, so that all errors will be available
  # afterwards.
  def valid_with_associated?(*args)
    without_recursion(:valid?) do
      [modified_associated.all?(&:valid?), valid_without_associated?(*args)].all?
    end
  end
  
  # deep saving of any new, changed, or deleted records.
  def create_or_update_with_associated(*args)
    self.class.transaction do
      create_or_update_without_associated(*args) &&
        without_recursion(:create_or_update){modified_associated.all?{|a| a.save(*args)}} &&
        deletable_associated.all?{|a| a.destroy}
    end
  end
  
  # Without this, we may not save deeply nested and changed records.
  # For example, suppose that User -> Task -> Tags, and that we change
  # an attribute on a tag but not on the task. Then when we are saving
  # the user, we would want to say that the task had changed so we
  # could then recurse and discover that the tag had changed.
  #
  # Unfortunately, this can also have a 2x performance penalty.
  def changed_with_associated?
    without_recursion(:changed) do
      changed_without_associated? or changed_associated
    end
  end
  
  protected
  
  def deletable_associated
    instantiated_associated.select{|a| a._delete}
  end

  def modified_associated
    instantiated_associated.select{|a| a.changed? and !a.new_record? and not a.id_changed?}
  end

  def changed_associated
    instantiated_associated.select{|a| a.changed?}
  end

  def instantiated_associated
    instantiated = []
    self.class.association_names.each do |name|
      ivar = "@#{name}"
      if association = instance_variable_get(ivar)
        if association.target.is_a?(Array)
          instantiated.concat(association.target)
        elsif association.target
          instantiated << association.target
        end
      end
    end
    instantiated
  end
end
