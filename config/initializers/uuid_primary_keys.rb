# Automatically use UUID type for all binary(16) columns
ActiveSupport.on_load(:active_record) do
  ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter.class_eval do
    def lookup_cast_type(sql_type)
      if sql_type == "varbinary(16)"
        ActiveRecord::Type.lookup(:uuid, adapter: :trilogy)
      else
        super
      end
    end

    # Override quote to handle binary UUID values properly
    def quote(value)
      if value.is_a?(String) && value.encoding == Encoding::BINARY && value.bytesize == 16
        # Quote binary UUID as hex literal for MySQL
        "X'#{value.unpack1('H*')}'"
      else
        super
      end
    end
  end

  # Fix schema dumper to include limit for binary columns
  module SchemaDumperBinaryLimit
    def prepare_column_options(column)
      spec = super
      # Ensure binary columns with limits always include them in schema
      if column.type == :binary && column.sql_type =~ /varbinary\((\d+)\)/
        spec[:limit] = $1.to_i
      end
      spec
    end
  end

  ActiveRecord::ConnectionAdapters::MySQL::SchemaDumper.prepend(SchemaDumperBinaryLimit)
end

# Automatically convert :uuid to binary(16) for primary keys and columns
module ActiveRecord
  module ConnectionAdapters
    class TableDefinition
      alias_method :original_set_primary_key, :set_primary_key

      def set_primary_key(table_name, id, primary_key, **options)
        # Convert :uuid to :binary with limit 16
        if id == :uuid
          id = :binary
          options[:limit] = 16
        elsif id.is_a?(Hash) && id[:type] == :uuid
          id[:type] = :binary
          id[:limit] = 16
        end

        original_set_primary_key(table_name, id, primary_key, **options)
      end

      alias_method :original_column, :column

      def column(name, type, **options)
        # Convert :uuid to :binary with limit 16 for regular columns too
        if type == :uuid
          type = :binary
          options[:limit] = 16
        end

        original_column(name, type, **options)
      end

      # Define uuid as a column type method (like string, integer, etc.)
      def uuid(name, **options)
        column(name, :uuid, **options)
      end
    end
  end
end
