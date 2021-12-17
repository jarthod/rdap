require "spec_helper"

describe RDAP do
  describe '.domain', :vcr do
    it "query the correct bootstrap URL and follow redirections" do
      expect(RDAP.domain("google.com")).to include({
        "objectClassName" => "domain",
        "handle" => "2138514_DOMAIN_COM-VRSN",
        "ldhName" => "GOOGLE.COM",
        "events" => [
          {"eventAction"=>"registration", "eventDate"=>"1997-09-15T04:00:00Z"},
          {"eventAction"=>"expiration", "eventDate"=>instance_of(String)},
          {"eventAction"=>"last update of RDAP database", "eventDate"=>instance_of(String)}
        ],
        "nameservers" => [
          {"objectClassName" => "nameserver", "ldhName" => "NS1.GOOGLE.COM"},
          {"objectClassName" => "nameserver", "ldhName" => "NS2.GOOGLE.COM"},
          {"objectClassName" => "nameserver", "ldhName" => "NS3.GOOGLE.COM"},
          {"objectClassName" => "nameserver", "ldhName" => "NS4.GOOGLE.COM"}
        ],
        "rdapConformance"=> ["rdap_level_0", "icann_rdap_technical_implementation_guide_0", "icann_rdap_response_profile_0"],
      })
      expect(WebMock).to have_requested(:get, 'https://rdap.org/domain/google.com').once
      expect(WebMock).to have_requested(:get, 'https://rdap.verisign.com/com/v1/domain/google.com').once
    end

    it "supports overriding the bootstrap URL" do
      expect(RDAP.domain("google.com", server: "https://rdap-bootstrap.arin.net/bootstrap")).to include({
        "objectClassName" => "domain",
        "handle" => "2138514_DOMAIN_COM-VRSN",
      })
      expect(WebMock).to have_requested(:get, 'https://rdap-bootstrap.arin.net/bootstrap/domain/google.com').once
      expect(WebMock).to have_requested(:get, 'https://rdap.verisign.com/com/v1/domain/google.com').once
    end

    it "supports giving the RDAP server directly" do
      expect(RDAP.domain("google.com", server: "https://rdap.verisign.com/com/v1")).to include({
        "objectClassName" => "domain",
        "handle" => "2138514_DOMAIN_COM-VRSN",
      })
      expect(WebMock).not_to have_requested(:get, 'https://rdap.org/domain/google.com')
      expect(WebMock).to have_requested(:get, 'https://rdap.verisign.com/com/v1/domain/google.com').once
    end

    it "raises an error for wrong type" do
      expect {
        RDAP.domain("8.8.8.8")
      }.to raise_error(RDAP::NotFound, "[404] domain 8.8.8.8 not found in IANA boostrap file")
      expect(WebMock).to have_requested(:get, 'https://rdap.org/domain/8.8.8.8').once
    end

    it "raises an error for unsupported TLD" do
      expect {
        RDAP.domain("test.fr")
      }.to raise_error(RDAP::NotFound, "[404] domain test.fr not found in IANA boostrap file")
      expect(WebMock).to have_requested(:get, 'https://rdap.org/domain/test.fr').once
    end

    it "raises an error for domain not found" do
      expect {
        RDAP.domain("jsiqpmcurt.design")
      }.to raise_error(RDAP::NotFound, "[404] Object not found")
    end

    it "raises an error for domain not found when the response body is empty" do
      expect {
        RDAP.domain("jsiqpmcurt.com")
      }.to raise_error(RDAP::NotFound, "[404] Not Found")
    end

    it "raises an error for an invalid URI" do
      expect {
        RDAP.domain("u$&~(!*@&@^#}")
      }.to raise_error(URI::InvalidURIError, "bad URI(is not URI?): \"https://rdap.org/domain/u$&~(!*@&@^#}\"")
    end

    it "raises an error for invalid options" do
      expect {
        RDAP.domain("test.com", invalid: :option)
      }.to raise_error(ArgumentError, "unknown keyword: invalid")
    end
  end

  describe '.ip', :vcr do
    it "works with the :ip type" do
      expect(RDAP.ip("8.8.8.8")).to include({
        "objectClassName" => "ip network",
        "status" => ["active"],
        "cidr0_cidrs" => [{"length"=>24, "v4prefix"=>"8.8.8.0"}],
        "startAddress" => "8.8.8.0",
        "endAddress" => "8.8.8.255",
        "handle" => "NET-8-8-8-0-1",
        "parentHandle" => "NET-8-0-0-0-1",
        "ipVersion" => "v4",
        "rdapConformance" => ["nro_rdap_profile_0", "rdap_level_0", "cidr0", "arin_originas0"],
      })
      expect(WebMock).to have_requested(:get, 'https://rdap.org/ip/8.8.8.8').once
      expect(WebMock).to have_requested(:get, 'https://rdap.arin.net/registry/ip/8.8.8.8/32').once
    end

    it "works with the :ip type (IPv6)" do
      expect(RDAP.ip("2620:119:35::35")).to include({
        "objectClassName" => "ip network",
        "name" => "OPENDNS-V6-NET-1",
        "status" => ["active"],
        "cidr0_cidrs" => [{"length"=>40, "v6prefix"=>"2620:119::"}],
        "arin_originas0_originautnums" => [36692],
        "startAddress" => "2620:119::",
        "endAddress" => "2620:119:ff:ffff:ffff:ffff:ffff:ffff",
        "handle" => "NET6-2620-119-1",
        "parentHandle" => "NET6-2620-1",
        "ipVersion" => "v6",
        "rdapConformance" => ["nro_rdap_profile_0", "rdap_level_0", "cidr0", "arin_originas0"],
      })
      expect(WebMock).to have_requested(:get, 'https://rdap.org/ip/2620:119:35::35').once
      expect(WebMock).to have_requested(:get, 'https://rdap.arin.net/registry/ip/2620:119:35::35/128').once
    end
  end

  describe '.as', :vcr do
    it "works with the :autnum type" do
      expect(RDAP.as("16276")).to include({
        "objectClassName" => "autnum",
        "type" => "DIRECT ALLOCATION",
        "name" => "OVH",
        "handle" => "AS16276",
        "events" => [{"eventAction"=>"last changed", "eventDate"=>instance_of(String)}],
        "rdapConformance" => ["rdap_level_0"],
      })
      expect(WebMock).to have_requested(:get, 'https://rdap.org/autnum/16276').once
      expect(WebMock).to have_requested(:get, 'https://rdap.db.ripe.net/autnum/16276').once
    end
  end

  describe '.query' do
    it "raises an error for invalid types" do
      expect {
        RDAP.query("google.com", type: :xxx)
      }.to raise_error(ArgumentError, "RDAP: Invalid query type: xxx, supported types: [:domain, :ip, :autnum]")
    end
  end
end