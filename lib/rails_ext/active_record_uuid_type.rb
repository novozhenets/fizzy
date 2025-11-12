# Custom UUID attribute type for MySQL binary storage with base36 string representation
module ActiveRecord
  module Type
    class Uuid < Binary
      BASE36_LENGTH = 25 # 36^25 > 2^128

      def self.generate
        uuid = SecureRandom.uuid_v7
        hex = uuid.delete("-")
        hex.to_i(16).to_s(36).rjust(25, "0")
      end

      def serialize(value)
        return unless value

        hex = value.to_s.to_i(36).to_s(16).rjust(32, "0")
        binary = hex.scan(/../).map(&:hex).pack("C*")
        binary.force_encoding(Encoding::BINARY)
      end

      def deserialize(value)
        return unless value

        hex = value.unpack1("H*")
        hex.to_i(16).to_s(36).rjust(BASE36_LENGTH, "0")
      end

      def cast(value)
        deserialize(serialize(value))
      end

    end
  end
end

# Register the UUID type for Trilogy adapter
ActiveRecord::Type.register(:uuid, ActiveRecord::Type::Uuid, adapter: :trilogy)
