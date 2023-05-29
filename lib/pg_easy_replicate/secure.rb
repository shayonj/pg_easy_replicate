# frozen_string_literal: true

module PgEasyReplicate
  class Secure
    class << self
      def generate_key
        SecureRandom.hex(16)
      end

      def encrypt(key, string)
        cipher = OpenSSL::Cipher.new("aes-256-cbc").encrypt
        cipher.key = key
        cipher.update(string) + cipher.final
      end

      def decrypt(key, ciphertext)
        cipher = OpenSSL::Cipher.new("aes-256-cbc").decrypt
        cipher.key = key
        cipher.update(ciphertext) + cipher.final
      end
    end
  end
end
