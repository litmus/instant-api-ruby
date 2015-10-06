require "spec_helper"
require "uri"
require "cgi"
require "rack/utils"

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
          it "is relayed" do
            response = Litmus::Instant.create_email(
              valid_email.merge(
                end_user_id: "bob"
              )
            )
            expect(response).to have_key "end_user_id"
            expect(response["end_user_id"]).to eq "bob"
          end
        end

        describe "prerequest configurations" do
          it "is relayed" do
            response = Litmus::Instant.create_email(
              valid_email.merge(
                configurations: [
                  { client: "OL2010" },
                  { client: "OL2013", images: "blocked" }
                ]
              )
            )
            expect(response).to have_key "configurations"
            expect(response["configurations"]).to be_an Array
            expect(response["configurations"]).to include(
              { "client" => "OL2010", "images" => "allowed", "orientation" => "vertical" }
            )
          end
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
  let(:expired_email_guid) { "e87c1ce1-fc66-4f7e-9eb5-00bffdd04a0f" }

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
        result = Litmus::Instant::preview_image_url(
          "FAKE-EMAIL-GUID",
          "FAKE-CLIENT",
          "full",
          orientation: "vertical",
          images: "blocked"
        )
        query_hash = Rack::Utils.parse_nested_query(URI(result).query)
        expect(query_hash["orientation"]).to eq "vertical"
        expect(query_hash["images"]).to eq "blocked"
      end

      it "URL encodes the fallback url" do
        result = Litmus::Instant::preview_image_url(
          "FAKE-EMAIL-GUID",
          "FAKE-CLIENT",
          "full",
          fallback_url: "http://placehold.it/100x100.png"
        )
        query_hash = Rack::Utils.parse_nested_query(URI(result).query)
        expect(query_hash["fallback_url"]).to eq "http%3A%2F%2Fplacehold.it%2F100x100.png"
      end
    end
  end
end
