# frozen_string_literal: true

RSpec.describe(PgEasyReplicate::Secure) do
  let(:string) do
    "postgres://UserName@!#$%*':\"'-!~Password@YourHostname:5432/YourDatabaseName"
  end

  describe ".generate_key" do
    it "has a secure string number" do
      expect(described_class.generate_key).to be_a(String)
    end
  end

  describe ".encrypt" do
    it "succesfully" do
      key = described_class.generate_key
      expect(described_class.encrypt(key, string)).to be_a(String)
    end
  end

  describe ".decrypt" do
    it "succesfully" do
      key = described_class.generate_key
      cipher = described_class.encrypt(key, string)

      expect(described_class.decrypt(key, cipher)).to eq(string)
    end
  end
end
