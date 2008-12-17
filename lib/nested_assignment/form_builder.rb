module NestedAssignment
  class FormBuilder < ActionView::Helpers::FormBuilder
    def fields_for(association_name_or_record_or_name_or_array, *args, &block)
      if association_reflection = accessible_association_reflection(association_name_or_record_or_name_or_array)
        return fields_for_with_nested_params(association_reflection, args, block)
      else
        return super(association_name_or_record_or_name_or_array, *args, &block)
      end
    end
    protected
    def accessible_association_reflection(association_name)
      if association_name
        klass = @object.class
        if klass.respond_to?(:reflect_on_accessible_associations) &&
            association_reflection = klass.reflect_on_accessible_associations.find { |ref| ref.name == association_name.to_sym }
          return association_reflection
        end
      end
    end

    def fields_for_with_nested_params(reflection, args, block)
      name = "#{object_name}[#{reflection.name}_params]"
      case reflection.macro
      when :has_one, :belongs_to
        @template.fields_for(name, @object.send(reflection.name), *args, &block)
      when :has_many, :has_and_belongs_to_many
        records = args.first.respond_to?(:new_record?) ? [args.first] : @object.send(reflection.name)
        records.map do |record|
          record_name = "#{name}[#{ record.new_record? ? new_child_id : record.id }]"
          @template.fields_for(record_name, record, *args) do |form_builder|
            block.arity == 2 ? block.call(form_builder, record) : block.call(form_builder)
          end
        end.join
      end
    end

    def new_child_id
      value = (@child_counter ||= 1)
      @child_counter += 1
      "new_#{value}"
    end
  end
end
