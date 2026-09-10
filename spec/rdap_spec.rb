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
          {"eventAction"=>"last changed", "eventDate"=>instance_of(String)},
          {"eventAction"=>"last update of RDAP database", "eventDate"=>instance_of(String)}
        ],
        "nameservers" => [
          {"objectClassName" => "nameserver", "ldhName" => "NS1.GOOGLE.COM"},
          {"objectClassName" => "nameserver", "ldhName" => "NS2.GOOGLE.COM"},
          {"objectClassName" => "nameserver", "ldhName" => "NS3.GOOGLE.COM"},
          {"objectClassName" => "nameserver", "ldhName" => "NS4.GOOGLE.COM"}
        ],
        "rdapConformance"=> ["rdap_level_0", "icann_rdap_technical_implementation_guide_1", "icann_rdap_response_profile_1"],
      })
      expect(WebMock).not_to have_requested(:get, 'https://rdap.org/domain/google.com')
      expect(WebMock).to have_requested(:get, 'https://rdap.verisign.com/com/v1/domain/google.com').once
    end

    it "pass default headers", vcr: false do
      stub_request(:get, "https://rdap.org/domain/test.com").with(headers: {
        "Accept" => "application/rdap+json, application/json, */*;q=0.8",
        "User-Agent" => "RDAP ruby gem (#{RDAP::VERSION})"
      }).to_return(status: 302, headers: { "Location" => "https://rdap.domain.com/domain/test.com" })
      stub_request(:get, "https://rdap.domain.com/domain/test.com").with(headers: {
        "Accept" => "application/rdap+json, application/json, */*;q=0.8",
        "User-Agent" => "RDAP ruby gem (#{RDAP::VERSION})"
      }).to_return(body: "{}")
      RDAP.domain("test.com", server: "https://rdap.org")
    end

    it "pass customized headers if any", vcr: false do
      stub_request(:get, "https://rdap.org/domain/test.com").with(headers: {
        "Accept" => "application/rdap+json, application/json, */*;q=0.8",
        "User-Agent" => "My application",
        "Accept-Encoding" => "gzip"
      }).to_return(status: 302, headers: { "Location" => "https://rdap.domain.com/domain/test.com" })
      stub_request(:get, "https://rdap.domain.com/domain/test.com").with(headers: {
        "Accept" => "application/rdap+json, application/json, */*;q=0.8",
        "User-Agent" => "My application",
        "Accept-Encoding" => "gzip"
      }).to_return(body: "{}")
      RDAP.domain("test.com", server: "https://rdap.org", headers: {'User-Agent' => 'My application', 'Accept-Encoding' => 'gzip'})
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

    it "supports rdap.nic.fr which does not accept rdap+json mimetype (as of 2022-12-29)" do
      expect(RDAP.domain("airport.fr")).to include({
        "objectClassName" => "domain",
        "handle" => "DOM000000001670-FRNIC",
      })
      expect(WebMock).not_to have_requested(:get, 'https://rdap.org/domain/airport.fr')
      expect(WebMock).to have_requested(:get, 'https://rdap.nic.fr/domain/airport.fr').once
    end

    it "raises an error for wrong type" do
      expect {
        RDAP.domain("8.8.8.8")
      }.to raise_error(RDAP::NotFound, "[404] Not Found")
      expect(WebMock).to have_requested(:get, 'https://rdap.org/domain/8.8.8.8').once
    end

    it "queries the authoritative server directly from the bundled bootstrap files" do
      expect {
        RDAP.domain("jsiqpmcurt.fr")
      }.to raise_error(RDAP::NotFound)
      expect(WebMock).not_to have_requested(:get, 'https://rdap.org/domain/jsiqpmcurt.fr')
      expect(WebMock).to have_requested(:get, 'https://rdap.nic.fr/domain/jsiqpmcurt.fr').once
    end

    it "raises an error for domain not found" do
      expect {
        RDAP.domain("jsiqpmcurt.design")
      }.to raise_error(RDAP::NotFound, "[404] Not found")
      expect(WebMock).to have_requested(:get, 'https://rdap.nic.design/domain/jsiqpmcurt.design').once
    end

    it "raises an error for domain not found when the response body is empty", vcr: false do
      stub_request(:get, "https://rdap.verisign.com/com/v1/domain/jsiqpmcurt.com").to_return(status: [404, ""])
      expect {
        RDAP.domain("jsiqpmcurt.com")
      }.to raise_error(RDAP::NotFound, "[404] ")
    end

    it "raises an error for throttling", vcr: false do
      stub_request(:get, "https://rdap.org/domain/test.com").to_return(status: [429, "Too Many Requests"])
      expect {
        RDAP.domain("test.com", server: "https://rdap.org")
      }.to raise_error(RDAP::TooManyRequests, "[429] Too Many Requests")
    end

    it "raises an error for empty body", vcr: false do
      stub_request(:get, "https://rdap.org/domain/test.com").to_return(status: [204, "No Content"])
      expect {
        RDAP.domain("test.com", server: "https://rdap.org")
      }.to raise_error(RDAP::EmptyResponse, "[204] No Content")
    end

    it "raises an error for invalid JSON", vcr: false do
      stub_request(:get, "https://rdap.org/domain/test.com").to_return(body: "invalid")
      expect {
        RDAP.domain("test.com", server: "https://rdap.org")
      }.to raise_error(RDAP::InvalidResponse, /\AJSON parser error: .*invalid/)
    end

    it "raises an error for invalid SSL", vcr: false do
      stub = stub_request(:get, "https://rdap.nic.porn/domain/heaven.porn").to_raise(OpenSSL::SSL::SSLError.new("SSL_connect returned=1 errno=0 state=error: certificate verify failed (certificate has expired)"))
      expect {
        RDAP.domain("heaven.porn")
      }.to raise_error(RDAP::SSLError, "SSL_connect returned=1 errno=0 state=error: certificate verify failed (certificate has expired) (rdap.nic.porn)")
      expect(WebMock).not_to have_requested(:get, 'https://rdap.org/domain/heaven.porn')
      expect(stub).to have_been_requested
    end

    it "wraps connection errors as RDAP::ConnectionError", vcr: false do
      stub = stub_request(:get, "https://rdap.nic.design/domain/jsiqpmcurt.design").to_raise(EOFError.new("end of file reached"))
      expect {
        RDAP.domain("jsiqpmcurt.design")
      }.to raise_error(RDAP::ConnectionError, "EOFError: end of file reached (rdap.nic.design)")
      expect(stub).to have_been_requested
    end

    it "raises an error for an invalid URI" do
      expect {
        RDAP.domain("u$&~(!*@&@^#}")
      }.to raise_error(URI::InvalidURIError, %r{bad URI ?\(is not URI\?\): "https://rdap\.org/domain/u\$&~})
    end

    it "raises an error for invalid options" do
      expect {
        RDAP.domain("test.com", invalid: :option)
      }.to raise_error(ArgumentError, /unknown keyword: :?invalid/)
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
        "handle" => "NET-8-8-8-0-2",
        "parentHandle" => "NET-8-0-0-0-0",
        "ipVersion" => "v4",
        "rdapConformance" => ["nro_rdap_profile_0", "rdap_level_0", "cidr0", "arin_originas0"],
      })
      expect(WebMock).not_to have_requested(:get, 'https://rdap.org/ip/8.8.8.8')
      expect(WebMock).to have_requested(:get, 'https://rdap.arin.net/registry/ip/8.8.8.8').once
    end

    it "works with the :ip type (IPv6)" do
      expect(RDAP.ip("2620:119:35::35")).to include({
        "objectClassName" => "ip network",
        "name" => "OPENDNS-V6-NET-1",
        "status" => ["active"],
        "cidr0_cidrs" => [{"length"=>40, "v6prefix"=>"2620:119::"}],
        "arin_originas0_originautnums" => [],
        "startAddress" => "2620:119::",
        "endAddress" => "2620:119:ff:ffff:ffff:ffff:ffff:ffff",
        "handle" => "NET6-2620-119-1",
        "parentHandle" => "NET6-2620-1",
        "ipVersion" => "v6",
        "rdapConformance" => ["nro_rdap_profile_0", "rdap_level_0", "cidr0", "arin_originas0"],
      })
      expect(WebMock).not_to have_requested(:get, 'https://rdap.org/ip/2620:119:35::35')
      expect(WebMock).to have_requested(:get, 'https://rdap.arin.net/registry/ip/2620:119:35::35').once
    end

    it "raises an error for an invalid IP", vcr: false do
      expect {
        RDAP.ip("notanip")
      }.to raise_error(IPAddr::InvalidAddressError, /invalid address:/)
    end
  end

  describe '.as', :vcr do
    it "works with the :autnum type" do
      expect(RDAP.as("16276")).to include({
        "objectClassName" => "autnum",
        "name" => "OVH",
        "handle" => "AS16276",
        "events" => [
          {"eventAction"=>"registration", "eventDate"=>instance_of(String)},
          {"eventAction"=>"last changed", "eventDate"=>instance_of(String)}
        ],
        "rdapConformance" => ["nro_rdap_profile_asn_flat_0", "rirSearch1", "autnums", "cidr0", "rdap_level_0", "nro_rdap_profile_0", "redacted"],
      })
      expect(WebMock).not_to have_requested(:get, 'https://rdap.org/autnum/16276')
      expect(WebMock).to have_requested(:get, 'https://rdap.db.ripe.net/autnum/16276').once
    end

    it "raises an error for an invalid AS number", vcr: false do
      expect {
        RDAP.as("AS16276")
      }.to raise_error(ArgumentError, 'RDAP: Invalid AS number: "AS16276"')
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