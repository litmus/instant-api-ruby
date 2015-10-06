require "spec_helper"
require "securerandom"

describe Litmus::Instant do
  it "has a version number" do
    expect(Litmus::Instant::VERSION).not_to be nil
  end

  describe "module methods" do
    it "has an api_key setter" do
      expect {
        Litmus::Instant.api_key = "foo"
      }.not_to raise_error

      expect(Litmus::Instant.api_key).to eq "foo"

      # don't leave the key set
      Litmus::Instant.default_options.delete :basic_auth
    end
  end

  describe ".create_email" do
    let(:valid_email) { { plain_text: "Hej världen!" } }
    let(:invalid_email) { { nyan_text: "Miow världen!" } }

    context "unauthenticated", authenticated: false do
      it "raises an authentication error" do
        expect { Litmus::Instant.create_email(valid_email) }.to(
          raise_error(Litmus::Instant::AuthenticationError)
        )
      end
    end

    context "authenticated", authenticated: true do
      context "with valid email Hash" do
        describe "response" do
          subject(:response) { Litmus::Instant.create_email(valid_email) }

          it { is_expected.to be_a Hash }
          it { is_expected.to have_key "email_guid" }
        end

        describe "optional end_user_id" do
          pending
        end

        describe "prerequest configurations" do
          pending
        end
      end

      context "with invalid email Hash" do
        it "raise a request error" do
          expect { Litmus::Instant.create_email(invalid_email) }.to(
            raise_error(Litmus::Instant::RequestError)
          )
        end
      end
    end
  end

  let(:email_guid) do
    with_authentication do
      Litmus::Instant.create_email(
        plain_text: "Hej världen! Kärlek, den svenska kocken."
      )["email_guid"]
    end
  end
  # random is equivalent to expired, everything unknown is treated the same
  let(:expired_email_guid) { SecureRandom.uuid }

  describe ".clients" do
    it "returns an array of client names" do
      response = Litmus::Instant.clients
      expect(response).to be_an Array
      expect(response).to include "OL2010"
    end
  end

  describe ".client_configurations" do
    it "returns a Hash of clients and their available options" do
      response = Litmus::Instant.client_configurations
      expect(response).to be_a Hash
      expect(response).to have_key "OL2010"
      sample_config = response["OL2010"]
      expect(sample_config).to be_a Hash
      expect(sample_config).to have_key "orientation_options"
      expect(sample_config).to have_key "images_options"
    end
  end

  describe ".get_preview" do
    it "raises RequestError for an invalid email_guid" do
      expect {
        Litmus::Instant.get_preview("NOT-A-GUID", "PLAINTEXT")
      }.to raise_error(Litmus::Instant::RequestError)
    end

    it "raises RequestError for an invalid client" do
      expect {
        Litmus::Instant.get_preview(email_guid, "OL2001MYSPACEODYSSEY")
      }.to raise_error(Litmus::Instant::RequestError)
    end

    it "raises NotFound for an expired email_guid" do
      expect {
        Litmus::Instant.get_preview(expired_email_guid, "OL2010")
      }.to raise_error(Litmus::Instant::NotFound)
    end

    it "returns a Hash of the image types" do
      response = Litmus::Instant.get_preview(email_guid, "PLAINTEXT")
      expect(response).to be_a Hash
      expect(response.keys).to include *%w(full_url thumb_url thumb450_url)
    end

  end

  describe ".prefetch_previews" do
    it "raises RequestError if any invalid configurations are present" do
      expect {
        Litmus::Instant.prefetch_previews(
          email_guid,
          [
            { client: "OL2010" },
            { client: "OL2001MYSPACEODYSSEY" }
          ]
        )
      }.to raise_error(Litmus::Instant::RequestError)
    end

    it "raises RequestError for an invalid email_guid" do
      expect {
        Litmus::Instant.prefetch_previews(
          "NOT-A-GUID",
          [
            { client: "OL2010" }
          ]
        )
      }.to raise_error(Litmus::Instant::RequestError)
    end

    it "responds with an array of the requested configurations" do
      response = Litmus::Instant.prefetch_previews(
        email_guid,
        [
          { client: "OL2010", images: "allowed" },
          { client: "IPAD", orientation: "vertical" }
        ]
      )
      expect(response).to have_key "configurations"
      expect(response["configurations"]).to be_an Array
      # The API relays the full configs, including any defaults inferred
      expect(response["configurations"]).to include(
        { "client" => "OL2010", "images" => "allowed", "orientation" => "vertical" }
      )
    end
  end

  describe ".preview_image_url" do
    describe "simple case" do
      subject(:result) {  Litmus::Instant::preview_image_url("FAKE-EMAIL-GUID", "FAKE-CLIENT") }
      it { is_expected.to eq "https://FAKE-CLIENT.instant-api.litmus.com/v1/emails/FAKE-EMAIL-GUID/previews/FAKE-CLIENT/full" }
    end

    describe "with optional configuration" do
      it "adds the appropriate query parameters" do
        pending
        fail
      end
    end

    describe "with fallback_url" do
      it "includes the URL encoded fallback url" do
        pending
        fail
      end
    end
  end
end
